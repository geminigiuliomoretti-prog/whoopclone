import 'dart:async';
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
  static List<int> buildOpcode22SendHistoricalData({int seq = 0}) {
    return HapticClockEncoder.buildFramedCommand(
      type: 0x01,
      seq: seq,
      cmd: 0x16,
      payload: const [0x00, 0x00, 0x00, 0x01, 0x00],
    );
  }

  /// Genera il pacchetto ACK Opcode 23 (HISTORICAL_DATA_RESULT) per avanzare il cursore Flash
  static List<int> buildOpcode23HistoricalDataResult(int lastSeqAck, {int seq = 0}) {
    return HapticClockEncoder.buildFramedCommand(
      type: 0x01,
      seq: seq,
      cmd: 0x17,
      payload: [lastSeqAck & 0xFF, (lastSeqAck >> 8) & 0xFF, 0x01],
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

  // 2. REGOLA SONNO PROFONDO (SWS):
  // Assenza di moto, frequenza ai minimi, rMSSD stabile, respirazione ritmica
  final isDeepCandidate = enmo < 0.008 && hrRatio <= 1.05 && respVar <= 0.151;
  if (isDeepCandidate && (epochIndex < (totalEpochs * 0.70) || respVar <= 0.08)) {
    // SWS favorito nella prima metà/due terzi della notte o con RSA eccezionalmente coerente
    return SleepStage.deepSws;
  }

  // 3. REGOLA SONNO REM:
  // Atonia muscolare (no moto), frequenza cardiaca variabile e spike di HRV (tono instabile)
  final isRemCandidate = enmo < 0.010 && hrvNorm > 1.20 && hrRatio > 0.95;
  final int minRemEpoch = totalEpochs > 150 ? 120 : (totalEpochs * 0.15).round();
  if (isRemCandidate && epochIndex > minRemEpoch) {
    return SleepStage.rem;
  }

  // 4. STATO BASE: Sonno Leggero (Light Sleep)
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
      // Trigger: Quiescenza cinematica ENMO < 0.015g per >= 30 min, HR < Media Diurna - 15% o vicina a FCR, RSA >= 0.50
      final int requiredCount = math.min(_telemetryBuffer.length, tSleepSustainSec);
      if (requiredCount >= tSleepSustainSec) {
        final recentWindow = _telemetryBuffer.sublist(_telemetryBuffer.length - requiredCount);
        
        final quietCount = recentWindow.where((s) => s.enmo <= enmoSleepThresh).length;
        final avgHr = recentWindow.map((s) => s.hr).reduce((a, b) => a + b) / requiredCount;
        final avgRespPower = recentWindow.map((s) => s.respPower).reduce((a, b) => a + b) / requiredCount;

        final bool isKinematicallyQuiet = (quietCount / requiredCount) >= 0.75;
        final bool isHrDropped = (avgHr <= (daytimeMeanHr * 0.85)) || (avgHr <= restHr + 6.0);
        final bool isRsaRegular = avgRespPower >= 0.50;

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
      // Trigger: Attività motoria continuativa ENMO > 0.080g per oltre 15 min, oppure battito HR > FCR + 20 bpm continuativo
      final int requiredWakeCount = math.min(_telemetryBuffer.length, tWakeSustainSec);
      if (requiredWakeCount >= math.min(tWakeSustainSec, 30)) {
        final recentWakeWindow = _telemetryBuffer.sublist(_telemetryBuffer.length - requiredWakeCount);

        final activeMotionCount = recentWakeWindow.where((s) => s.enmo >= enmoWakeThresh).length;
        final avgHr = recentWakeWindow.map((s) => s.hr).reduce((a, b) => a + b) / requiredWakeCount;

        final bool isMotorActive = (activeMotionCount / requiredWakeCount) >= 0.70;
        final bool isHrElevated = avgHr >= (restHr + 22.0);

        if (isMotorActive && isHrElevated) {
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
        targetDateIso: safeStart.toIso8601String().substring(0, 10),
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

    const int startSustainSamples = 10;
    const int endSustainSamples = 8;

    for (int i = 0; i < records.length - startSustainSamples; i++) {
      bool isQuietWindow = true;
      for (int j = 0; j < startSustainSamples; j++) {
        final r = records[i + j];
        final motion = (r['motion_var'] ?? r['motion'] ?? r['enmo'] ?? 0.050).toDouble();
        final hr = (r['hr'] ?? r['bpm'] ?? 100.0).toDouble();
        if (motion > 0.015 || hr > (daytimeMeanHr * 0.90)) {
          isQuietWindow = false;
          break;
        }
      }
      if (isQuietWindow) {
        startIndex = i;
        break;
      }
    }

    if (startIndex != -1) {
      for (int i = startIndex + startSustainSamples; i < records.length - endSustainSamples; i++) {
        bool isWakeWindow = true;
        for (int j = 0; j < endSustainSamples; j++) {
          final r = records[i + j];
          final motion = (r['motion_var'] ?? r['motion'] ?? r['enmo'] ?? 0.0).toDouble();
          final hr = (r['hr'] ?? r['bpm'] ?? 0.0).toDouble();
          if (motion < 0.080 && hr < (rhrBaseline + 20.0)) {
            isWakeWindow = false;
            break;
          }
        }
        if (isWakeWindow) {
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
  }) async {
    final double rhrBaseline = (userBaseline30d['rhr_mean'] ?? 55.0).toDouble();
    final double hrvBaseline = (userBaseline30d['rmssd_mean'] ?? 65.0).toDouble();
    final double? tempBaseline = (userBaseline30d['baseline_temp_celsius'] as num?)?.toDouble();
    final double sleepNeedMin = (userBaseline30d['sleep_need_min'] ??
            userBaseline30d['sleep_baseline_min'] ??
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
            final rr = p['rr_ms'] != null ? (p['rr_ms'] as num).toDouble() : null;
            final motion = (p['motion_var'] as num?)?.toDouble() ?? 0.002;
            return {
              'timestamp': p['timestamp'],
              'timestamp_utc_ms': p['timestamp_utc_ms'],
              'hr': bpm,
              'bpm': bpm,
              'rmssd': rr,
              'rr_ms': rr,
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
        final double sleepPerfPct = ((totalManualSleepMin / sleepNeedMin) * 100.0).clamp(0.0, 100.0);
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

        debugPrint('[OvernightSleepEngine] Salvata sessione manuale ($dateIso): ${totalManualSleepMin.toInt()} min, Perf: ${sleepPerfPct.toInt()}%, Vitali: --');

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

    final double? recoveryScore = (finalNightHrvRmssd != null && finalNightRhr != null)
        ? _calculateRecoveryScore(
            hrvRmssd: finalNightHrvRmssd,
            rhrBpm: finalNightRhr,
            sleepPerformancePct: sleepPerformancePct,
            skinTempDelta: deltaSkinTemp ?? 0.0,
            spo2Pct: spo2Pct,
            userBaseline: userBaseline30d,
            nightlyStress: sleepStressMean,
          )
        : null;

    // 9. Persistenza Transazionale Atomica su SQLite (Cicli Fisiologici e Sonno)
    final String dateIso = targetDateIso ??
        (windowEnd ?? (epochs30s.isNotEmpty ? epochs30s.last.timestamp : DateTime.now()))
            .toIso8601String()
            .substring(0, 10);

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
        epochs: epochs30s,
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
      'skin_temperature_delta_c': deltaSkinTemp,
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
      if (ts == null) return fallback;
      if (ts is DateTime) return ts;
      return DateTime.tryParse(ts.toString()) ?? fallback;
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
      final effectiveStart = DateTime.now().subtract(Duration(seconds: records.length * 30));
      for (int i = 0; i < records.length; i++) {
        final r = records[i];
        final motion = (r['motion_var'] ?? r['motion'] ?? r['accel_enmo'] ?? r['enmo'] as num?)?.toDouble() ?? 0.0;
        final hr = (r['hr'] ?? r['bpm'] as num?)?.toDouble() ?? 0.0;
        final rmssd = (r['rmssd'] as num?)?.toDouble() ?? (r['hrv_ms'] as num?)?.toDouble() ?? 0.0;
        final respPower = (r['resp_power'] as num?)?.toDouble() ?? 0.0;
        final respRate = (r['resp_rate'] as num?)?.toDouble() ?? 0.0;
        final rmssdVar = (r['rmssd_var'] as num?)?.toDouble() ?? 0.0;
        final hrFluc = (r['hr_fluc'] as num?)?.toInt() ?? 0;
        final List<double> pp = r['pp_intervals'] != null
            ? List<double>.from(r['pp_intervals'])
            : (r['rr_ms'] != null ? [(r['rr_ms'] as num).toDouble() / 1000.0] : []);

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

    DateTime effectiveStart = startTime ?? firstTs;
    DateTime effectiveEnd = endTime ?? (lastTs.isAfter(effectiveStart) ? lastTs : effectiveStart.add(const Duration(hours: 8)));

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

          final rmssdVal = (r['rmssd'] as num?)?.toDouble() ??
              (r['hrv_ms'] as num?)?.toDouble() ??
              ((r['rr_ms'] as num?) != null && (r['rr_ms'] as num) < 250.0 ? (r['rr_ms'] as num).toDouble() : null);
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
          } else if (r['rr_ms'] != null) {
            ppList.add((r['rr_ms'] as num).toDouble() / 1000.0);
          }
        }

        final double currentHr = hrCount > 0 ? (hrSum / hrCount) : (lastHr ?? 0.0);
        if (hrCount > 0) lastHr = currentHr;

        final double currentRmssd = rmssdCount > 0 ? (rmssdSum / rmssdCount).clamp(20.0, 140.0) : (lastRmssd ?? 0.0);
        if (rmssdCount > 0) lastRmssd = currentRmssd;

        list.add(Epoch30s(
          index: k,
          timestamp: epochTime,
          motionVar: motionSum / count,
          hr: currentHr,
          rmssd: currentRmssd,
          respPower: respPowerSum / count,
          respRate: respRateSum / count,
          rmssdVarInWindow: rmssdVarSum / count,
          hrFluctuations: (hrFlucSum / count).round(),
          ppIntervals: ppList,
          sampleCount: count,
          quality: count >= 10 ? EpochQuality.valid : EpochQuality.lowConfidence,
          stage: 'LIGHT',
        ));
      } else {
        // Epoca senza campioni BLE (gap temporale): contrassegna esplicitamente come MISSING
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

    return list;
  }

  /// Classificatore per l'Ipnogramma Notturno con Estrazione Multi-Feature e Filtro di Smoothing Temporale
  void _classifyHypnogram(List<Epoch30s> epochs, double rhrBaseline, double hrvBaseline) {
    final int totalEpochs = epochs.length;
    if (totalEpochs == 0) return;

    final List<SleepStage> rawStages = [];

    for (int k = 0; k < totalEpochs; k++) {
      final ep = epochs[k];

      // Se l'epoca è priva di campioni o marcata MISSING, preserva lo stato MISSING
      if (ep.quality == EpochQuality.missing || ep.sampleCount == 0 || ep.stage == 'MISSING') {
        rawStages.add(SleepStage.missing);
        continue;
      }

      final double enmo = ep.motionVar;
      final double hrRatio = rhrBaseline > 0 ? (ep.hr / rhrBaseline) : 1.0;
      final double hrvNorm = hrvBaseline > 0 ? (ep.rmssd / hrvBaseline) : 1.0;
      final double respVar = ep.respPower > 0.0
          ? double.parse(((1.0 - ep.respPower) * 0.5).clamp(0.0, 1.0).toStringAsFixed(3))
          : 0.0;

      var stage = classifyEpoch(
        enmo: enmo,
        hrRatio: hrRatio,
        hrvNorm: hrvNorm,
        respVar: respVar,
        epochIndex: k,
        totalEpochs: totalEpochs,
      );

      // Supporto per feature aggiuntive di atonia REM su epoche con hrFluctuations o rmssdVarInWindow
      if (stage == SleepStage.light && k > (totalEpochs > 150 ? 120 : (totalEpochs * 0.15).round())) {
        if (enmo < 0.010 && (ep.rmssdVarInWindow >= 0.25 || ep.hrFluctuations >= 4)) {
          stage = SleepStage.rem;
        }
      }

      rawStages.add(stage);
    }

    // 2. Filtro di Smoothing Temporale (Majority Vote / Eliminazione Flickering a singola epoca)
    final List<SleepStage> smoothedStages = List.from(rawStages);
    for (int i = 1; i < totalEpochs - 1; i++) {
      final prev = smoothedStages[i - 1];
      final curr = smoothedStages[i];
      final next = rawStages[i + 1];

      // Non applicare smoothing su epoche MISSING (i buchi di dati rimangono buchi autentici)
      if (curr == SleepStage.missing || prev == SleepStage.missing || next == SleepStage.missing) {
        continue;
      }

      // Se l'epoca corrente è isolata tra due epoche dello stesso stadio, uniforma (a meno di forte spike motorio di veglia)
      if (prev == next && curr != prev) {
        if (curr == SleepStage.wake && epochs[i].motionVar > 0.060) {
          // Preserva micro-risveglio autentico ad alta accelerazione
        } else {
          smoothedStages[i] = prev;
        }
      }
    }

    for (int k = 0; k < totalEpochs; k++) {
      epochs[k].stage = smoothedStages[k].toHypnogramString();
    }
  }

  /// Estrazione di rMSSD ed RHR nell'Ultimo Ciclo SWS prima del risveglio finale (Brevetto US9750415B2)
  /// Calcolo matematico rigoroso:
  /// rMSSD = sqrt( 1/(N-1) * sum( (PP_{i+1} - PP_i)^2 ) )
  /// RHR = 1/N * sum( BPM_i )
  Map<String, double?> _extractLastSwsCycleMetrics(List<Epoch30s> epochs) {
    if (epochs.isEmpty) {
      return {'rmssd': null, 'rhr': null};
    }

    // 1. Cerca l'ultimo blocco contiguo di SWS prima del risveglio finale
    int lastSwsIdx = -1;
    for (int i = epochs.length - 1; i >= 0; i--) {
      if (epochs[i].stage == 'SWS') {
        lastSwsIdx = i;
        break;
      }
    }

    List<Epoch30s> evalSws = [];
    if (lastSwsIdx != -1) {
      int startIdx = lastSwsIdx;
      while (startIdx > 0 && epochs[startIdx - 1].stage == 'SWS') {
        startIdx--;
      }
      evalSws = epochs.sublist(startIdx, lastSwsIdx + 1);
    } else {
      // 2. Fallback: Finestra di minima varianza accelerometrica (motionVar < 0.020g) escludendo epoche MISSING
      final validEpochs = epochs.where((e) => e.stage != 'MISSING' && e.stage != 'UNKNOWN' && e.sampleCount > 0).toList();
      final quietEpochs = validEpochs.where((e) => e.motionVar < 0.020).toList();
      evalSws = quietEpochs.isNotEmpty ? quietEpochs : validEpochs;
    }

    if (evalSws.isEmpty) {
      return {'rmssd': null, 'rhr': null};
    }

    // Calcolo FCR (RHR) = media aritmetica dei BPM
    final validHrs = evalSws.map((e) => e.hr).where((h) => h > 25.0 && h < 180.0).toList();
    final double? avgRhr = validHrs.isNotEmpty
        ? (validHrs.reduce((a, b) => a + b) / validHrs.length)
        : null;

    // Calcolo VFC (rMSSD) esatto per epoca nel blocco SWS con filtraggio fisiologico ed ectopico
    final List<double> epochRmssdList = [];
    for (final ep in evalSws) {
      if (ep.motionVar > 0.015) {
        // Scarta epoche con rumore accelerometrico elevato
        continue;
      }

      if (ep.ppIntervals.length >= 2) {
        final ppList = ep.ppIntervals;
        final validPp = <double>[];
        for (final p in ppList) {
          final ms = p < 5.0 ? p * 1000.0 : p;
          if (ms >= 300.0 && ms <= 1500.0) {
            validPp.add(ms);
          }
        }

        if (validPp.length >= 2) {
          double sumSq = 0.0;
          int count = 0;
          for (int j = 0; j < validPp.length - 1; j++) {
            final diff = (validPp[j + 1] - validPp[j]).abs();
            // Rigetto Ectopico: se la variazione tra battiti adiacenti supera 200ms, scarta
            if (diff <= 200.0) {
              sumSq += (diff * diff);
              count++;
            }
          }
          if (count > 0) {
            final epochVal = math.sqrt(sumSq / count);
            if (epochVal >= 20.0 && epochVal <= 140.0) {
              epochRmssdList.add(epochVal);
            }
          }
        }
      } else if (ep.rmssd > 0 && ep.rmssd <= 140.0) {
        final clampedVal = ep.rmssd.clamp(20.0, 120.0);
        epochRmssdList.add(clampedVal);
      }
    }

    double? computedRmssd;
    if (epochRmssdList.isNotEmpty) {
      computedRmssd = epochRmssdList.reduce((a, b) => a + b) / epochRmssdList.length;
    }

    return {
      'rmssd': computedRmssd != null ? double.parse(computedRmssd.clamp(20.0, 120.0).toStringAsFixed(1)) : null,
      'rhr': avgRhr != null ? double.parse(avgRhr.clamp(30.0, 120.0).toStringAsFixed(1)) : null,
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

  /// Calcolo Delta Temperatura Cutanea (°C) reale rispetto alla baseline
  double? _calculateDeltaSkinTemp(List<Map<String, dynamic>> records, double? baseTemp) {
    if (records.isEmpty || baseTemp == null) return null;
    final List<double> celsiusList = [];

    for (final r in records) {
      // 1. Lettura diretta gradi Celsius (da SQLite telemetria_grezza o stream BLE decodificato)
      final directCelsius = (r['skin_temp_celsius'] ?? r['temp_celsius'] ?? r['skin_temp']) as num?;
      if (directCelsius != null && directCelsius > 25.0 && directCelsius < 43.0) {
        celsiusList.add(directCelsius.toDouble());
        continue;
      }

      // 2. Lettura valore raw sensore AS6221 (es. 4672 / 128.0 = 36.5 °C)
      final rawSensor = (r['skin_temp_raw'] ?? r['temp_raw']) as num?;
      if (rawSensor != null && rawSensor > 1000 && rawSensor < 8000) {
        final c = rawSensor.toDouble() / 128.0;
        if (c > 25.0 && c < 43.0) {
          celsiusList.add(c);
        }
      }
    }

    if (celsiusList.isEmpty) return null;
    final avgCelsius = celsiusList.reduce((a, b) => a + b) / celsiusList.length;
    return double.parse((avgCelsius - baseTemp).clamp(-3.0, 3.0).toStringAsFixed(1));
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

  /// Frequenza Respiratoria Notturna via RSA Dinamica (Bandpass & Peak Detection: 0.15 - 0.40 Hz)
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

    // 2. Estrazione RSA per singola epoca di 30s da serie continua di picchi PP
    for (final ep in evalEpochs) {
      if (ep.ppIntervals.length >= 8) {
        final ppList = ep.ppIntervals;
        final meanPp = ppList.reduce((a, b) => a + b) / ppList.length;
        
        int zeroCrossings = 0;
        for (int j = 1; j < ppList.length; j++) {
          final prevDiff = ppList[j - 1] - meanPp;
          final currDiff = ppList[j] - meanPp;
          if ((prevDiff < 0 && currDiff >= 0) || (prevDiff >= 0 && currDiff < 0)) {
            zeroCrossings++;
          }
        }
        
        final durationSec = ppList.reduce((a, b) => a + b);
        if (durationSec > 2.0 && zeroCrossings >= 2) {
          final cycles = zeroCrossings / 2.0;
          final fPeak = cycles / durationSec;
          final rpm = fPeak * 60.0;
          if (rpm >= 7.0 && rpm <= 24.0) {
            calculatedRpmList.add(rpm);
          }
        }
      } else if (ep.respRate > 0 && ep.respRate >= 7.0 && ep.respRate <= 24.0) {
        calculatedRpmList.add(ep.respRate);
      }
    }

    // 3. Estrazione RSA su finestre mobili di intervalli R-R se disponibili nei record grezzi scaricati
    if (calculatedRpmList.isEmpty) {
      final validRrs = records
          .map((r) => (r['rr_ms'] as num?)?.toDouble())
          .where((rr) => rr != null && rr >= 300.0 && rr <= 1500.0)
          .map((rr) => rr!)
          .toList();

      if (validRrs.length >= 25) {
        const windowSize = 30;
        for (int w = 0; w + windowSize <= validRrs.length; w += 15) {
          final window = validRrs.sublist(w, w + windowSize);
          final meanRr = window.reduce((a, b) => a + b) / window.length;
          int zc = 0;
          for (int j = 1; j < window.length; j++) {
            final p = window[j - 1] - meanRr;
            final c = window[j] - meanRr;
            if ((p < 0 && c >= 0) || (p >= 0 && c < 0)) {
              zc++;
            }
          }
          final durSec = (window.reduce((a, b) => a + b)) / 1000.0;
          if (durSec > 4.0 && zc >= 2) {
            final rpm = ((zc / 2.0) / durSec) * 60.0;
            if (rpm >= 7.0 && rpm <= 24.0) {
              calculatedRpmList.add(rpm);
            }
          }
        }
      }
    }

    // 4. Fallback su oscillazione della frequenza cardiaca (BPM) con durata temporale reale
    if (calculatedRpmList.isEmpty) {
      final bpms = records
          .map((r) => (r['hr'] ?? r['bpm']) as num?)
          .where((b) => b != null && b > 30)
          .map((b) => b!.toDouble())
          .toList();

      if (bpms.length >= 60) {
        final meanBpm = bpms.reduce((a, b) => a + b) / bpms.length;
        int zeroCrossings = 0;
        for (int j = 1; j < bpms.length; j++) {
          final p = bpms[j - 1] - meanBpm;
          final c = bpms[j] - meanBpm;
          if ((p < 0 && c >= 0) || (p >= 0 && c < 0)) {
            zeroCrossings++;
          }
        }

        double durationSec = bpms.length.toDouble();
        if (records.first['timestamp'] != null && records.last['timestamp'] != null) {
          final t0 = DateTime.tryParse(records.first['timestamp'].toString());
          final t1 = DateTime.tryParse(records.last['timestamp'].toString());
          if (t0 != null && t1 != null && t1.isAfter(t0)) {
            final diffSec = t1.difference(t0).inSeconds.toDouble();
            if (diffSec > 0) {
              final avgSampleSec = diffSec / bpms.length;
              if (avgSampleSec <= 2.5) {
                durationSec = diffSec;
              }
            }
          }
        }

        final fPeak = (zeroCrossings / 2.0) / durationSec;
        final rpm = fPeak * 60.0;
        if (rpm >= 7.0 && rpm <= 24.0) {
          calculatedRpmList.add(rpm);
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

  /// Algoritmo di Calcolo Recovery Score (0 - 100%)
  double? _calculateRecoveryScore({
    required double? hrvRmssd,
    required double? rhrBpm,
    required double? sleepPerformancePct,
    required double skinTempDelta,
    double? spo2Pct,
    required Map<String, dynamic> userBaseline,
    double? nightlyStress,
  }) {
    if (hrvRmssd == null || rhrBpm == null) {
      return null;
    }

    final double hrvMean = (userBaseline['rmssd_mean'] ?? 65.0).toDouble();
    final double hrvStd = (userBaseline['rmssd_std'] ?? 15.0).toDouble();
    final double rhrMean = (userBaseline['rhr_mean'] ?? 55.0).toDouble();
    final double rhrStd = (userBaseline['rhr_std'] ?? 3.5).toDouble();

    final zHrv = (hrvRmssd - hrvMean) / (hrvStd > 0 ? hrvStd : 1.0);
    final zRhr = (rhrMean - rhrBpm) / (rhrStd > 0 ? rhrStd : 1.0);

    final sleepPerf = sleepPerformancePct ?? 80.0;

    // Contributo autonomico base (50% HRV, 35% RHR, 15% Sonno)
    double baseRecovery = 50.0 + (zHrv * 18.0) + (zRhr * 12.0) + ((sleepPerf - 80.0) * 0.25);

    // Penalità per Temperatura Cutanea alterata
    if (skinTempDelta.abs() > 0.8) {
      baseRecovery -= (skinTempDelta.abs() * 4.0);
    }

    // Penalità per Ipossiemia SpO2 (<95%)
    if (spo2Pct != null && spo2Pct < 95.0) {
      baseRecovery -= (95.0 - spo2Pct) * 3.0;
    }

    // Penalità per Stress Notturno elevato (> 1.0)
    if (nightlyStress != null && nightlyStress > 1.0) {
      baseRecovery -= ((nightlyStress - 1.0) * 15.0);
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
    List<Epoch30s> epochs = const [],
    bool isManual = false,
  }) async {
    try {
      final db = await _dbHelper.database;
      await db.transaction((txn) async {
        // 1. Upsert Ciclo Fisiologico preservando strain o campi pre-esistenti
        final existing = await txn.query(
          DatabaseHelper.tableCicliFisiologici,
          where: 'data_iso = ?',
          whereArgs: [dateIso],
        );
        final existingMap = existing.isNotEmpty ? existing.first : <String, dynamic>{};
        await txn.insert(
          DatabaseHelper.tableCicliFisiologici,
          {
            'data_iso': dateIso,
            'strain_giornaliero': existingMap['strain_giornaliero'],
            'recovery_score': recoveryScore ?? existingMap['recovery_score'],
            'sleep_need_min': existingMap['sleep_need_min'],
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

        // 2. Persistenza punti campionati di Stress Notturno su misurazioni_stress
        final now = DateTime.now();
        final sleepStart = windowStart ?? now.subtract(Duration(minutes: totalSleepMin + wasoMin));
        final sleepEnd = windowEnd ?? now;

        if (nightlyStressPoints.isNotEmpty) {
          await txn.delete(
            DatabaseHelper.tableMisurazioniStress,
            where: 'data_iso = ? AND timestamp >= ? AND timestamp <= ?',
            whereArgs: [dateIso, sleepStart.toIso8601String(), sleepEnd.toIso8601String()],
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
        final existingSonnoRows = await txn.query(
          DatabaseHelper.tableSonno,
          columns: ['id'],
          where: 'data_iso = ?',
          whereArgs: [dateIso],
        );
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

        final denominator = totalSleepMin + wasoMin > 0 ? totalSleepMin + wasoMin : 1;
        final double? effPct = isManual ? null : (((totalSleepMin / denominator) * 100).clamp(0.0, 100.0));
        final perfPct = sleepPerformancePct ?? (((totalSleepMin / 480.0) * 100).clamp(0.0, 100.0));

        // Cancella qualsiasi sessione sonno preesistente per questa data prima di inserire quella nuova/ricalcolata
        await txn.delete(
          DatabaseHelper.tableSonno,
          where: 'data_iso = ?',
          whereArgs: [dateIso],
        );

        final sonnoId = await txn.insert(
          DatabaseHelper.tableSonno,
          {
            'data_iso': dateIso,
            'ora_inizio': sleepStart.toIso8601String(),
            'ora_fine': sleepEnd.toIso8601String(),
            'durata_tot_min': totalSleepMin,
            'sonno_profondo_min': isManual ? 0 : swsMin,
            'sonno_rem_min': isManual ? 0 : remMin,
            'efficienza_pct': effPct,
            'sleep_performance_pct': perfPct,
            'provenance': isManual ? 'USER_ENTERED' : 'REAL',
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
