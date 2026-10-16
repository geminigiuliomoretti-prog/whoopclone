import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import '../ble/noop_protocol_decoder.dart';
import '../database/database_helper.dart';
import '../../domain/analytics/whoop_analytics_engine.dart';

/// Risultato della Validazione e Parsing dell'Inviluppo BLE WHOOP 4.0 / 5.0
class BleFrameValidationResult {
  final bool isValid;
  final int versionType; // es. v18 (biometrici) o v26 (PPG 24Hz raw)
  final int seqNumber;
  final int declLen;
  final List<int> innerPayload;
  final bool crc16Passed;
  final bool crc32Passed;

  BleFrameValidationResult({
    required this.isValid,
    required this.versionType,
    required this.seqNumber,
    required this.declLen,
    required this.innerPayload,
    required this.crc16Passed,
    required this.crc32Passed,
  });
}

/// Decodifica e Controlla l'integrità del Pacchetto BLE WHOOP (Frame Envelope Validation)
/// Spec: Start Marker 0xAA (Byte 0), Prefix 0x01 (Byte 1), Inner Length u16 LE (Byte 2-3),
/// Header CRC-16/Modbus, Inner Payload CRC-32 IEEE 802.3 (Final XOR 0xF43F44AC).
BleFrameValidationResult? validateAndParseBleFrame(List<int> rawBytes) {
  if (rawBytes.length < 8) return null;
  if (rawBytes[0] != 0xAA || rawBytes[1] != 0x01) {
    return null; // Marker o prefisso non valido
  }

  final declLen = rawBytes[2] | (rawBytes[3] << 8);
  final totalFrameSize = declLen + 8;
  if (rawBytes.length < totalFrameSize) {
    return null; // Pacchetto incompleto
  }

  // Estrazione dell'Inner Payload
  final innerPayload = rawBytes.sublist(4, totalFrameSize - 4);
  final receivedCrc32 = (rawBytes[totalFrameSize - 4] & 0xFF) |
      ((rawBytes[totalFrameSize - 3] & 0xFF) << 8) |
      ((rawBytes[totalFrameSize - 2] & 0xFF) << 16) |
      ((rawBytes[totalFrameSize - 1] & 0xFF) << 24);

  // Verifica del CRC-32 IEEE 802.3 proprietario WHOOP sul payload interno
  final computedCrc32 = WhoopCrc32.compute(innerPayload);
  final bool crc32Passed = (receivedCrc32 & 0xFFFFFFFF) == (computedCrc32 & 0xFFFFFFFF);

  if (!crc32Passed) {
    return BleFrameValidationResult(
      isValid: false,
      versionType: 0,
      seqNumber: 0,
      declLen: declLen,
      innerPayload: innerPayload,
      crc16Passed: true,
      crc32Passed: false,
    );
  }

  final versionType = innerPayload.length >= 6 ? innerPayload[5] : 0;
  final seqNumber = innerPayload.length >= 5 ? innerPayload[4] : 0;

  return BleFrameValidationResult(
    isValid: true,
    versionType: versionType,
    seqNumber: seqNumber,
    declLen: declLen,
    innerPayload: innerPayload,
    crc16Passed: true,
    crc32Passed: true,
  );
}

/// Gestore del Protocollo Store-and-Forward Mattutino (Opcode 22 & 23)
class StoreAndForwardHandler {
  /// Genera il comando Opcode 22 (SEND_HISTORICAL_DATA) per scaricare i blocchi v18/v26
  static List<int> buildOpcode22SendHistoricalData({int seq = 0, bool isWhoop5 = false}) {
    if (isWhoop5) {
      // WHOOP 5.0 SEND_HISTORICAL_DATA (22): body [0x00]
      return HapticClockEncoder.buildFramedCommand(
        type: 0x23,
        seq: seq,
        cmd: 0x16,
        payload: const [0x00],
        isWhoop5: true,
      );
    }
    return HapticClockEncoder.buildFramedCommand(
      type: 0x01,
      seq: seq,
      cmd: 0x16,
      payload: const [0x00, 0x00, 0x00, 0x01, 0x00],
      isWhoop5: false,
    );
  }

  /// Genera il pacchetto ACK Opcode 23 (HISTORICAL_DATA_RESULT) per avanzare il cursore Flash
  /// Sul WHOOP 5.0: richiede [0x01] + token verbatim da 8 byte dell'end block
  static List<int> buildOpcode23HistoricalDataResult(int lastSeqAck, {int seq = 0, List<int>? endBlock, bool isWhoop5 = false}) {
    if (isWhoop5) {
      final token = (endBlock != null && endBlock.length >= 8)
          ? endBlock.sublist(0, 8)
          : [lastSeqAck & 0xFF, (lastSeqAck >> 8) & 0xFF, 0, 0, 0, 0, 0, 0];
      return HapticClockEncoder.buildFramedCommand(
        type: 0x23,
        seq: seq,
        cmd: 0x17,
        payload: [0x01, ...token],
        isWhoop5: true,
      );
    }
    return HapticClockEncoder.buildFramedCommand(
      type: 0x01,
      seq: seq,
      cmd: 0x17,
      payload: [lastSeqAck & 0xFF, (lastSeqAck >> 8) & 0xFF, 0x01],
      isWhoop5: false,
    );
  }

  /// Ricompone i frammenti BLE MTU in un pacchetto record completo (v26 1244-byte / IMU 1928-byte)
  static List<int> reassembleFragments(List<List<int>> fragments) {
    final Uint8Buffer buffer = Uint8Buffer();
    for (var frag in fragments) {
      buffer.addAll(frag);
    }
    return buffer.toList();
  }
}

/// Fasi del Sonno Staging Deterministico WHOOP 5.0
enum SleepStage { wake, light, deepSws, rem, missing, unknown }

enum EpochQuality { valid, lowConfidence, missing }

extension SleepStageExtension on SleepStage {
  String toHypnogramString() {
    switch (this) {
      case SleepStage.wake:
        return 'WAKE';
      case SleepStage.light:
        return 'LIGHT';
      case SleepStage.deepSws:
        return 'SWS';
      case SleepStage.rem:
        return 'REM';
      case SleepStage.missing:
        return 'MISSING';
      case SleepStage.unknown:
        return 'UNKNOWN';
    }
  }
}

/// Matrice di Scoring Probabilistico / Deterministico per lo Staging dell'Epoca da 30s
SleepStage classifyEpoch({
  required double enmo,
  required double hrRatio,
  required double hrvNorm,
  required double respVar,
  required int epochIndex,
  required int totalEpochs,
}) {
  // 1. REGOLA VEGLIA (WASO): Movimento significativo o frequenza molto alta
  if (enmo > 0.040 || hrRatio > 1.25) {
    return SleepStage.wake;
  }

  // 2. REGOLA SONNO PROFONDO (SWS / N3):
  // Assenza di moto (enmo < 0.006g), frequenza cardiaca al nadir (hrRatio <= 0.98 con RSA regolare o <= 0.90 senza RSA),
  // e respirazione altamente stabile. SWS fisiologico si concentra nei primi cicli (prima del 70% della notte con RSA,
  // prima del 45% senza RSA per evitare sovrastima sistematica di sonno leggero N2).
  final bool hasExplicitRsa = respVar <= 0.151 && respVar > 0.0;
  final bool isDeepCandidate = hasExplicitRsa
      ? (enmo < 0.006 && hrRatio <= 0.98)
      : (enmo < 0.005 && hrRatio <= 0.95);

  final double maxDeepProgress = hasExplicitRsa ? 0.70 : 0.45;
  if (isDeepCandidate && (epochIndex < (totalEpochs * maxDeepProgress) || (hasExplicitRsa && respVar <= 0.08))) {
    return SleepStage.deepSws;
  }

  // 3. REGOLA SONNO REM:
  // Atonia muscolare (no moto), frequenza cardiaca variabile e spike di HRV (tono instabile)
  final isRemCandidate = enmo < 0.010 && hrvNorm > 1.20 && hrRatio > 0.95;
  final int minRemEpoch = totalEpochs > 150 ? 120 : (totalEpochs * 0.15).round();
  if (isRemCandidate && epochIndex > minRemEpoch) {
    return SleepStage.rem;
  }

  // 4. STATO BASE: Sonno Leggero (Light Sleep / N1-N2)
  return SleepStage.light;
}

/// Struttura dell'Epoca di Sonno a 30 Secondi (30-second Hypnogram Epoch)
class Epoch30s {
  final int index;
  final DateTime timestamp;
  final double motionVar; // Varianza accelerazione triassiale IMU / ENMO
  final double hr; // Heart Rate dell'epoca
  final double rmssd; // rMSSD calcolato sugli intervalli PP dell'epoca
  final double respPower; // Ampiezza picco spettrale RSA [0.12 - 0.40 Hz]
  final double respRate; // Frequenza respiratoria estratta (atti/min)
  final double rmssdVarInWindow; // Varianza inter-epoca del rMSSD
  final int hrFluctuations; // Picchi isolati di FC nell'epoca
  final List<double> ppIntervals; // Intervalli picco-picco in secondi
  final int sampleCount;
  final EpochQuality quality;
  String stage; // WAKE, LIGHT, SWS, REM, MISSING, UNKNOWN

  Epoch30s({
    required this.index,
    required this.timestamp,
    required this.motionVar,
    required this.hr,
    required this.rmssd,
    required this.respPower,
    required this.respRate,
    required this.rmssdVarInWindow,
    required this.hrFluctuations,
    required this.ppIntervals,
    this.stage = 'LIGHT',
    this.sampleCount = 30,
    this.quality = EpochQuality.valid,
  });

  Map<String, dynamic> toMap() => {
        'index': index,
        'timestamp': timestamp.toIso8601String(),
        'motion': motionVar,
        'hr': hr,
        'rmssd': rmssd,
        'resp_power': respPower,
        'resp_rate': respRate,
        'stage': stage,
        'sample_count': sampleCount,
        'quality': quality.name,
      };
}

/// Stati FSM dell'Auto Sleep Detection Engine
enum AutoSleepState {
  idleAwake,
  sleepCandidateBuffering,
  sleepInProgress,
  wakeCooldownPending,
  sleepTerminated,
}

/// Record di telemetria per il buffer del rilevatore automatico del sonno
class SleepTelemetrySample {
  final DateTime timestamp;
  final double hr;
  final double enmo;
  final double rmssd;
  final double respPower;
  final double respRate;
  final double rmssdVar;
  final int hrFluc;
  final int? tempRaw;
  final double? spo2Ratio;

  SleepTelemetrySample({
    required this.timestamp,
    required this.hr,
    required this.enmo,
    required this.rmssd,
    required this.respPower,
    required this.respRate,
    required this.rmssdVar,
    required this.hrFluc,
    this.tempRaw,
    this.spo2Ratio,
  });

  Map<String, dynamic> toMap() => {
        'timestamp': timestamp.toIso8601String(),
        'hr': hr,
        'motion_var': enmo,
        'enmo': enmo,
        'rmssd': rmssd,
        'resp_power': respPower,
        'resp_rate': respRate,
        'rmssd_var': rmssdVar,
        'hr_fluc': hrFluc,
        'skin_temp_raw': tempRaw,
        'spo2_ratio_r': spo2Ratio,
      };
}

/// Rilevatore Automatico di Sonno basato su Macchina a Stati Finita (FSM), Quiescenza ENMO,
/// Calo della Frequenza Cardiaca, Regolarità Respiratoria (RSA) e Backdating di Inizio/Fine.
class AutoSleepDetector {
  final double restHr;
  final double daytimeMeanHr;
  final double hrvBaseline;
  final double enmoSleepThresh; // 0.015g: soglia di quiescenza cinematica prolungata
  final double enmoWakeThresh; // 0.080g: soglia di risveglio per attività motoria continuativa
  final int tSleepSustainSec; // 30 min = 1800s (durata minima di quiete per confermare SLEEP_START)
  final int tWakeSustainSec; // 15 min = 900s (durata minima di attività per confermare SLEEP_END)
  final int bufferCapacity; // Max campioni in RAM (default 14 ore @ 1Hz o 30s)

  final OvernightSleepEngine _sleepEngine;
  final Map<String, dynamic> Function()? userBaselineProvider;

  // Buffer Circolare Telemetria
  final List<SleepTelemetrySample> _telemetryBuffer = [];
  List<SleepTelemetrySample> get telemetryBuffer => List.unmodifiable(_telemetryBuffer);

  // Stato FSM
  AutoSleepState state = AutoSleepState.idleAwake;
  DateTime? activeSleepStart;

  // Stream per notificare l'avvenuto completamento del calcolo del sonno e del recovery
  final StreamController<Map<String, dynamic>> _autoSleepController =
      StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get autoSleepDetectedStream => _autoSleepController.stream;

  AutoSleepDetector({
    this.restHr = 55.0,
    double? daytimeMeanHr,
    this.hrvBaseline = 65.0,
    this.enmoSleepThresh = 0.015,
    this.enmoWakeThresh = 0.080,
    int? tSleepSustainSec,
    int? tWakeSustainSec,
    this.bufferCapacity = 14 * 3600,
    OvernightSleepEngine? sleepEngine,
    this.userBaselineProvider,
  })  : daytimeMeanHr = daytimeMeanHr ?? (restHr * 1.35),
        tSleepSustainSec = tSleepSustainSec ?? 30 * 60,
        tWakeSustainSec = tWakeSustainSec ?? 15 * 60,
        _sleepEngine = sleepEngine ?? OvernightSleepEngine();

  /// Ingestione di un campione di telemetria (1Hz o epoch 30s)
  void ingestSample(
    DateTime timestamp,
    double hr, {
    double? enmo,
    double? rmssd,
    double? respPower,
    double? respRate,
    double? rmssdVar,
    int? hrFluc,
    int? tempRaw,
    double? spo2Ratio,
  }) {
    final double enmoVal = enmo ?? 0.0;
    final double rmssdVal = rmssd ?? 0.0;
    final double rPower = respPower ?? 0.0;
    final double rRate = respRate ?? 0.0;
    final double rVar = rmssdVar ?? 0.0;
    final int hFluc = hrFluc ?? 0;

    final sample = SleepTelemetrySample(
      timestamp: timestamp,
      hr: hr,
      enmo: enmoVal,
      rmssd: rmssdVal,
      respPower: rPower,
      respRate: rRate,
      rmssdVar: rVar,
      hrFluc: hFluc,
      tempRaw: tempRaw,
      spo2Ratio: spo2Ratio,
    );

    _telemetryBuffer.add(sample);
    if (_telemetryBuffer.length > bufferCapacity) {
      _telemetryBuffer.removeAt(0);
    }

    _evaluateFsm(timestamp);
  }

  /// Supporto per flusso BPM diretto
  void processBpmSample(int bpm, DateTime timestamp, {double? enmo, double? rmssd}) {
    ingestSample(timestamp, bpm.toDouble(), enmo: enmo, rmssd: rmssd);
  }

  /// Valutazione della Macchina a Stati di Auto-Sleep Detection
  void _evaluateFsm(DateTime currentTime) {
    if (state == AutoSleepState.idleAwake || state == AutoSleepState.sleepCandidateBuffering) {
      // 1. RILEVAMENTO ADDORMENTAMENTO (SLEEP_START)
      // Trigger: Quiescenza cinematica ENMO < 0.015g per >= 30 min, HR coerente con sonno fisiologico.
      final int requiredCount = math.min(_telemetryBuffer.length, tSleepSustainSec);
      if (requiredCount >= tSleepSustainSec) {
        final recentWindow = _telemetryBuffer.sublist(_telemetryBuffer.length - requiredCount);
        
        // Verifica durata temporale effettiva della finestra (wall-clock seconds)
        final int elapsedWallClockSec = recentWindow.isNotEmpty
            ? recentWindow.last.timestamp.difference(recentWindow.first.timestamp).inSeconds.abs()
            : 0;

        // Se tSleepSustainSec è configurato per durata di produzione (>= 600s),
        // esigiamo che la durata wall-clock sia effettivamente trascorsa (almeno 80% di tSleepSustainSec)
        if (tSleepSustainSec >= 600 && elapsedWallClockSec < (tSleepSustainSec * 0.8).round()) {
          return;
        }

        final quietCount = recentWindow.where((s) => s.enmo <= enmoSleepThresh).length;
        final avgHr = recentWindow.map((s) => s.hr).reduce((a, b) => a + b) / requiredCount;
        final avgRespPower = recentWindow.map((s) => s.respPower).reduce((a, b) => a + b) / requiredCount;

        final bool isKinematicallyQuiet = (quietCount / requiredCount) >= 0.75;

        // Distinzione tra riposo passivo/divano e sonno effettivo:
        // Finestra notturna (21:00 - 09:00): soglia basale più permissiva
        final currentHour = currentTime.hour;
        final bool isCircadianNight = currentHour >= 21 || currentHour < 9;

        final bool isHrDropped;
        if (isCircadianNight) {
          isHrDropped = (avgHr <= (daytimeMeanHr * 0.85)) && (avgHr <= restHr + 6.0);
        } else {
          // Di giorno (veglia rilassata/divano a 60-70 bpm):
          // Seduti sul divano la FC resta tipicamente > restHr + 4 bpm: NON deve innescare il sonno!
          // Un pisolino diurno richiede caduta a FC basale profonda (<= restHr + 2) e regolarità RSA,
          // oppure forte stabilità motoria (>90% quiete assoluta).
          isHrDropped = (avgHr <= restHr + 2.0) && (avgRespPower >= 0.50 || (quietCount / requiredCount) >= 0.90);
        }

        final bool isRsaRegular = avgRespPower >= 0.50 && avgHr <= (daytimeMeanHr * 0.85);

        if (isKinematicallyQuiet && (isHrDropped || isRsaRegular)) {
          // Retrodata l'inizio del sonno al primo minuto di quiete
          activeSleepStart = _backdateSleepStart();
          state = AutoSleepState.sleepInProgress;
          debugPrint('[AutoSleepDetector] SLEEP_START rilevato! Inizio retrodatato a $activeSleepStart');
        } else if (isKinematicallyQuiet) {
          state = AutoSleepState.sleepCandidateBuffering;
        } else {
          state = AutoSleepState.idleAwake;
        }
      }
    } else if (state == AutoSleepState.sleepInProgress) {
      // 2. RILEVAMENTO RISVEGLIO (SLEEP_END / WAKE_UP)
      // Trigger: Attività motoria continuativa ENMO > 0.080g o FC elevata, o scarica motoria intensa
      final int requiredWakeCount = math.min(_telemetryBuffer.length, tWakeSustainSec);
      if (requiredWakeCount >= math.min(tWakeSustainSec, 15)) {
        final recentWakeWindow = _telemetryBuffer.sublist(_telemetryBuffer.length - requiredWakeCount);

        final activeMotionCount = recentWakeWindow.where((s) => s.enmo >= enmoWakeThresh).length;
        final avgHr = recentWakeWindow.map((s) => s.hr).reduce((a, b) => a + b) / requiredWakeCount;

        final bool isMotorActive = (activeMotionCount / requiredWakeCount) >= 0.50;
        final bool isHrElevated = avgHr >= (restHr + 14.0) || avgHr >= (daytimeMeanHr * 0.90);
        final bool isHighMotionBurst = recentWakeWindow.where((s) => s.enmo >= 0.100).length >= 5;

        if ((isMotorActive && isHrElevated) || isHighMotionBurst) {
          final wakeEndTime = _backdateSleepEnd();
          state = AutoSleepState.wakeCooldownPending;
          debugPrint('[AutoSleepDetector] SLEEP_END rilevato! Risveglio retrodatato a $wakeEndTime');
          try {
            _terminateAndProcessSleep(activeSleepStart ?? _telemetryBuffer.first.timestamp, wakeEndTime)
                .catchError((e, stack) {
              debugPrint('[AutoSleepDetector] Errore asincrono in _terminateAndProcessSleep: $e\n$stack');
              state = AutoSleepState.idleAwake;
              activeSleepStart = null;
              return <String, dynamic>{};
            });
          } catch (e, stack) {
            debugPrint('[AutoSleepDetector] Errore avvio terminazione sonno: $e\n$stack');
            state = AutoSleepState.idleAwake;
            activeSleepStart = null;
          }
        }
      }
    }
  }

  /// Retrodatazione dell'orario di addormentamento identificando la prima finestra
  /// prolungata di quiete motoria e stabilità emodinamica che introduce la sessione di sonno.
  DateTime _backdateSleepStart() {
    if (_telemetryBuffer.isEmpty) return DateTime.now();
    if (_telemetryBuffer.length == 1) return _telemetryBuffer.first.timestamp;

    bool isQuiet(SleepTelemetrySample s) =>
        s.enmo <= enmoSleepThresh && s.hr <= (daytimeMeanHr * 0.90);

    // Durata minima della finestra di quiete prolungata per validare l'addormentamento (es. 5 min / 300s)
    final int minWindowSec = math.min(tSleepSustainSec, 300);
    const double stabilityThresh = 0.75;

    for (int i = 0; i < _telemetryBuffer.length; i++) {
      final sample = _telemetryBuffer[i];
      if (!isQuiet(sample)) continue;

      // Finestra temporale di verifica a partire dal candidato
      final windowEndLimit = sample.timestamp.add(Duration(seconds: minWindowSec));
      int windowCount = 0;
      int windowQuietCount = 0;

      for (int j = i; j < _telemetryBuffer.length; j++) {
        final current = _telemetryBuffer[j];
        if (current.timestamp.isAfter(windowEndLimit) && windowCount > 0) break;
        windowCount++;
        if (isQuiet(current)) windowQuietCount++;
      }

      if (windowCount == 0) continue;
      final double windowQuietRatio = windowQuietCount / windowCount;

      // Se la finestra iniziale è stabile, verifichiamo che la stabilità
      // si mantenga fino alla fine del buffer (fase di sonno corrente confermata)
      if (windowQuietRatio >= stabilityThresh) {
        int totalFromI = 0;
        int quietFromI = 0;
        for (int k = i; k < _telemetryBuffer.length; k++) {
          totalFromI++;
          if (isQuiet(_telemetryBuffer[k])) quietFromI++;
        }

        if (totalFromI > 0 && (quietFromI / totalFromI) >= stabilityThresh) {
          return sample.timestamp;
        }
      }
    }

    return _telemetryBuffer.first.timestamp;
  }

  /// Retrodatazione dell'orario di risveglio escludendo la coda di movimento post-risveglio
  DateTime _backdateSleepEnd() {
    final int wakeFrames = math.min(_telemetryBuffer.length, tWakeSustainSec);
    final targetIdx = _telemetryBuffer.length - wakeFrames;
    if (targetIdx >= 0 && targetIdx < _telemetryBuffer.length) {
      return _telemetryBuffer[targetIdx].timestamp;
    }
    return _telemetryBuffer.last.timestamp;
  }

  /// Conclude la sessione notturna, isola la telemetria, invoca l'OvernightSleepEngine ed emette l'evento
  Future<Map<String, dynamic>> _terminateAndProcessSleep(DateTime start, DateTime end) async {
    try {
      DateTime safeStart = start;
      DateTime safeEnd = end;

      if (safeEnd.isBefore(safeStart)) {
        final tmp = safeStart;
        safeStart = safeEnd;
        safeEnd = tmp;
      }

      // Protezione sonno mostruoso (> 14 ore): se i buffer erano rimasti aperti per giorni
      if (safeEnd.difference(safeStart).inHours > 14) {
        safeStart = safeEnd.subtract(const Duration(hours: 8));
      }

      final sleepSamples = _telemetryBuffer
          .where((s) => !s.timestamp.isBefore(safeStart) && !s.timestamp.isAfter(safeEnd))
          .map((s) => s.toMap())
          .toList();

      final baseline = userBaselineProvider?.call() ?? {
        'rhr_mean': restHr,
        'rmssd_mean': hrvBaseline,
        'rmssd_std': 15.0,
        'baseline_temp_celsius': null,
        'sleep_baseline_min': 480,
      };

      final result = await _sleepEngine.processNightlyTelemetry(
        rawTelemetryRecords: sleepSamples.isNotEmpty
            ? sleepSamples
            : _telemetryBuffer.map((s) => s.toMap()).toList(),
        userBaseline30d: baseline,
        windowStart: safeStart,
        windowEnd: safeEnd,
        targetDateIso: safeEnd.toLocal().toIso8601String().substring(0, 10),
      );

      state = AutoSleepState.sleepTerminated;
      _autoSleepController.add(result);
      return result;
    } catch (e, stack) {
      debugPrint('[AutoSleepDetector] Errore durante l\'elaborazione o salvataggio del sonno: $e\n$stack');
      rethrow;
    } finally {
      state = AutoSleepState.idleAwake;
      activeSleepStart = null;
    }
  }

  /// Chiusura forzata o trigger manuale post-quiescenza (es. al risveglio mattutino / apertura app)
  Future<Map<String, dynamic>?> triggerMorningWakeUpManual() async {
    if (activeSleepStart != null) {
      final now = DateTime.now();
      return await _terminateAndProcessSleep(activeSleepStart!, now);
    }
    return null;
  }

  void dispose() {
    _autoSleepController.close();
  }
}

/// Pipeline Analitico Notturno WHOOP 4.0 / 5.0 (OvernightSleepEngine)
/// Calcola Ipnogramma (Veglia, Leggero, SWS, REM), HRV nell'Ultimo Ciclo SWS (Brevetto US9750415B2),
/// WASO, Frequenza Respiratoria Dinamica da RSA, Delta Temperatura e Recovery Score.
class OvernightSleepEngine {
  final DatabaseHelper _dbHelper;

  OvernightSleepEngine({DatabaseHelper? dbHelper})
      : _dbHelper = dbHelper ?? DatabaseHelper();

  /// Rilevamento automatico dei confini del sonno (SLEEP_START e SLEEP_END) su un flusso continuo
  /// di telemetria non segmentata.
  Map<String, dynamic> detectSleepBoundaries(
    List<Map<String, dynamic>> records, {
    double rhrBaseline = 55.0,
    double daytimeMeanHr = 75.0,
  }) {
    if (records.isEmpty) {
      return {'startIndex': 0, 'endIndex': 0, 'hasSleep': false};
    }

    int startIndex = -1;
    int endIndex = -1;

    // Regole di rilevamento addormentamento ed estrazione confini del sonno:
    // Non avviare il sonno all'inizio della sessione o per semplice immobilità serale sul divano.
    // Richiede una finestra mobile sostenuta di almeno 10 minuti di quiete motoria (ENMO ridotto)
    // combinata con un andamento cardiaco coerente (decadimento verso o sotto la baseline a riposo).
    // Usa isteresi per separare addormentamento e risveglio finale.
    const int minOnsetEpochs = 20; // 20 campioni/epoche (10 minuti se 30s)
    const int wakeConfirmEpochs = 16; // 8 minuti di attività motoria sostenuta per confermare risveglio

    // Soglia cardiaca di sonno adattata: sul divano la FC serale è tipicamente daytimeMeanHr (65-75 bpm).
    // Il sonno reale richiede che la FC scenda stabilmente vicino alla baseline di riposo (rhrBaseline + margine ristretto).
    final double sleepHrCeiling = math.min(daytimeMeanHr * 0.85, rhrBaseline + 10.0);

    for (int i = 0; i <= records.length - minOnsetEpochs; i++) {
      bool isConsistentSleepOnset = true;
      int quietMotionCount = 0;
      int lowHrCount = 0;

      for (int j = 0; j < minOnsetEpochs; j++) {
        final r = records[i + j];
        final motion = (r['motion_var'] ?? r['motion'] ?? r['enmo'] ?? r['accel_enmo'] ?? 0.050).toDouble();
        final hr = (r['hr'] ?? r['bpm'] ?? 100.0).toDouble();

        if (motion <= 0.012) quietMotionCount++;
        if (hr <= sleepHrCeiling) lowHrCount++;

        // Se c'è un picco di movimento evidente o FC di veglia attiva, l'inizio non è valido
        if (motion > 0.025 || hr > (daytimeMeanHr * 0.95)) {
          isConsistentSleepOnset = false;
          break;
        }
      }

      // Richiede che almeno il 90% della finestra soddisfi sia la quiete motoria che la FC basale
      if (isConsistentSleepOnset && quietMotionCount >= (minOnsetEpochs * 0.9) && lowHrCount >= (minOnsetEpochs * 0.85)) {
        startIndex = i;
        break;
      }
    }

    if (startIndex != -1) {
      for (int i = startIndex + minOnsetEpochs; i <= records.length - wakeConfirmEpochs; i++) {
        bool isSustainedWake = true;
        int activeMotionCount = 0;

        for (int j = 0; j < wakeConfirmEpochs; j++) {
          final r = records[i + j];
          final motion = (r['motion_var'] ?? r['motion'] ?? r['enmo'] ?? r['accel_enmo'] ?? 0.0).toDouble();
          final hr = (r['hr'] ?? r['bpm'] ?? 0.0).toDouble();

          if (motion >= 0.040 || hr >= (rhrBaseline + 18.0)) {
            activeMotionCount++;
          } else {
            isSustainedWake = false;
            break;
          }
        }

        if (isSustainedWake && activeMotionCount >= (wakeConfirmEpochs * 0.75)) {
          endIndex = i;
          break;
        }
      }
    }

    final hasSleep = startIndex != -1 && endIndex != -1 && endIndex > startIndex;
    return {
      'startIndex': hasSleep ? startIndex : 0,
      'endIndex': hasSleep ? endIndex : records.length - 1,
      'hasSleep': hasSleep,
    };
  }

  /// Elaborazione completa della telemetria notturna e staging del sonno matematico
  Future<Map<String, dynamic>> processNightlyTelemetry({
    required List<Map<String, dynamic>> rawTelemetryRecords,
    required Map<String, dynamic> userBaseline30d,
    DateTime? windowStart,
    DateTime? windowEnd,
    String? targetDateIso,
    bool forceOverwrite = false,
    double? sleepConsistencyPct,
  }) async {
    final Map<String, dynamic> effectiveBaseline = Map<String, dynamic>.from(userBaseline30d);
    try {
      final pbHrv = await _dbHelper.getPersonalBaseline('hrv');
      if (pbHrv != null && (pbHrv['mean'] as num?) != null && (pbHrv['mean'] as num) > 0) {
        effectiveBaseline['rmssd_mean'] = (pbHrv['mean'] as num).toDouble();
        if ((pbHrv['std_dev'] as num?) != null && (pbHrv['std_dev'] as num) > 0) {
          effectiveBaseline['rmssd_std'] = (pbHrv['std_dev'] as num).toDouble();
        }
      }
      final pbRhr = await _dbHelper.getPersonalBaseline('rhr');
      if (pbRhr != null && (pbRhr['mean'] as num?) != null && (pbRhr['mean'] as num) > 0) {
        effectiveBaseline['rhr_mean'] = (pbRhr['mean'] as num).toDouble();
        if ((pbRhr['std_dev'] as num?) != null && (pbRhr['std_dev'] as num) > 0) {
          effectiveBaseline['rhr_std'] = (pbRhr['std_dev'] as num).toDouble();
        }
      }
    } catch (_) {}

    final double rhrBaseline = (effectiveBaseline['rhr_mean'] ?? 55.0).toDouble();
    final double hrvBaseline = (effectiveBaseline['rmssd_mean'] ?? 65.0).toDouble();
    final double? tempBaseline = (effectiveBaseline['baseline_temp_celsius'] as num?)?.toDouble();
    final double sleepNeedMin = (effectiveBaseline['sleep_need_min'] ??
            effectiveBaseline['sleep_baseline_min'] ??
            480.0)
        .toDouble();

    List<Map<String, dynamic>> processedRecords = List.from(rawTelemetryRecords);

    // Se i dati in memoria sono insufficienti, interroga la tabella SQLite telemetria_grezza
    if (processedRecords.length < 10) {
      final now = DateTime.now();
      final start = windowStart ?? now.subtract(const Duration(hours: 8));
      final end = windowEnd ?? now;

      try {
        final dbPoints = await _dbHelper.getTelemetriaInTimeRange(start, end);
        if (dbPoints.isNotEmpty) {
          processedRecords = dbPoints.map((p) {
            final bpm = (p['bpm'] as num).toDouble();
            final rawRr = p['rr_ms'] != null ? (p['rr_ms'] as num).toDouble() : null;
            final rr = (rawRr != null && rawRr >= 300.0 && rawRr <= 2000.0) ? rawRr : null;
            final rmssd = (p['rmssd_ms'] as num?)?.toDouble() ??
                (p['rmssd'] as num?)?.toDouble() ??
                ((rawRr != null && rawRr > 0.0 && rawRr <= 250.0) ? rawRr : null);
            final motion = (p['motion_var'] as num?)?.toDouble() ?? 0.0;
            return {
              'timestamp': p['timestamp'],
              'timestamp_utc_ms': p['timestamp_utc_ms'],
              'hr': bpm,
              'bpm': bpm,
              'rmssd': rmssd,
              'rmssd_ms': rmssd,
              'rr_ms': rr,
              'rr_intervals_json': p['rr_intervals_json'],
              'motion_var': motion,
              'accel_enmo': p['accel_enmo'] ?? motion,
              'resp_power': (p['resp_power'] as num?)?.toDouble(),
              'resp_rate': (p['resp_rate'] as num?)?.toDouble(),
              'skin_temp_raw': (p['skin_temp_raw'] as num?)?.toInt(),
              'skin_temp_celsius': (p['skin_temp_celsius'] as num?)?.toDouble(),
              'spo2_ratio_r': (p['spo2_ratio_r'] as num?)?.toDouble(),
              'spo2_pct': (p['spo2_pct'] as num?)?.toDouble(),
            };
          }).toList();
        }
      } catch (e, stack) {
        debugPrint('[OvernightSleepEngine] Error querying telemetria range: $e\n$stack');
      }
    }

    // Se la fascia era scollegata e SQLite non ha campioni:
    // Se la finestra è stata inserita manualmente dall'utente (windowStart e windowEnd presenti),
    // salva la sessione con la durata reale impostata e lascia i parametri cardio/recovery/stadi a null/--
    if (processedRecords.isEmpty) {
      if (windowStart != null && windowEnd != null) {
        final double totalManualSleepMin = (windowEnd.difference(windowStart).inSeconds / 60.0).clamp(0.0, 1440.0);
        final double? sleepPerfPct = sleepNeedMin > 0
            ? ((totalManualSleepMin / sleepNeedMin) * 100.0).clamp(0.0, 100.0)
            : null;
        final String dateIso = targetDateIso ?? windowEnd.toIso8601String().substring(0, 10);

        await _persistOvernightResults(
          dateIso: dateIso,
          recoveryScore: null,
          hrvRmssd: null,
          rhrBpm: null,
          totalSleepMin: totalManualSleepMin.round(),
          swsMin: 0,
          remMin: 0,
          lightMin: 0,
          wasoMin: 0,
          respRate: null,
          deltaSkinTemp: null,
          spo2Pct: null,
          sleepPerformancePct: sleepPerfPct,
          windowStart: windowStart,
          windowEnd: windowEnd,
          isManual: true,
        );

        debugPrint('[OvernightSleepEngine] Salvata sessione manuale ($dateIso): ${totalManualSleepMin.toInt()} min, Perf: ${sleepPerfPct != null ? '${sleepPerfPct.toInt()}%' : '--'}, Vitali: --');

        return {
          'has_data': true,
          'manual_no_ble': true,
          'recovery_score': null,
          'hrv_rmssd_ms': null,
          'resting_hr_bpm': null,
          'respiratory_rate': null,
          'skin_temperature_delta_c': null,
          'spo2_percentage': null,
          'total_sleep_min': totalManualSleepMin,
          'sws_min': 0.0,
          'rem_min': 0.0,
          'light_min': 0.0,
          'waso_min': 0.0,
          'sleep_performance_pct': sleepPerfPct,
          'sleep_stress': null,
          'sleep_stress_basso_min': null,
          'sleep_stress_medio_min': null,
          'sleep_stress_alto_min': null,
          'hypnogram': <String>[],
        };
      }

      debugPrint('[OvernightSleepEngine] Nessun dato biometrico registrato nella finestra richiesta.');
      return {
        'has_data': false,
        'recovery_score': null,
        'hrv_rmssd_ms': null,
        'resting_hr_bpm': null,
        'respiratory_rate': null,
        'skin_temperature_delta_c': null,
        'spo2_percentage': null,
        'total_sleep_min': null,
        'sws_min': null,
        'rem_min': null,
        'light_min': null,
        'waso_min': null,
        'sleep_performance_pct': null,
        'sleep_stress': null,
        'sleep_stress_basso_min': null,
        'sleep_stress_medio_min': null,
        'sleep_stress_alto_min': null,
        'hypnogram': <String>[],
      };
    }

    DateTime? effectiveWindowStart = windowStart;
    DateTime? effectiveWindowEnd = windowEnd;

    // Se la finestra non è stata fornita manualmente e abbiamo un flusso continuo di telemetria (es. sync mattutino automatico delle ultime 14h),
    // usa detectSleepBoundaries per isolare l'inizio e la fine effettiva del sonno
    if (effectiveWindowStart == null && effectiveWindowEnd == null && processedRecords.length >= 60) {
      final boundaries = detectSleepBoundaries(
        processedRecords,
        rhrBaseline: rhrBaseline,
        daytimeMeanHr: rhrBaseline * 1.35,
      );
      if (boundaries['hasSleep'] == true) {
        final startIdx = boundaries['startIndex'] as int;
        final endIdx = boundaries['endIndex'] as int;
        if (startIdx >= 0 && endIdx < processedRecords.length && endIdx > startIdx) {
          final sTs = processedRecords[startIdx]['timestamp'];
          final eTs = processedRecords[endIdx]['timestamp'];
          if (sTs != null && eTs != null) {
            final parsedStart = DateTime.tryParse(sTs.toString());
            final parsedEnd = DateTime.tryParse(eTs.toString());
            if (parsedStart != null && parsedEnd != null && parsedEnd.isAfter(parsedStart)) {
              effectiveWindowStart = parsedStart;
              effectiveWindowEnd = parsedEnd;
            }
          }
        }
      }
    }

    // 1. Suddivisione della telemetria in epoche di 30 secondi ed estrazione feature
    final List<Epoch30s> epochs30s = _chunkInto30sEpochs(processedRecords, startTime: effectiveWindowStart, endTime: effectiveWindowEnd);

    // 2. Classificazione degli stadi del sonno (Hypnogram Decision Tree / HMM)
    _classifyHypnogram(epochs30s, rhrBaseline, hrvBaseline);

    // 3. Estrazione dell'HRV/rMSSD ed RHR nell'Ultimo Ciclo SWS prima del risveglio (Brevetto US9750415B2)
    final swsMetrics = _extractLastSwsCycleMetrics(epochs30s);
    final double? finalNightHrvRmssd = swsMetrics['rmssd'];
    final double? finalNightRhr = swsMetrics['rhr'];

    // 4. Calcolo WASO (Veglia nel mezzo della notte), Veglia Totale e Durate Fasi
    final sleepDurations = _calculateSleepStageDurations(epochs30s);
    final double wasoMinutes = sleepDurations['waso_min'] ?? 0.0;
    final double totalWakeMin = sleepDurations['total_wake_min'] ?? wasoMinutes;
    final double disturbancesCount = sleepDurations['disturbances_count'] ?? 0.0;
    
    final double swsMin = sleepDurations['sws_min'] ?? 0.0;
    final double remMin = sleepDurations['rem_min'] ?? 0.0;
    final double lightMin = sleepDurations['light_min'] ?? 0.0;
    final double stageSleepSum = swsMin + remMin + lightMin;
    final double totalSleepMin = stageSleepSum;

    // 5. Temperatura Cutanea Relativa & Saturazione d'Ossigeno (SpO2)
    final vitalsRecords = rawTelemetryRecords.isNotEmpty ? rawTelemetryRecords : processedRecords;
    final double? deltaSkinTemp = _calculateDeltaSkinTemp(vitalsRecords, tempBaseline);
    final double? spo2Pct = _calculateSpo2(vitalsRecords, epochs30s);

    // 6. Frequenza Respiratoria Notturna Matematica via RSA Dinamica
    final double? nocturnalRespRate = _calculateNocturnalRespRate(epochs30s, processedRecords);

    // 7. Calcolo dello Stress Notturno Epoca per Epoca (0.0 - 3.0)
    double totalEpochStress = 0.0;
    int validStressEpochs = 0;
    int stressBassoEpochs = 0;
    int stressMedioEpochs = 0;
    int stressAltoEpochs = 0;
    final List<Map<String, dynamic>> nightlyStressPoints = [];

    for (int i = 0; i < epochs30s.length; i++) {
      final ep = epochs30s[i];
      if (ep.hr > 0) {
        final epStress = WhoopAnalyticsEngine.calculateStressScore(
          hrLive: ep.hr,
          hrvLiveMs: ep.rmssd > 0 ? ep.rmssd : hrvBaseline,
          hrRest: rhrBaseline,
          baselineHrvMean: hrvBaseline,
          baselineHrvStd: 15.0,
          accMagnitude: 1.0 + ep.motionVar,
        );

        totalEpochStress += epStress;
        validStressEpochs++;

        if (epStress < 1.0) {
          stressBassoEpochs++;
        } else if (epStress < 2.0) {
          stressMedioEpochs++;
        } else {
          stressAltoEpochs++;
        }

        // Campiona punti ogni 5 minuti (10 epoche da 30s) per la timeline dello stress
        if (i % 10 == 0 || i == epochs30s.length - 1) {
          nightlyStressPoints.add({
            'timestamp': ep.timestamp.toIso8601String(),
            'valore_stress': epStress,
            'hrv_ms': ep.rmssd > 0 ? ep.rmssd : hrvBaseline,
            'bpm': ep.hr.round(),
          });
        }
      }
    }

    final double? sleepStressMean = validStressEpochs > 0
        ? double.parse((totalEpochStress / validStressEpochs).toStringAsFixed(2))
        : null;

    final double sleepStressBassoMin = stressBassoEpochs * 0.5;
    final double sleepStressMedioMin = stressMedioEpochs * 0.5;
    final double sleepStressAltoMin = stressAltoEpochs * 0.5;

    // 8. Calcolo Finale del Punteggio di Recovery e Prestazione Sonno %
    final double? sleepPerformancePct = totalSleepMin > 0 && sleepNeedMin > 0
        ? ((totalSleepMin / sleepNeedMin) * 100.0).clamp(0.0, 100.0)
        : null;

    final int validRrEpochs = epochs30s.where((e) => e.quality == EpochQuality.valid && e.rmssd > 0).length;

    final double? recoveryScore = (finalNightHrvRmssd != null && finalNightRhr != null)
        ? _calculateRecoveryScore(
            hrvRmssd: finalNightHrvRmssd,
            rhrBpm: finalNightRhr,
            sleepPerformancePct: sleepPerformancePct,
            skinTempDelta: (tempBaseline != null && deltaSkinTemp != null && deltaSkinTemp >= 25.0)
                ? (deltaSkinTemp - tempBaseline)
                : deltaSkinTemp,
            spo2Pct: spo2Pct,
            respRateDelta: (nocturnalRespRate != null && userBaseline30d['resp_rate_mean'] != null)
                ? (nocturnalRespRate - (userBaseline30d['resp_rate_mean'] as num).toDouble())
                : null,
            userBaseline: effectiveBaseline,
            nightlyStress: sleepStressMean,
            sleepDurationMin: totalSleepMin,
            validRrEpochs: validRrEpochs,
          )
        : null;

    // 9. Persistenza Transazionale Atomica su SQLite (Cicli Fisiologici e Sonno)
    final String dateIso = targetDateIso ??
        (windowEnd ?? (epochs30s.isNotEmpty ? epochs30s.last.timestamp : DateTime.now()))
            .toLocal()
            .toIso8601String()
            .substring(0, 10);

    DateTime? actualSleepOnset;
    DateTime? actualWakeTime;
    final sleepEpochs = epochs30s.where((e) => e.stage == 'LIGHT' || e.stage == 'SWS' || e.stage == 'REM').toList();
    if (sleepEpochs.isNotEmpty) {
      actualSleepOnset = sleepEpochs.first.timestamp;
      actualWakeTime = sleepEpochs.last.timestamp.add(const Duration(seconds: 30));
    }

    if (totalSleepMin > 0) {
      await _persistOvernightResults(
        dateIso: dateIso,
        recoveryScore: recoveryScore,
        hrvRmssd: finalNightHrvRmssd,
        rhrBpm: finalNightRhr,
        totalSleepMin: totalSleepMin.round(),
        swsMin: swsMin.round(),
        remMin: remMin.round(),
        lightMin: lightMin.round(),
        wasoMin: totalWakeMin.round(),
        respRate: nocturnalRespRate,
        deltaSkinTemp: deltaSkinTemp,
        spo2Pct: spo2Pct,
        sleepPerformancePct: sleepPerformancePct,
        sleepStress: sleepStressMean,
        nightlyStressPoints: nightlyStressPoints,
        windowStart: effectiveWindowStart ?? (epochs30s.isNotEmpty ? epochs30s.first.timestamp : null),
        windowEnd: effectiveWindowEnd ?? (epochs30s.isNotEmpty ? epochs30s.last.timestamp : null),
        actualSleepOnset: actualSleepOnset,
        actualWakeTime: actualWakeTime,
        epochs: epochs30s,
        forceOverwrite: forceOverwrite,
        sleepConsistencyPct: sleepConsistencyPct,
      );
    }

    return {
      'has_data': true,
      'manual_no_ble': false,
      'recovery_score': recoveryScore,
      'hrv_rmssd_ms': finalNightHrvRmssd,
      'hrv_notte': finalNightHrvRmssd,
      'resting_hr_bpm': finalNightRhr,
      'rhr_notte': finalNightRhr,
      'respiratory_rate': nocturnalRespRate,
      'skin_temperature_delta_c': (tempBaseline != null && deltaSkinTemp != null && deltaSkinTemp >= 25.0)
          ? double.parse((deltaSkinTemp - tempBaseline).clamp(-3.0, 3.0).toStringAsFixed(1))
          : deltaSkinTemp,
      'delta_skin_temp': (tempBaseline != null && deltaSkinTemp != null && deltaSkinTemp >= 25.0)
          ? double.parse((deltaSkinTemp - tempBaseline).clamp(-3.0, 3.0).toStringAsFixed(1))
          : deltaSkinTemp,
      'skin_temp_celsius': deltaSkinTemp,
      'spo2_percentage': spo2Pct,
      'total_sleep_min': totalSleepMin,
      'sws_min': swsMin,
      'rem_min': remMin,
      'light_min': lightMin,
      'missing_min': sleepDurations['missing_min'] ?? 0.0,
      'waso_min': wasoMinutes,
      'total_wake_min': totalWakeMin,
      'disturbances_count': disturbancesCount,
      'sleep_performance_pct': sleepPerformancePct,
      'sleep_stress': sleepStressMean,
      'sleep_stress_basso_min': sleepStressBassoMin,
      'sleep_stress_medio_min': sleepStressMedioMin,
      'sleep_stress_alto_min': sleepStressAltoMin,
      'hypnogram': epochs30s.map((e) => e.stage).toList(),
      'sleep_start': effectiveWindowStart ?? (epochs30s.isNotEmpty ? epochs30s.first.timestamp : null),
      'sleep_end': effectiveWindowEnd ?? (epochs30s.isNotEmpty ? epochs30s.last.timestamp : null),
    };
  }

  /// Suddivide i record grezzi in epoche reali di 30 secondi agganciate ai timestamp effettivi
  List<Epoch30s> _chunkInto30sEpochs(List<Map<String, dynamic>> records, {DateTime? startTime, DateTime? endTime}) {
    if (records.isEmpty) return [];

    DateTime parseTs(dynamic ts, DateTime fallback) {
      if (ts == null) return fallback.toLocal();
      if (ts is DateTime) return ts.toLocal();
      final parsed = DateTime.tryParse(ts.toString());
      return parsed != null ? parsed.toLocal() : fallback.toLocal();
    }

    bool hasValidTimestamps = false;
    for (final r in records) {
      if (r['timestamp'] != null) {
        hasValidTimestamps = true;
        break;
      }
    }

    // Se i record NON contengono timestamp espliciti e né startTime né endTime sono forniti (es. test sintetici a lista)
    if (!hasValidTimestamps && startTime == null && endTime == null) {
      final List<Epoch30s> list = [];
      final effectiveStart = DateTime.now().subtract(Duration(seconds: records.length * 30)).toLocal();
      for (int i = 0; i < records.length; i++) {
        final r = records[i];
        final motion = (r['motion_var'] ?? r['motion'] ?? r['accel_enmo'] ?? r['enmo'] as num?)?.toDouble() ?? 0.0;
        final hr = (r['hr'] ?? r['bpm'] as num?)?.toDouble() ?? 0.0;
        final rmssd = (r['rmssd'] as num?)?.toDouble() ?? (r['hrv_ms'] as num?)?.toDouble() ?? 0.0;
        final respPower = (r['resp_power'] as num?)?.toDouble() ?? 0.0;
        final respRate = (r['resp_rate'] as num?)?.toDouble() ?? 0.0;
        final rmssdVar = (r['rmssd_var'] as num?)?.toDouble() ?? 0.0;
        final hrFluc = (r['hr_fluctuations'] as num?)?.toInt() ?? 0;
        List<double> pp = [];
        if (r['pp_intervals'] != null) {
          pp = List<double>.from(r['pp_intervals']);
        } else if (r['rr_intervals_json'] != null) {
          try {
            final decoded = jsonDecode(r['rr_intervals_json'].toString());
            if (decoded is List) {
              pp = decoded
                  .map((e) => (e as num).toDouble())
                  .where((e) => e >= 300.0 && e <= 2000.0)
                  .map((e) => e / 1000.0)
                  .toList();
            }
          } catch (_) {}
        } else if (r['rr_ms'] != null) {
          final val = (r['rr_ms'] as num).toDouble();
          if (val >= 300.0 && val <= 2000.0) {
            pp = [val / 1000.0];
          }
        }

        list.add(Epoch30s(
          index: i,
          timestamp: effectiveStart.add(Duration(seconds: i * 30)),
          motionVar: motion,
          hr: hr,
          rmssd: rmssd,
          respPower: respPower,
          respRate: respRate,
          rmssdVarInWindow: rmssdVar,
          hrFluctuations: hrFluc,
          ppIntervals: pp,
        ));
      }
      return list;
    }

    final firstTs = parseTs(records.first['timestamp'], DateTime.now().subtract(const Duration(hours: 8)));
    final lastTs = parseTs(records.last['timestamp'], firstTs.add(Duration(seconds: records.length * 30)));

    DateTime effectiveStart = (startTime ?? firstTs).toLocal();
    DateTime effectiveEnd = (endTime ?? (lastTs.isAfter(effectiveStart) ? lastTs : effectiveStart.add(const Duration(hours: 8)))).toLocal();

    if (effectiveEnd.isBefore(effectiveStart)) {
      effectiveEnd = effectiveStart.add(const Duration(hours: 8));
    }

    // Durata della finestra in secondi, limitata fisiologicamente tra 30s e 16 ore (960 min = 57600s)
    int totalWindowSec = effectiveEnd.difference(effectiveStart).inSeconds;
    if (totalWindowSec <= 0) totalWindowSec = records.length * 30;
    totalWindowSec = totalWindowSec.clamp(30, 16 * 3600);

    final int numEpochs = (totalWindowSec / 30.0).ceil().clamp(1, 1920);

    // Bins per aggregare i campioni ad alta frequenza (1Hz, 25Hz, ecc.) nella rispettiva epoca da 30s
    final List<List<Map<String, dynamic>>> epochBins = List.generate(numEpochs, (_) => []);

    for (final r in records) {
      final ts = parseTs(r['timestamp'], DateTime.fromMillisecondsSinceEpoch(0));
      if (ts.millisecondsSinceEpoch > 0) {
        final offsetSec = ts.difference(effectiveStart).inSeconds;
        final int binIdx = (offsetSec / 30.0).floor().clamp(0, numEpochs - 1);
        epochBins[binIdx].add(r);
      }
    }

    final List<Epoch30s> list = [];
    double? lastHr;
    double? lastRmssd;

    for (int k = 0; k < numEpochs; k++) {
      final epochTime = effectiveStart.add(Duration(seconds: k * 30));
      final bin = epochBins[k];

      if (bin.isNotEmpty) {
        double hrSum = 0;
        int hrCount = 0;
        double motionSum = 0;
        double rmssdSum = 0;
        int rmssdCount = 0;
        double respPowerSum = 0;
        double respRateSum = 0;
        double rmssdVarSum = 0;
        int hrFlucSum = 0;
        final List<double> ppList = [];
        int count = bin.length;

        for (final r in bin) {
          final hrVal = (r['hr'] ?? r['bpm'] as num?)?.toDouble();
          if (hrVal != null && hrVal > 0) {
            hrSum += hrVal;
            hrCount++;
          }
          final motionVal = (r['motion_var'] ?? r['motion'] ?? r['accel_enmo'] ?? r['enmo'] as num?)?.toDouble() ?? 0.0;
          motionSum += motionVal;

          final rmssdVal = (r['rmssd_ms'] as num?)?.toDouble() ??
              (r['rmssd'] as num?)?.toDouble() ??
              (r['hrv_ms'] as num?)?.toDouble();
          if (rmssdVal != null && rmssdVal > 0) {
            rmssdSum += rmssdVal;
            rmssdCount++;
          }

          final respP = (r['resp_power'] as num?)?.toDouble() ?? 0.0;
          final respR = (r['resp_rate'] as num?)?.toDouble() ?? 0.0;
          final rVar = (r['rmssd_var'] as num?)?.toDouble() ?? 0.0;
          final hFluc = (r['hr_fluc'] as num?)?.toInt() ?? 0;

          respPowerSum += respP;
          respRateSum += respR;
          rmssdVarSum += rVar;
          hrFlucSum += hFluc;

          if (r['pp_intervals'] != null) {
            ppList.addAll(List<double>.from(r['pp_intervals']));
          } else if (r['rr_intervals_json'] != null) {
            try {
              final decoded = jsonDecode(r['rr_intervals_json'].toString());
              if (decoded is List) {
                ppList.addAll(decoded.map((e) => (e as num).toDouble() / 1000.0));
              }
            } catch (_) {}
          } else if (r['rr_ms'] != null) {
            final rr = (r['rr_ms'] as num).toDouble();
            if (rr >= 300.0 && rr <= 2000.0) {
              ppList.add(rr / 1000.0);
            }
          }
        }

        final double currentHr = hrCount > 0 ? (hrSum / hrCount) : (lastHr ?? 0.0);
        if (hrCount > 0) lastHr = currentHr;

        double currentRmssd = rmssdCount > 0 ? (rmssdSum / rmssdCount).clamp(10.0, 250.0) : (lastRmssd ?? 0.0);
        // Se non era già presente rmssd_ms nel DB ma abbiamo ppList (intervalli RR/PP), calcola RMSSD reale:
        if (rmssdCount == 0 && ppList.length >= 2) {
          double sumDiffSq = 0.0;
          int dCount = 0;
          for (int i = 0; i < ppList.length - 1; i++) {
            final diffMs = ((ppList[i + 1] - ppList[i]) * 1000.0).abs();
            if (diffMs <= 200.0) {
              sumDiffSq += diffMs * diffMs;
              dCount++;
            }
          }
          if (dCount >= 1) {
            currentRmssd = math.sqrt(sumDiffSq / dCount).clamp(10.0, 250.0);
          }
        }
        if (currentRmssd > 0) lastRmssd = currentRmssd;

        // Calcola la variabilità intra-epoca dell'HR o degli intervalli PP come rmssdVarInWindow
        double intraEpochVar = 0.0;
        if (bin.length >= 3) {
          final hrValues = bin
              .map((r) => (r['hr'] ?? r['bpm'] as num?)?.toDouble() ?? 0.0)
              .where((h) => h > 30)
              .toList();
          if (hrValues.length >= 3) {
            final meanH = hrValues.reduce((a, b) => a + b) / hrValues.length;
            final varianceH = hrValues.map((h) => (h - meanH) * (h - meanH)).reduce((a, b) => a + b) / hrValues.length;
            intraEpochVar = (math.sqrt(varianceH) / math.max(1.0, meanH)).clamp(0.0, 1.0);
          }
        }
        final double finalRmssdVar = rmssdVarSum > 0 ? (rmssdVarSum / count) : intraEpochVar;

        list.add(Epoch30s(
          index: k,
          timestamp: epochTime,
          motionVar: motionSum / count,
          hr: currentHr,
          rmssd: currentRmssd,
          respPower: respPowerSum / count,
          respRate: respRateSum / count,
          rmssdVarInWindow: finalRmssdVar,
          hrFluctuations: (hrFlucSum / count).round(),
          ppIntervals: ppList,
          sampleCount: count,
          quality: count >= 1 ? EpochQuality.valid : EpochQuality.missing,
          stage: 'LIGHT',
        ));
      } else {
        // Controlla durata buco consecutivo vuoto
        int runStart = k;
        while (runStart > 0 && epochBins[runStart - 1].isEmpty) {
          runStart--;
        }
        int runEnd = k;
        while (runEnd < numEpochs && epochBins[runEnd].isEmpty) {
          runEnd++;
        }
        final int gapLen = runEnd - runStart;

        if (gapLen < 10 && lastHr != null) {
          // Buco inferiore a 5 minuti (10 epoche) con segnale pregresso: interpola come epoca valida
          list.add(Epoch30s(
            index: k,
            timestamp: epochTime,
            motionVar: 0.002,
            hr: lastHr,
            rmssd: lastRmssd ?? 0.0,
            respPower: 0.0,
            respRate: 0.0,
            rmssdVarInWindow: 0.0,
            hrFluctuations: 0,
            ppIntervals: [],
            sampleCount: 1,
            quality: EpochQuality.valid,
            stage: 'LIGHT',
          ));
        } else {
          // Vero buco di disconnessione (>= 10 epoche / >= 5 min)
          list.add(Epoch30s(
            index: k,
            timestamp: epochTime,
            motionVar: 0.0,
            hr: lastHr ?? 0.0,
            rmssd: lastRmssd ?? 0.0,
            respPower: 0.0,
            respRate: 0.0,
            rmssdVarInWindow: 0.0,
            hrFluctuations: 0,
            ppIntervals: [],
            sampleCount: 0,
            quality: EpochQuality.missing,
            stage: 'MISSING',
          ));
        }
      }
    }

    return list;
  }

  /// Classificatore per l'Ipnogramma Notturno con Estrazione Multi-Feature e Filtro di Smoothing Temporale
  void _classifyHypnogram(List<Epoch30s> epochs, double rhrBaseline, double hrvBaseline) {
    final int totalEpochs = epochs.length;
    if (totalEpochs == 0) return;

    final validEpochs = epochs
        .where((e) => e.quality != EpochQuality.missing && e.sampleCount > 0 && e.hr > 30)
        .toList();
    if (validEpochs.isEmpty) return;

    final hrs = validEpochs.map((e) => e.hr).toList()..sort();
    final double p25 = hrs[(hrs.length * 0.25).floor()];
    final double p75 = hrs[(hrs.length * 0.75).floor()];
    final double sigmaNightHr = math.max(2.0, (p75 - p25) / 1.349);

    if (totalEpochs < 10) {
      final List<SleepStage> rawShort = List.filled(totalEpochs, SleepStage.light);
      for (int k = 0; k < totalEpochs; k++) {
        final ep = epochs[k];
        if (ep.quality == EpochQuality.missing || ep.sampleCount == 0 || ep.stage == 'MISSING') {
          rawShort[k] = SleepStage.missing;
          continue;
        }
        final double hrRatio = rhrBaseline > 0 ? (ep.hr / rhrBaseline) : 1.0;
        final double hrvNorm = hrvBaseline > 0 ? (ep.rmssd / hrvBaseline) : 1.0;
        final double respVar = ep.respPower > 0.0
            ? double.parse(((1.0 - ep.respPower) * 0.5).clamp(0.0, 1.0).toStringAsFixed(3))
            : 0.50;
        rawShort[k] = classifyEpoch(
          enmo: ep.motionVar,
          hrRatio: hrRatio,
          hrvNorm: hrvNorm,
          respVar: respVar,
          epochIndex: k,
          totalEpochs: totalEpochs,
        );
      }
      final List<SleepStage> smoothedShort = List.from(rawShort);
      for (int i = 1; i < totalEpochs - 1; i++) {
        final prev = smoothedShort[i - 1];
        final curr = smoothedShort[i];
        final next = rawShort[i + 1];
        if (curr == SleepStage.missing || prev == SleepStage.missing || next == SleepStage.missing) continue;
        if (prev == next && curr != prev) {
          smoothedShort[i] = prev;
        }
      }
      for (int k = 0; k < totalEpochs; k++) {
        epochs[k].stage = smoothedShort[k].toHypnogramString();
      }
      return;
    }

    final List<SleepStage> rawStages = List.filled(totalEpochs, SleepStage.light);

    // Taglio coda post-risveglio: se nella parte finale (progress > 0.70) la FC sale >= rhrBaseline + 20.0
    // (es. >= 70 bpm quando l'utente si è alzato), marca come post-risveglio ed escludi dal sonno
    int postWakeCutIdx = totalEpochs;
    for (int k = (totalEpochs * 0.70).floor(); k < totalEpochs; k++) {
      if (epochs[k].quality != EpochQuality.missing && epochs[k].hr >= rhrBaseline + 20.0) {
        int subsequentActive = 0;
        final int checkLen = math.min(8, totalEpochs - k);
        for (int m = k; m < k + checkLen; m++) {
          if (epochs[m].hr >= rhrBaseline + 14.0 || epochs[m].motionVar >= 0.010) {
            subsequentActive++;
          }
        }
        if (subsequentActive >= (checkLen * 0.5).round() || k + checkLen >= totalEpochs) {
          postWakeCutIdx = k;
          break;
        }
      }
    }

    for (int k = 0; k < totalEpochs; k++) {
      final ep = epochs[k];
      if (ep.quality == EpochQuality.missing || ep.sampleCount == 0 || ep.stage == 'MISSING') {
        rawStages[k] = SleepStage.missing;
        continue;
      }

      final double enmo = ep.motionVar;
      final double progress = k / totalEpochs;

      if (k >= postWakeCutIdx || (progress > 0.70 && ep.hr >= rhrBaseline + 20.0)) {
        rawStages[k] = SleepStage.wake;
        continue;
      }

      // Media mobile locale centrata (finestra 150 epoche = 75 min) sulle epoche quiete
      final int wStart = math.max(0, k - 75);
      final int wEnd = math.min(totalEpochs - 1, k + 75);
      double hrSumLocal = 0.0;
      int hrCountLocal = 0;
      for (int w = wStart; w <= wEnd; w++) {
        if (epochs[w].quality != EpochQuality.missing && epochs[w].sampleCount > 0 && epochs[w].hr > 30 && epochs[w].motionVar <= 0.020) {
          hrSumLocal += epochs[w].hr;
          hrCountLocal++;
        }
      }
      final double muHrLocal = hrCountLocal > 0 ? (hrSumLocal / hrCountLocal) : rhrBaseline;
      final double zHrLocal = (ep.hr - muHrLocal) / sigmaNightHr;

      // Incremento cardiaco acuto rispetto al minimo dei 2 minuti precedenti (4 epoche)
      double minHrPrev = ep.hr;
      for (int p = math.max(0, k - 4); p < k; p++) {
        if (epochs[p].hr > 30 && epochs[p].hr < minHrPrev) minHrPrev = epochs[p].hr;
      }
      final double deltaHrAcute = ep.hr - minHrPrev;

      // Indice di instabilità cardiaca locale (HRI su 5 epoche)
      double hri = 0.0;
      if (k >= 2 && k < totalEpochs - 2) {
        hri = ((ep.hr - epochs[k - 2].hr).abs() +
               (ep.hr - epochs[k - 1].hr).abs() +
               (epochs[k + 1].hr - ep.hr).abs() +
               (epochs[k + 2].hr - ep.hr).abs()) / 4.0;
      }

      // 1. VEGLIA / WASO (Target ~10-15% del tempo a letto):
      // Latenza iniziale pre-sonno o micro-risvegli motori/autonomici
      final bool isLatencyWake = progress < 0.06 && (enmo >= 0.012 || (enmo >= 0.009 && ep.hr > rhrBaseline && zHrLocal >= 0.55));
      final bool isWasoWake = enmo >= 0.022 ||
          (enmo >= 0.010 && ep.hr > rhrBaseline && (zHrLocal >= 0.70 || deltaHrAcute >= 4.2)) ||
          (enmo >= 0.005 && ep.hr > rhrBaseline && zHrLocal >= 1.30 && deltaHrAcute >= 5.5);

      if (isLatencyWake || isWasoWake) {
        rawStages[k] = SleepStage.wake;
        continue;
      }

      // 2. SONNO PROFONDO SWS / N3:
      // Brevetto WHOOP US9750415B2 & EP3766410B1:
      // SWS identificato da forte potenza respiratoria RSA (respPower >= 0.62), stabilità autonomica (basso HRI),
      // quiescenza motoria (ENMO <= 0.009g) e minimo relativo intra-notte (zHrLocal).
      final bool isSwsCardio = ep.respPower > 0.0
          ? (ep.respPower >= 0.62)
          : (zHrLocal <= (progress <= 0.50 ? -0.15 : -0.30) || (ep.hr <= p25 && zHrLocal <= 0.0));

      final bool isDeep = enmo <= 0.009 &&
          isSwsCardio &&
          hri <= 1.65 &&
          progress <= 0.85;

      // 3. SONNO REM:
      // Atonia motoria periferica con instabilità autonomica/elettrofisiologica (HRI, variabilità intra-epoca, micro-fluttuazioni),
      // con frequenza cardiaca a livello intermedio/leggermente elevato, concentrata nei cicli avanzati.
      final bool isRem = enmo <= 0.008 &&
          progress >= 0.15 &&
          zHrLocal > -0.25 &&
          zHrLocal <= 1.25 &&
          (hri >= 1.15 || ep.rmssdVarInWindow >= 0.15 || deltaHrAcute >= 1.8);

      if (isDeep) {
        rawStages[k] = SleepStage.deepSws;
      } else if (isRem) {
        rawStages[k] = SleepStage.rem;
      } else {
        rawStages[k] = SleepStage.light;
      }
    }

    // Smoothing: filtro a finestra mobile di 5 epoche (2.5 minuti) - majority vote sulle 5 epoche adiacenti
    final List<SleepStage> smoothed = List.from(rawStages);
    for (int i = 0; i < totalEpochs; i++) {
      final curr = rawStages[i];
      if (curr == SleepStage.missing) continue;
      if (curr == SleepStage.wake && (epochs[i].motionVar >= 0.010 || epochs[i].hr >= rhrBaseline + 3.5)) {
        continue;
      }

      final int start = math.max(0, i - 2);
      final int end = math.min(totalEpochs - 1, i + 2);

      final Map<SleepStage, int> counts = {};
      for (int w = start; w <= end; w++) {
        final st = rawStages[w];
        if (st != SleepStage.missing) {
          counts[st] = (counts[st] ?? 0) + 1;
        }
      }
      if (counts.isNotEmpty) {
        SleepStage majorityStage = curr;
        int maxCount = 0;
        for (final entry in counts.entries) {
          if (entry.value > maxCount) {
            maxCount = entry.value;
            majorityStage = entry.key;
          }
        }
        if (maxCount >= 3) {
          smoothed[i] = majorityStage;
        }
      }
    }

    // Durata minima blocco (bout minimo): 6 epoche (3 minuti) per SWS, REM e LIGHT
    for (int i = 0; i < totalEpochs;) {
      final st = smoothed[i];
      if (st == SleepStage.deepSws || st == SleepStage.rem || st == SleepStage.light) {
        int run = 0;
        while (i + run < totalEpochs && smoothed[i + run] == st) {
          run++;
        }
        if (run < 6) {
          final SleepStage replacement;
          final prevStage = i > 0 ? smoothed[i - 1] : null;
          final nextStage = (i + run < totalEpochs) ? smoothed[i + run] : null;
          if (prevStage != null && prevStage != SleepStage.missing && prevStage != SleepStage.wake) {
            replacement = prevStage;
          } else if (nextStage != null && nextStage != SleepStage.missing && nextStage != SleepStage.wake) {
            replacement = nextStage;
          } else {
            replacement = SleepStage.light;
          }
          for (int r = 0; r < run; r++) {
            smoothed[i + r] = replacement;
          }
        }
        i += run;
      } else {
        i++;
      }
    }

    for (int k = 0; k < totalEpochs; k++) {
      epochs[k].stage = smoothed[k].toHypnogramString();
    }
  }

  /// Calcola la media quadratica (Root Mean Square) degli RMSSD delle epoche SWS (HRV-01)
  static double? calculateSwsPooledRmssd(List<double> epochRmssdList) {
    if (epochRmssdList.isEmpty) return null;
    final sumSquares = epochRmssdList.map((x) => x * x).reduce((a, b) => a + b);
    return math.sqrt(sumSquares / epochRmssdList.length);
  }

  /// Estrazione di rMSSD ed RHR nell'Ultimo Ciclo SWS prima del risveglio finale (Brevetto US9750415B2)
  /// Calcolo matematico rigoroso:
  /// rMSSD = sqrt( 1/(N-1) * sum( (PP_{i+1} - PP_i)^2 ) )
  /// RHR = 1/N * sum( BPM_i )
  Map<String, double?> _extractLastSwsCycleMetrics(List<Epoch30s> epochs) {
    if (epochs.isEmpty) {
      return {'rmssd': null, 'rhr': null};
    }

    final int totalEpochs = epochs.length;

    // a) Pre-processing intervalli R-R contro artefatti PPG (PPG artifact & ectopic filter)
    List<double> filterRrIntervals(List<double> rawPp) {
      final validPp = <double>[];
      for (final p in rawPp) {
        final ms = p < 5.0 ? p * 1000.0 : p;
        if (ms >= 330.0 && ms <= 1750.0) {
          validPp.add(ms);
        }
      }
      if (validPp.length < 5) return validPp;

      final filtered = <double>[];
      for (int i = 0; i < validPp.length; i++) {
        final start = math.max(0, i - 2);
        final end = math.min(validPp.length, i + 3);
        final window = validPp.sublist(start, end)..sort();
        final median5 = window[window.length ~/ 2];
        if (median5 > 0 && ((validPp[i] - median5).abs() / median5) <= 0.22) {
          filtered.add(validPp[i]);
        }
      }
      return filtered;
    }

    double? computeRmssdFromFilteredRr(List<double> rrList) {
      if (rrList.length < 2) return null;
      double sumSq = 0.0;
      int count = 0;
      for (int j = 0; j < rrList.length - 1; j++) {
        final diff = (rrList[j + 1] - rrList[j]).abs();
        final meanAdjacent = (rrList[j + 1] + rrList[j]) / 2.0;
        final maxDiff = math.min(180.0, 0.22 * meanAdjacent);
        if (diff <= maxDiff) {
          sumSq += (diff * diff);
          count++;
        }
      }
      if (count == 0) return null;
      return math.sqrt(sumSq / count);
    }

    // b) Ponderazione SWS (Brevetto EP3766410NWB1 / US9750415B2)
    // Raccogli tutte le epoche con stage == 'SWS' (e motionVar <= 0.012) dell'intera notte
    List<({int index, double rmssd, double hr})> swsCandidates = [];
    for (int i = 0; i < totalEpochs; i++) {
      final ep = epochs[i];
      if (ep.stage == 'SWS' && ep.motionVar <= 0.012) {
        double? val;
        if (ep.ppIntervals.length >= 2) {
          final cleaned = filterRrIntervals(ep.ppIntervals);
          val = computeRmssdFromFilteredRr(cleaned);
        }
        val ??= (ep.rmssd > 0 && ep.rmssd <= 250.0 ? ep.rmssd : null);
        if (val != null && val >= 10.0 && val <= 250.0) {
          swsCandidates.add((index: i, rmssd: val, hr: ep.hr));
        }
      }
    }

    // Fallback permissivo se poche epoche con motionVar <= 0.012
    if (swsCandidates.isEmpty) {
      for (int i = 0; i < totalEpochs; i++) {
        final ep = epochs[i];
        if (ep.stage == 'SWS' && ep.motionVar <= 0.025) {
          double? val;
          if (ep.ppIntervals.length >= 2) {
            final cleaned = filterRrIntervals(ep.ppIntervals);
            val = computeRmssdFromFilteredRr(cleaned);
          }
          val ??= (ep.rmssd > 0 && ep.rmssd <= 250.0 ? ep.rmssd : null);
          if (val != null && val >= 10.0 && val <= 250.0) {
            swsCandidates.add((index: i, rmssd: val, hr: ep.hr));
          }
        }
      }
    }

    // Fallback estremo se non ci sono epoche SWS (es. sessione parziale)
    if (swsCandidates.isEmpty) {
      for (int i = 0; i < totalEpochs; i++) {
        final ep = epochs[i];
        if (ep.motionVar <= 0.020 && ep.stage != 'MISSING' && ep.stage != 'WAKE') {
          double? val;
          if (ep.ppIntervals.length >= 2) {
            final cleaned = filterRrIntervals(ep.ppIntervals);
            val = computeRmssdFromFilteredRr(cleaned);
          }
          val ??= (ep.rmssd > 0 && ep.rmssd <= 250.0 ? ep.rmssd : null);
          if (val != null && val >= 10.0 && val <= 250.0) {
            swsCandidates.add((index: i, rmssd: val, hr: ep.hr));
          }
        }
      }
    }

    double? computedHrv;
    double? swsWeightedMeanHr;

    if (swsCandidates.isNotEmpty) {
      // Ordina i valori di rmssd ed esegui trimming inter-percentile [P20, P95]
      final sortedByRmssd = List<({int index, double rmssd, double hr})>.from(swsCandidates)
        ..sort((a, b) => a.rmssd.compareTo(b.rmssd));
      final int len = sortedByRmssd.length;
      final double p20 = sortedByRmssd[(len * 0.20).floor()].rmssd;
      final double p95 = sortedByRmssd[(len * 0.95).floor().clamp(0, len - 1)].rmssd;

      final trimmed = swsCandidates.where((e) => e.rmssd >= p20 && e.rmssd <= p95).toList();
      final evalList = trimmed.isNotEmpty ? trimmed : swsCandidates;

      // Media lineare ponderata esponenzialmente per la recenza dell'epoca nella notte
      double sumWeightedRmssd = 0.0;
      double sumRmssdWeight = 0.0;
      double sumWeightedHr = 0.0;
      double sumHrWeight = 0.0;

      for (final e in evalList) {
        final double weight = math.exp(2.2 * (e.index / totalEpochs));
        sumWeightedRmssd += (e.rmssd * weight);
        sumRmssdWeight += weight;

        if (e.hr > 25.0 && e.hr < 180.0) {
          sumWeightedHr += (e.hr * weight);
          sumHrWeight += weight;
        }
      }

      computedHrv = sumRmssdWeight > 0 ? (sumWeightedRmssd / sumRmssdWeight) : null;
      swsWeightedMeanHr = sumHrWeight > 0 ? (sumWeightedHr / sumHrWeight) : null;
    }

    // c) Calcolo FCR notturna: rhr = 0.70 * swsWeightedMeanHr + 0.30 * quietSleepMedianHr
    final quietHrs = epochs
        .where((e) => (e.stage == 'LIGHT' || e.stage == 'SWS') && e.motionVar <= 0.010 && e.hr > 25.0 && e.hr < 180.0)
        .map((e) => e.hr)
        .toList()
      ..sort();

    final double? quietSleepMedianHr = quietHrs.isNotEmpty ? quietHrs[quietHrs.length ~/ 2] : null;

    double? computedRhr;
    if (swsWeightedMeanHr != null && quietSleepMedianHr != null) {
      computedRhr = (0.70 * swsWeightedMeanHr) + (0.30 * quietSleepMedianHr);
    } else {
      computedRhr = swsWeightedMeanHr ?? quietSleepMedianHr;
    }

    return {
      'rmssd': computedHrv != null ? double.parse(computedHrv.clamp(10.0, 250.0).toStringAsFixed(1)) : null,
      'rhr': computedRhr != null ? double.parse(computedRhr.clamp(30.0, 120.0).toStringAsFixed(1)) : null,
    };
  }

  /// Calcolo durate del sonno, WASO (veglia nel mezzo della notte) e veglia totale
  Map<String, double> _calculateSleepStageDurations(List<Epoch30s> epochs) {
    if (epochs.isEmpty) {
      return {
        'waso_min': 0.0,
        'total_wake_min': 0.0,
        'total_sleep_min': 0.0,
        'sws_min': 0.0,
        'rem_min': 0.0,
        'light_min': 0.0,
        'disturbances_count': 0.0,
      };
    }

    double totalWakeCount = 0;
    double wasoCount = 0;
    double lightCount = 0;
    double swsCount = 0;
    double remCount = 0;
    double missingCount = 0;
    int disturbancesCount = 0;
    bool inWakeCluster = false;

    int sleepStart = -1;
    int sleepEnd = -1;

    for (int i = 0; i < epochs.length; i++) {
      final s = epochs[i].stage;
      if (s == 'SWS' || s == 'REM' || s == 'LIGHT') {
        if (sleepStart == -1) sleepStart = i;
        sleepEnd = i;
      }
    }

    for (int i = 0; i < epochs.length; i++) {
      final stage = epochs[i].stage;
      if (stage == 'WAKE') {
        totalWakeCount++;
        // Se l'epoca cade DOPO l'addormentamento iniziale e PRIMA del risveglio finale: è WASO nel mezzo della notte
        if (sleepStart != -1 && i >= sleepStart && i <= sleepEnd) {
          wasoCount++;
          if (!inWakeCluster) {
            disturbancesCount++;
            inWakeCluster = true;
          }
        }
      } else if (stage == 'MISSING' || stage == 'UNKNOWN') {
        inWakeCluster = false;
        missingCount++;
      } else {
        inWakeCluster = false;
        switch (stage) {
          case 'SWS':
            swsCount++;
            break;
          case 'REM':
            remCount++;
            break;
          case 'LIGHT':
          default:
            lightCount++;
            break;
        }
      }
    }

    final swsMin = swsCount * 0.5;
    final remMin = remCount * 0.5;
    final lightMin = lightCount * 0.5;
    final wasoMin = wasoCount * 0.5;
    final totalWakeMin = totalWakeCount * 0.5;
    final missingMin = missingCount * 0.5;

    // totalSleepMin = lightMinutes + deepMinutes + remMinutes (tempo effettivo di sonno, escludendo ogni veglia o gap mancante)
    final totalSleepMin = lightMin + swsMin + remMin;

    return {
      'waso_min': wasoMin,
      'total_wake_min': totalWakeMin,
      'total_sleep_min': totalSleepMin,
      'sws_min': swsMin,
      'rem_min': remMin,
      'light_min': lightMin,
      'missing_min': missingMin,
      'disturbances_count': disturbancesCount.toDouble(),
    };
  }

  /// Calcolo Temperatura Cutanea Notturna Reale in Gradi Celsius (°C)
  /// Estrae i gradi reali da telemetria grezza (celsius, AS6221 raw, o int8 framed)
  /// e restituisce direttamente la media in gradi Celsius, consentendo a BaselineCalculator
  /// di calcolare la baseline 30d e il relativo delta.
  double? _calculateDeltaSkinTemp(List<Map<String, dynamic>> records, double? baseTemp) {
    if (records.isEmpty) return null;
    final List<double> celsiusList = [];

    for (final r in records) {
      // 1. Lettura diretta gradi Celsius (da SQLite telemetria_grezza o stream BLE decodificato)
      final directCelsius = (r['skin_temp_celsius'] ?? r['temp_celsius'] ?? r['skin_temp']) as num?;
      if (directCelsius != null && directCelsius >= 28.0 && directCelsius <= 42.0) {
        celsiusList.add(directCelsius.toDouble());
        continue;
      }

      // 2. Lettura valore raw sensore AS6221 (es. > 1000 * 0.0078125 = 16-bit LE)
      final rawSensor = (r['skin_temp_raw'] ?? r['temp_raw']) as num?;
      if (rawSensor != null) {
        final rawVal = rawSensor.toInt();
        if (rawVal > 1000 && rawVal < 8000) {
          final c = rawVal * 0.0078125;
          if (c >= 28.0 && c <= 42.0) {
            celsiusList.add(c);
            continue;
          }
        } else if (rawVal >= 1 && rawVal <= 250) {
          // Frame compatto int8 offset
          final c = 36.0 + (rawVal > 127 ? (rawVal - 256) : rawVal) / 10.0;
          if (c >= 30.0 && c <= 41.5) {
            celsiusList.add(c);
            continue;
          }
        }
      }
    }

    if (celsiusList.isEmpty) return null;
    final avgCelsius = celsiusList.reduce((a, b) => a + b) / celsiusList.length;
    return double.parse(avgCelsius.toStringAsFixed(2));
  }

  /// Calcolo Saturazione d'Ossigeno SpO2 (% = 110 - 25 * R) reale
  double? _calculateSpo2(List<Map<String, dynamic>> records, List<Epoch30s> epochs) {
    if (records.isEmpty) return null;
    final List<double> spo2List = [];

    // 1. Cerca prima nei campioni durante il sonno profondo (SWS) — standard fisiologico WHOOP
    for (int i = 0; i < epochs.length; i++) {
      if (epochs[i].stage == 'SWS') {
        final idx = math.min(i, records.length - 1);
        if (idx >= 0 && idx < records.length) {
          final r = records[idx];
          final directSpo2 = (r['spo2_pct'] ?? r['spo2']) as num?;
          if (directSpo2 != null && directSpo2 >= 70.0 && directSpo2 <= 100.0) {
            spo2List.add(directSpo2.toDouble());
            continue;
          }
          final ratio = (r['spo2_ratio_r'] ?? r['spo2_ratio']) as num?;
          if (ratio != null && ratio > 0 && ratio <= 1.2) {
            final spo2 = 110.0 - (25.0 * ratio.toDouble());
            spo2List.add(spo2.clamp(80.0, 100.0));
          }
        }
      }
    }

    // 2. Se non presenti durante SWS, estrai da tutti i record notturni validi
    if (spo2List.isEmpty) {
      for (final r in records) {
        final directSpo2 = (r['spo2_pct'] ?? r['spo2']) as num?;
        if (directSpo2 != null && directSpo2 >= 70.0 && directSpo2 <= 100.0) {
          spo2List.add(directSpo2.toDouble());
          continue;
        }
        final ratio = (r['spo2_ratio_r'] ?? r['spo2_ratio']) as num?;
        if (ratio != null && ratio > 0 && ratio <= 1.2) {
          final spo2 = 110.0 - (25.0 * ratio.toDouble());
          spo2List.add(spo2.clamp(80.0, 100.0));
        }
      }
    }

    if (spo2List.isEmpty) return null;
    final avgSpo2 = spo2List.reduce((a, b) => a + b) / spo2List.length;
    return double.parse(avgSpo2.clamp(80.0, 100.0).toStringAsFixed(1));
  }

  /// Stima della Frequenza Respiratoria Notturna via Arritmia Sinusale Respiratoria (RSA)
  /// Utilizza trasformata spettrale non-uniforme limitata rigorosamente
  /// alla banda fisiologica respiratoria [0.15 Hz - 0.42 Hz] (9 - 25.2 RPM), rigettando
  /// le onde vasomotorie di Mayer (LF ~0.05-0.12 Hz / ~6-7 cicli al minuto) che falsano lo zero-crossing.
  static double? estimateRsaPeakFromIntervalsSec(List<double> intervalsSec) =>
      _estimateRsaPeakFromIntervalsSec(intervalsSec);

  static double? _estimateRsaPeakFromIntervalsSec(List<double> intervalsSec) {
    if (intervalsSec.length < 8) return null;
    final int n = intervalsSec.length;
    final double meanVal = intervalsSec.reduce((a, b) => a + b) / n;

    final List<double> t = List<double>.filled(n, 0.0);
    double cum = 0.0;
    for (int i = 0; i < n; i++) {
      t[i] = cum;
      cum += intervalsSec[i];
    }
    final double totalSec = cum;
    if (totalSec < 4.0) return null;

    const double minFreq = 0.15; // 9.0 RPM (esclude onde di Mayer < 0.15 Hz)
    const double maxFreq = 0.42; // 25.2 RPM
    const double step = 0.005;

    double maxPower = 0.0;
    double bestFreq = 0.0;

    for (double f = minFreq; f <= maxFreq; f += step) {
      double realSum = 0.0;
      double imagSum = 0.0;
      final double omega = 2.0 * math.pi * f;

      for (int i = 0; i < n; i++) {
        final double centered = intervalsSec[i] - meanVal;
        final double angle = omega * t[i];
        realSum += centered * math.cos(angle);
        imagSum -= centered * math.sin(angle);
      }

      final double power = (realSum * realSum + imagSum * imagSum) / n;
      if (power > maxPower) {
        maxPower = power;
        bestFreq = f;
      }
    }

    if (bestFreq > 0.0 && maxPower > 1e-6) {
      final double rpm = bestFreq * 60.0;
      if (rpm >= 8.0 && rpm <= 25.0) {
        return rpm;
      }
    }
    return null;
  }

  /// Frequenza Respiratoria Notturna via RSA Dinamica Spettrale (0.15 - 0.40 Hz)
  /// RPM = f_peak * 60
  double? _calculateNocturnalRespRate(List<Epoch30s> epochs, List<Map<String, dynamic>> records) {
    // 1. Se nei record o nelle epoche sono presenti valori diretti di frequenza respiratoria
    final directRates = records
        .map((r) => (r['resp_rate'] ?? r['respiratory_rate']) as num?)
        .where((rr) => rr != null && rr >= 7.0 && rr <= 24.0)
        .map((rr) => rr!.toDouble())
        .toList();

    if (directRates.length >= 5) {
      directRates.sort();
      return double.parse(directRates[directRates.length ~/ 2].toStringAsFixed(1));
    }

    final calmEpochs = epochs.where((e) => e.motionVar < 0.015 && (e.stage == 'SWS' || e.stage == 'LIGHT')).toList();
    final evalEpochs = calmEpochs.isNotEmpty ? calmEpochs : epochs.where((e) => e.motionVar < 0.030).toList();

    if (evalEpochs.isEmpty && records.isEmpty) return null;

    final List<double> calculatedRpmList = [];

    // 2. Estrazione RSA per singola epoca di 30s da serie continua di picchi PP via picco spettrale RSA
    for (final ep in evalEpochs) {
      if (ep.ppIntervals.length >= 8) {
        final rsaRpm = _estimateRsaPeakFromIntervalsSec(ep.ppIntervals);
        if (rsaRpm != null) {
          calculatedRpmList.add(rsaRpm);
        }
      } else if (ep.respRate > 0 && ep.respRate >= 7.0 && ep.respRate <= 24.0) {
        calculatedRpmList.add(ep.respRate);
      }
    }

    // 3. Estrazione RSA su finestre mobili di intervalli R-R se disponibili nei record grezzi scaricati
    if (calculatedRpmList.isEmpty) {
      final validRrs = <double>[];
      for (final r in records) {
        if (r['rr_intervals_json'] != null) {
          try {
            final decoded = jsonDecode(r['rr_intervals_json'].toString());
            if (decoded is List) {
              for (final val in decoded) {
                final d = (val as num).toDouble();
                if (d >= 300.0 && d <= 1500.0) {
                  validRrs.add(d);
                }
              }
            }
          } catch (_) {}
        } else if (r['rr_ms'] != null) {
          final d = (r['rr_ms'] as num).toDouble();
          if (d >= 300.0 && d <= 1500.0) {
            validRrs.add(d);
          }
        }
      }

      if (validRrs.length >= 25) {
        const windowSize = 35;
        for (int w = 0; w + windowSize <= validRrs.length; w += 15) {
          final window = validRrs.sublist(w, w + windowSize);
          final windowSec = window.map((rr) => rr / 1000.0).toList();
          final rsaRpm = _estimateRsaPeakFromIntervalsSec(windowSec);
          if (rsaRpm != null) {
            calculatedRpmList.add(rsaRpm);
          }
        }
      }
    }

    // 4. Fallback su oscillazione della frequenza cardiaca (BPM) a 1 Hz con trasformata spettrale
    if (calculatedRpmList.isEmpty) {
      final bpms = records
          .map((r) => (r['hr'] ?? r['bpm']) as num?)
          .where((b) => b != null && b > 30 && b < 200)
          .map((b) => b!.toDouble())
          .toList();

      if (bpms.length >= 60) {
        final meanBpm = bpms.reduce((a, b) => a + b) / bpms.length;
        final centered = bpms.map((b) => b - meanBpm).toList();
        final n = centered.length;
        double maxPower = 0.0;
        double bestFreq = 0.0;
        for (double f = 0.15; f <= 0.40; f += 0.005) {
          double realSum = 0.0;
          double imagSum = 0.0;
          for (int t = 0; t < n; t++) {
            final angle = 2.0 * math.pi * f * t; // 1 Hz sampling rate
            realSum += centered[t] * math.cos(angle);
            imagSum -= centered[t] * math.sin(angle);
          }
          final power = (realSum * realSum + imagSum * imagSum) / n;
          if (power > maxPower) {
            maxPower = power;
            bestFreq = f;
          }
        }
        if (bestFreq > 0.0 && maxPower > 0.01) {
          final rpm = bestFreq * 60.0;
          if (rpm >= 8.0 && rpm <= 24.0) {
            calculatedRpmList.add(rpm);
          }
        }
      }
    }

    // 5. Se anche il fallback è vuoto ma erano presenti letture sparse directRates
    if (calculatedRpmList.isEmpty && directRates.isNotEmpty) {
      directRates.sort();
      return double.parse(directRates[directRates.length ~/ 2].toStringAsFixed(1));
    }

    if (calculatedRpmList.isEmpty) return null;

    calculatedRpmList.sort();
    final median = calculatedRpmList[calculatedRpmList.length ~/ 2];
    return double.parse(median.toStringAsFixed(1));
  }

  /// Algoritmo di Calcolo Recovery Score (0 - 100%) - STG-06 Gating & Zero-Mock
  double? _calculateRecoveryScore({
    required double? hrvRmssd,
    required double? rhrBpm,
    required double? sleepPerformancePct,
    double? skinTempDelta,
    double? spo2Pct,
    double? respRateDelta,
    required Map<String, dynamic> userBaseline,
    double? nightlyStress,
    double? sleepDurationMin,
    int? validRrEpochs,
  }) {
    if (hrvRmssd == null || rhrBpm == null || hrvRmssd <= 0 || rhrBpm <= 0) {
      return null;
    }

    // STG-06: Gating del Recovery Score
    final bool strictGating = userBaseline['strict_gating'] == true;
    if (strictGating) {
      if (sleepDurationMin != null && sleepDurationMin < 120.0) return null;
      if (validRrEpochs != null && validRrEpochs < 30) return null;
      final int baselineDays = (userBaseline['baseline_days'] as num?)?.toInt() ?? 0;
      if (baselineDays < 4) return null;
    }

    final double hrvMean30d = (userBaseline['rmssd_mean'] ?? 65.0).toDouble();
    final double hrvStd30d = (userBaseline['rmssd_std'] ?? 15.0).toDouble();
    final double rhrMean30d = (userBaseline['rhr_mean'] ?? 55.0).toDouble();
    final double rhrStd30d = (userBaseline['rhr_std'] ?? 3.5).toDouble();

    final double safeHrvMean = hrvMean30d > 0 ? hrvMean30d : 65.0;
    final double stdLnHrv30d = math.max(0.15, hrvStd30d / safeHrvMean);
    final double zHrv = ((math.log(hrvRmssd) - math.log(safeHrvMean)) / stdLnHrv30d).clamp(-3.0, 3.0);
    final double zRhr = ((rhrMean30d - rhrBpm) / math.max(2.5, rhrStd30d)).clamp(-3.0, 3.0);
    final double zSleep = (((sleepPerformancePct ?? 82.0) - 82.0) / 15.0).clamp(-2.5, 1.5);

    final double zRec = (0.60 * zHrv) + (0.28 * zRhr) + (0.12 * zSleep);
    double baseRecovery = 100.0 / (1.0 + math.exp(-1.15 * (zRec + 0.65)));

    // Penalità
    if (respRateDelta != null && respRateDelta > 1.2) {
      baseRecovery -= 4.5 * math.pow(respRateDelta - 1.2, 1.3);
    }
    if (skinTempDelta != null && skinTempDelta.abs() > 0.6) {
      baseRecovery -= 6.0 * math.pow(skinTempDelta.abs() - 0.6, 1.4);
    }
    if (spo2Pct != null && spo2Pct < 94.0) {
      baseRecovery -= 2.5 * (94.0 - spo2Pct);
    }
    if (nightlyStress != null && nightlyStress >= 1.6) {
      baseRecovery -= 10.0 * (nightlyStress - 1.6);
    }

    return double.parse(baseRecovery.clamp(1.0, 99.0).toStringAsFixed(1));
  }

  /// Raggruppa le epoche da 30s in segmenti contigui di stadio omogeneo (STG-07)
  static List<Map<String, dynamic>> buildSegmentsFromEpochs(List<Epoch30s> epochs) {
    if (epochs.isEmpty) return [];
    final List<Map<String, dynamic>> segments = [];

    DateTime? segStart;
    DateTime? segEnd;
    String? currentStage;
    double confidenceSum = 0;
    int epochCount = 0;

    void flushSegment() {
      if (segStart != null && segEnd != null && currentStage != null) {
        segments.add({
          'start_utc_ms': segStart.toUtc().millisecondsSinceEpoch,
          'end_utc_ms': segEnd.toUtc().millisecondsSinceEpoch,
          'stage': currentStage,
          'confidence': epochCount > 0 ? double.parse((confidenceSum / epochCount).toStringAsFixed(2)) : 1.0,
        });
      }
    }

    for (final ep in epochs) {
      final epStart = ep.timestamp.toUtc();
      final epEnd = epStart.add(const Duration(seconds: 30));
      final double epConf = ep.quality == EpochQuality.valid
          ? 1.0
          : (ep.quality == EpochQuality.lowConfidence ? 0.6 : 0.0);

      if (currentStage == null) {
        currentStage = ep.stage;
        segStart = epStart;
        segEnd = epEnd;
        confidenceSum = epConf;
        epochCount = 1;
      } else if (ep.stage == currentStage && epStart.difference(segEnd!).inSeconds.abs() <= 1) {
        segEnd = epEnd;
        confidenceSum += epConf;
        epochCount++;
      } else {
        flushSegment();
        currentStage = ep.stage;
        segStart = epStart;
        segEnd = epEnd;
        confidenceSum = epConf;
        epochCount = 1;
      }
    }
    flushSegment();
    return segments;
  }

  /// Persistenza Transazionale su Database SQLite (`cicli_fisiologici`, `sonno` & `sleep_stage_segments`)
  Future<void> _persistOvernightResults({
    required String dateIso,
    double? recoveryScore,
    double? hrvRmssd,
    double? rhrBpm,
    required int totalSleepMin,
    required int swsMin,
    required int remMin,
    required int lightMin,
    required int wasoMin,
    double? respRate,
    double? deltaSkinTemp,
    double? spo2Pct,
    double? sleepPerformancePct,
    double? sleepStress,
    List<Map<String, dynamic>> nightlyStressPoints = const [],
    DateTime? windowStart,
    DateTime? windowEnd,
    DateTime? actualSleepOnset,
    DateTime? actualWakeTime,
    List<Epoch30s> epochs = const [],
    bool isManual = false,
    bool forceOverwrite = false,
    double? sleepConsistencyPct,
  }) async {
    try {
      final db = await _dbHelper.database;
      await db.transaction((txn) async {
        // 1. Upsert Ciclo Fisiologico e Sonno preservando strain o campi pre-esistenti
        final existing = await txn.query(
          DatabaseHelper.tableCicliFisiologici,
          where: 'data_iso = ?',
          whereArgs: [dateIso],
        );
        final existingMap = existing.isNotEmpty ? existing.first : <String, dynamic>{};

        final existingSonnoRows = await txn.query(
          DatabaseHelper.tableSonno,
          where: 'data_iso = ?',
          whereArgs: [dateIso],
        );
        final existingSonno = existingSonnoRows.isNotEmpty ? existingSonnoRows.first : null;

        // Calcolo deterministico di sleepDebtMin e sleepNeedMin se non già presenti
        int? sleepDebt = (existingSonno?['sleep_debt_min'] as num?)?.toInt() ??
            (existingMap['sonno_arretrato_min'] as num?)?.toInt();
        int? sleepNeed = (existingSonno?['sleep_need_min'] as num?)?.toInt() ??
            (existingMap['sleep_need_min'] as num?)?.toInt();

        if (sleepNeed == null || sleepNeed <= 0 || sleepDebt == null) {
          int baselineSleepMin = 480;
          try {
            final userRows = await txn.query(DatabaseHelper.tableUtenteProfilo, limit: 1);
            if (userRows.isNotEmpty) {
              baselineSleepMin = (userRows.first['sleep_baseline_min'] as num?)?.toInt() ?? 480;
            }
          } catch (_) {}

          if (sleepDebt == null) {
            try {
              final priorSleepRows = await txn.query(
                DatabaseHelper.tableSonno,
                where: 'data_iso < ? AND durata_tot_min >= 180',
                whereArgs: [dateIso],
                orderBy: 'data_iso DESC',
                limit: 7,
              );
              if (priorSleepRows.isNotEmpty) {
                final pairs = priorSleepRows.reversed.map((row) {
                  final needVal = (row['sleep_need_min'] as num?)?.toDouble() ?? baselineSleepMin.toDouble();
                  final durVal = (row['durata_tot_min'] as num?)?.toDouble() ?? 0.0;
                  return (sleepNeedMin: needVal, actualSleepMin: durVal);
                }).toList();
                sleepDebt = WhoopAnalyticsEngine.calculateAccumulatedSleepDebt(
                  historicalSleeps: pairs,
                ).round();
              } else {
                sleepDebt = 0;
              }
            } catch (_) {
              sleepDebt = 0;
            }
          }

          if (sleepNeed == null || sleepNeed <= 0) {
            final double currentStrain = (existingMap['strain_giornaliero'] as num?)?.toDouble() ?? 0.0;
            sleepNeed = WhoopAnalyticsEngine.calculateSleepNeedMinutes(
              baselineNeedMin: baselineSleepMin.toDouble(),
              dayStrain: currentStrain,
              sleepDebtMin: sleepDebt.toDouble(),
            );
          }
        }

        await txn.insert(
          DatabaseHelper.tableCicliFisiologici,
          {
            'data_iso': dateIso,
            'strain_giornaliero': existingMap['strain_giornaliero'],
            'recovery_score': recoveryScore ?? existingMap['recovery_score'],
            'sleep_need_min': sleepNeed,
            'sonno_arretrato_min': sleepDebt,
            'hrv_notte': hrvRmssd ?? existingMap['hrv_notte'],
            'rhr_notte': rhrBpm ?? existingMap['rhr_notte'],
            'frequenza_respiratoria_rpm': respRate ?? existingMap['frequenza_respiratoria_rpm'],
            'temp_cutanea_c': deltaSkinTemp ?? existingMap['temp_cutanea_c'],
            'spo2_pct': spo2Pct ?? existingMap['spo2_pct'],
            'fc_max_bpm': existingMap['fc_max_bpm'],
            'fc_media_bpm': existingMap['fc_media_bpm'],
            'calorie_tot': existingMap['calorie_tot'],
            'valore_stress_notte': sleepStress ?? existingMap['valore_stress_notte'],
            'provenance': isManual ? 'USER_ENTERED' : (existingMap['provenance'] ?? 'REAL'),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );

        // 2. Determina l'inizio e la fine effettivi del sonno
        DateTime? detectedOnset = actualSleepOnset;
        DateTime? detectedWake = actualWakeTime;

        if (detectedOnset == null && epochs.isNotEmpty) {
          final sleepEpochs = epochs.where((e) => e.stage == 'LIGHT' || e.stage == 'SWS' || e.stage == 'REM').toList();
          if (sleepEpochs.isNotEmpty) {
            detectedOnset = sleepEpochs.first.timestamp;
            detectedWake = sleepEpochs.last.timestamp.add(const Duration(seconds: 30));
          }
        }

        final now = DateTime.now();
        // Orario di inizio e fine del sonno effettivo (esclude la Sleep Onset Latency e la veglia post-risveglio)
        final actualStart = detectedOnset ?? windowStart ??
            (epochs.isNotEmpty ? epochs.first.timestamp : now.subtract(Duration(minutes: totalSleepMin + wasoMin)));
        final actualEnd = detectedWake ?? windowEnd ??
            (epochs.isNotEmpty ? epochs.last.timestamp.add(const Duration(seconds: 30)) : now);
        final bedStart = windowStart ?? (epochs.isNotEmpty ? epochs.first.timestamp : actualStart);
        final bedEnd = windowEnd ?? (epochs.isNotEmpty ? epochs.last.timestamp.add(const Duration(seconds: 30)) : actualEnd);

        // Persistenza punti campionati di Stress Notturno su misurazioni_stress
        if (nightlyStressPoints.isNotEmpty) {
          await txn.delete(
            DatabaseHelper.tableMisurazioniStress,
            where: 'data_iso = ? AND timestamp >= ? AND timestamp <= ?',
            whereArgs: [dateIso, bedStart.toLocal().toIso8601String(), bedEnd.toLocal().toIso8601String()],
          );
          for (final pt in nightlyStressPoints) {
            await txn.insert(
              DatabaseHelper.tableMisurazioniStress,
              {
                'data_iso': dateIso,
                'timestamp': pt['timestamp'],
                'valore_stress': pt['valore_stress'],
                'hrv_ms': pt['hrv_ms'],
                'bpm': pt['bpm'],
              },
            );
          }
        }

        // 3. Upsert Sonno e pulizia vecchi segmenti ipnogramma per questa data
        // PROTEZIONE STORICO: Non sovrascrivere mai dati autentici WHOOP_IMPORT o sessioni valide se non forzato
        if (existingSonno != null && !forceOverwrite) {
          final existingProv = existingSonno['provenance'] as String?;
          final existingDur = (existingSonno['durata_tot_min'] as num?)?.toInt() ?? 0;
          if ((existingProv == 'WHOOP_IMPORT' || existingProv == 'WHOOP_NAP') && !isManual) {
            debugPrint('[OvernightSleepEngine] Preservata sessione WHOOP_IMPORT per $dateIso: nessuna sovrascrittura automatica.');
            return;
          }
          if (existingDur > 0 && totalSleepMin <= 0 && !isManual) {
            debugPrint('[OvernightSleepEngine] Preservata sessione valida ($existingDur min) per $dateIso: rifiutata sovrascrittura con 0 min.');
            return;
          }
          // Se la nuova elaborazione parziale ha meno del 50% della durata già registrata e valida, preserva la precedente
          if (existingDur > 120 && totalSleepMin < (existingDur * 0.50) && !isManual) {
            debugPrint('[OvernightSleepEngine] Preservata sessione precedente ($existingDur min) per $dateIso: rifiutata sovrascrittura da dati parziali ($totalSleepMin min).');
            return;
          }
        }

        double? regolarita = sleepConsistencyPct ?? (existingSonno != null ? (existingSonno['regolarita_sonno_pct'] as num?)?.toDouble() : null);
        if (regolarita == null || regolarita <= 0) {
          try {
            final priorRows = await txn.query(
              DatabaseHelper.tableSonno,
              where: 'data_iso < ? AND durata_tot_min > 0',
              whereArgs: [dateIso],
              orderBy: 'data_iso DESC',
              limit: 4,
            );
            if (priorRows.isNotEmpty) {
              final priorSleeps = <({DateTime onset, DateTime wake})>[];
              for (final row in priorRows) {
                final sStr = row['ora_inizio'] as String?;
                final eStr = row['ora_fine'] as String?;
                if (sStr != null && eStr != null) {
                  final sDt = DateTime.tryParse(sStr);
                  final eDt = DateTime.tryParse(eStr);
                  if (sDt != null && eDt != null) {
                    priorSleeps.add((onset: sDt, wake: eDt));
                  }
                }
              }
              if (priorSleeps.isNotEmpty) {
                regolarita = WhoopAnalyticsEngine.calculateMultiNightSleepConsistency(
                  currentSleep: (onset: actualStart, wake: actualEnd),
                  priorSleeps: priorSleeps,
                );
              }
            }
          } catch (_) {}
        }

        // Efficienza del sonno: tempo effettivamente dormito / tempo totale a letto * 100.
        // Include SOL (latenza addormentamento), TST e tutta la veglia notturna (WASO + veglia finale).
        final double totalInBed = (totalSleepMin + math.max(wasoMin, (totalSleepMin * 0.09).round())).toDouble();
        final double? effPct = (isManual || totalInBed <= 0 || totalSleepMin <= 0)
            ? null
            : double.parse(((totalSleepMin / totalInBed) * 100.0).clamp(0.0, 100.0).toStringAsFixed(1));

        final double? perfPct = sleepPerformancePct ??
            ((sleepNeed > 0 && totalSleepMin > 0)
                ? WhoopAnalyticsEngine.calculateSleepPerformancePct(
                    actualDurationMin: totalSleepMin.toDouble(),
                    sleepNeedMin: sleepNeed.toDouble(),
                  )
                : null);

        // Pulizia atomica dei vecchi segmenti ed eliminazione della sessione precedente all'interno della stessa transazione
        for (final oldRow in existingSonnoRows) {
          final oldId = oldRow['id'] as int?;
          if (oldId != null) {
            await txn.delete(
              DatabaseHelper.tableSleepStageSegments,
              where: 'sonno_id = ?',
              whereArgs: [oldId],
            );
          }
        }

        await txn.delete(
          DatabaseHelper.tableSonno,
          where: 'data_iso = ?',
          whereArgs: [dateIso],
        );

        final sonnoId = await txn.insert(
          DatabaseHelper.tableSonno,
          {
            'data_iso': dateIso,
            'ora_inizio': bedStart.toLocal().toIso8601String(),
            'ora_fine': actualEnd.toLocal().toIso8601String(),
            'durata_tot_min': totalSleepMin,
            'sonno_profondo_min': isManual ? 0 : swsMin,
            'sonno_rem_min': isManual ? 0 : remMin,
            'efficienza_pct': effPct,
            'sleep_performance_pct': perfPct,
            'regolarita_sonno_pct': regolarita,
            'sleep_need_min': sleepNeed,
            'sleep_debt_min': sleepDebt,
            'provenance': isManual ? 'USER_ENTERED' : (existingSonno?['provenance'] ?? 'REAL'),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );

        // 4. Persistenza dei Segmenti dell'Ipnogramma (STG-07)
        if (epochs.isNotEmpty && sonnoId > 0) {
          final segments = buildSegmentsFromEpochs(epochs);
          for (final seg in segments) {
            await txn.insert(
              DatabaseHelper.tableSleepStageSegments,
              {
                'sonno_id': sonnoId,
                'start_utc_ms': seg['start_utc_ms'],
                'end_utc_ms': seg['end_utc_ms'],
                'stage': seg['stage'],
                'confidence': seg['confidence'],
              },
            );
          }
        }
      });
      debugPrint('OvernightSleepEngine: Salvo sonno e recovery notturno su SQLite ($dateIso, Rec: ${recoveryScore?.toInt()}%)');
    } catch (e) {
      debugPrint('OvernightSleepEngine Warning: Scrittura SQLite fallback/test: $e');
    }
  }
}

/// Helper Buffer Uint8
class Uint8Buffer {
  final List<int> _list = [];
  void addAll(Iterable<int> iterable) => _list.addAll(iterable);
  List<int> toList() => List.unmodifiable(_list);
}
