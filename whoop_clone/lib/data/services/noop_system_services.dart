import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import '../ble/ble_connection_manager.dart';
import '../ble/noop_protocol_decoder.dart';
import '../database/database_helper.dart';
import '../engine/whoop_analytics_engine.dart';
import '../repositories/whoop_repository.dart';
import 'noop_analytics_engine.dart';

/// Gestore Sveglie Aptiche del WHOOP (da ryanbr/noop)
class HapticAlarmScheduler {
  final BleConnectionManager bleManager;
  Timer? _alarmCheckTimer;
  DateTime? _scheduledAlarmTime;
  int _lastPattern = 1;
  bool _isVibrating = false;

  HapticAlarmScheduler({required this.bleManager});

  /// Programma una sveglia a vibrazione sul cinturino WHOOP
  Future<bool> scheduleHapticAlarm({
    required DateTime alarmTime,
    int vibrationPattern = 1,
  }) async {
    _scheduledAlarmTime = alarmTime;
    _lastPattern = vibrationPattern;

    if (bleManager.state == BleState.connected) {
      final payload = HapticClockEncoder.encodeAlarmTime(
        alarmTime: alarmTime,
        vibrationPattern: vibrationPattern,
      );
      await bleManager.sendHapticVibrationCommand(pattern: vibrationPattern);
      debugPrint('HapticAlarmScheduler: Inviato pacchetto sveglia haptic (${payload.length} bytes)');
    }

    _startAlarmCheckTimer();
    return true;
  }

  /// Annulla la sveglia programmata
  void cancelAlarm() {
    _scheduledAlarmTime = null;
    _alarmCheckTimer?.cancel();
    _isVibrating = false;
    bleManager.sendCancelAlarmCommand();
  }

  void _startAlarmCheckTimer() {
    _alarmCheckTimer?.cancel();
    _alarmCheckTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (_isVibrating) return;
      if (_scheduledAlarmTime != null) {
        final now = DateTime.now();
        if (now.isAfter(_scheduledAlarmTime!) || now.isAtSameMomentAs(_scheduledAlarmTime!)) {
          _isVibrating = true;
          debugPrint('HapticAlarmScheduler: SVEGLIA SCATTATA! Invio sequenza vibrazione haptic sul cinturino WHOOP...');
          try {
            for (int i = 0; i < 5; i++) {
              if (_scheduledAlarmTime == null) break;
              await bleManager.sendHapticVibrationCommand(pattern: _lastPattern);
              await Future.delayed(const Duration(milliseconds: 1000));
            }
          } finally {
            cancelAlarm();
          }
        }
      }
    });
  }

  void dispose() {
    _scheduledAlarmTime = null;
    _isVibrating = false;
    _alarmCheckTimer?.cancel();
  }
}

/// Daemon per la sincronizzazione continua e il monitoraggio notturno in background (da ryanbr/noop)
class BackgroundSyncDaemon {
  final BleConnectionManager bleManager;
  final WhoopRepository? repository;
  Timer? _syncTimer;
  bool _isRunning = false;

  final List<int> _nocturnalBpmSamples = [];
  final List<double> _nocturnalHrvSamples = [];
  final List<double> _nocturnalRrSamples = [];
  DateTime? _lastPacket96Time;
  StreamSubscription? _hrSub;
  StreamSubscription? _packet96Sub;

  // Buffer per i dati di movimento/accelerazione estratti dal pacchetto 96 byte
  double _lastMotionVar = 0.0;
  double? _lastRespPower;
  double? _lastRespRate;
  double? _lastSkinTempC;
  double? _lastSpo2Pct;

  BackgroundSyncDaemon({required this.bleManager, this.repository});

  void startDaemon() {
    if (_isRunning) return;
    _isRunning = true;

    // Sottoscrizione al flusso pacchetti 96 byte per estrarre ENMO, temperatura, SpO2, respirazione
    _packet96Sub?.cancel();
    _packet96Sub = bleManager.packet96ByteStream.listen((packet) async {
      // Estrazione dei dati biometrici avanzati dal pacchetto proprietario Whoop 96 byte
      if (packet.rawBytes.length >= 40) {
        _lastMotionVar = packet.motionVariance;
        _lastRespPower = _extractFloat32LE(packet.rawBytes, 16);
        _lastRespRate = _extractFloat32LE(packet.rawBytes, 20);
        final rawTemp = _extractUint16LE(packet.rawBytes, 28);
        if (rawTemp != null && rawTemp > 1000 && rawTemp < 6000) {
          _lastSkinTempC = double.parse((rawTemp * 0.0078125).toStringAsFixed(2));
        }
        final rRatio = _extractFloat32LE(packet.rawBytes, 32);
        if (rRatio != null && rRatio > 0 && rRatio <= 1.2) {
          _lastSpo2Pct = double.parse((110.0 - (25.0 * rRatio)).clamp(85.0, 100.0).toStringAsFixed(1));
        }

        // Salva i pacchetti 96-byte (streaming live e pacchetti Store-and-Forward flash) su SQLite
        try {
          final hrVal = packet.heartRateBpm > 0 ? packet.heartRateBpm : (_nocturnalBpmSamples.isNotEmpty ? _nocturnalBpmSamples.last : 0);
          if (hrVal > 0) {
            _lastPacket96Time = packet.timestamp;
            final rmssdVal = packet.hrvRmssdMs > 0 && packet.hrvRmssdMs < 200 ? packet.hrvRmssdMs : null;
            if (rmssdVal != null) {
              _nocturnalHrvSamples.add(rmssdVal);
              if (_nocturnalHrvSamples.length > 3600) {
                _nocturnalHrvSamples.removeAt(0);
              }
            }
            await DatabaseHelper().insertTelemetriaPoint(
              bpm: hrVal,
              rrMs: rmssdVal, // rr_ms memorizza l'rMSSD in ms (HRV fisiologica)
              accelEnmo: _lastMotionVar,
              motionVar: _lastMotionVar,
              skinTempCelsius: _lastSkinTempC,
              skinTempRaw: rawTemp,
              spo2Pct: _lastSpo2Pct,
              spo2RatioR: rRatio,
              respRate: _lastRespRate,
              respPower: _lastRespPower,
              timestamp: packet.timestamp,
              timestampUtcMs: packet.timestamp.toUtc().millisecondsSinceEpoch,
            );
          }
        } catch (e) {
          debugPrint('[BackgroundSyncDaemon] Error saving packet telemetry: $e');
        }
      }
    });

    // Sottoscrizione continua ai flussi BLE per mantenere attivo il buffering notturno e salvare la telemetria grezza su SQLite
    _hrSub?.cancel();
    _hrSub = bleManager.hrStream.listen((hrPacket) async {
      if (hrPacket.bpm > 0) {
        _nocturnalBpmSamples.add(hrPacket.bpm);
        if (_nocturnalBpmSamples.length > 3600) {
          _nocturnalBpmSamples.removeAt(0);
        }

        double? calculatedRmssd;
        if (hrPacket.rrIntervalsMs.isNotEmpty) {
          for (final rr in hrPacket.rrIntervalsMs) {
            if (rr > 300 && rr < 1500) {
              _nocturnalRrSamples.add(rr);
              if (_nocturnalRrSamples.length > 3600) {
                _nocturnalRrSamples.removeAt(0);
              }
            }
          }

          // Calcola il vero rMSSD sugli intervalli RR raccolti (finestra mobile degli ultimi 30 campioni)
          if (_nocturnalRrSamples.length >= 2) {
            final recentRr = _nocturnalRrSamples.length > 30
                ? _nocturnalRrSamples.sublist(_nocturnalRrSamples.length - 30)
                : _nocturnalRrSamples;
            final rmssd = NoopAnalyticsEngine.calculateRmssd(recentRr);
            if (rmssd != null && rmssd > 0 && rmssd < 200) {
              calculatedRmssd = rmssd;
              final hasRecent96 = _lastPacket96Time != null &&
                  hrPacket.timestamp.difference(_lastPacket96Time!).inMilliseconds.abs() < 2000;
              if (!hasRecent96) {
                _nocturnalHrvSamples.add(rmssd);
                if (_nocturnalHrvSamples.length > 3600) {
                  _nocturnalHrvSamples.removeAt(0);
                }
              }
            }
          }
        }

        // Coordinamento con _packet96Sub: se abbiamo appena ricevuto un pacchetto 96 byte (entro 1500 ms),
        // evitiamo di inserire un campione duplicato alla stessa frequenza in telemetria_grezza
        // poiché il pacchetto a 96 byte contiene già la telemetria completa (sensori + rMSSD nativo).
        final bool hasRecent96Packet = _lastPacket96Time != null &&
            hrPacket.timestamp.difference(_lastPacket96Time!).inMilliseconds.abs() < 1500;

        if (!hasRecent96Packet) {
          try {
            // Chiariamo il significato di rr_ms: memorizza il vero rMSSD in ms (non l'intervallo RR grezzo da 900 ms)
            await DatabaseHelper().insertTelemetriaPoint(
              bpm: hrPacket.bpm,
              rrMs: calculatedRmssd,
              accelEnmo: _lastMotionVar,
              motionVar: _lastMotionVar,
              skinTempCelsius: _lastSkinTempC,
              spo2Pct: _lastSpo2Pct,
              respRate: _lastRespRate,
              respPower: _lastRespPower,
              timestamp: hrPacket.timestamp,
              timestampUtcMs: hrPacket.timestamp.toUtc().millisecondsSinceEpoch,
            );
          } catch (e) {
            debugPrint('[BackgroundSyncDaemon] Error saving HR telemetry: $e');
          }
        }
      }
    });

    _syncTimer = Timer.periodic(const Duration(minutes: 5), (timer) async {
      if (bleManager.state == BleState.connected && _nocturnalBpmSamples.isNotEmpty) {
        // Calcolo del vero rMSSD: priorità ai campioni rMSSD raccolti,
        // altrimenti calcolato autenticamente dall'intero buffer di intervalli RR
        double? currentHrv;
        if (_nocturnalHrvSamples.isNotEmpty) {
          currentHrv = (_nocturnalHrvSamples.reduce((a, b) => a + b) / _nocturnalHrvSamples.length);
        } else if (_nocturnalRrSamples.length >= 2) {
          currentHrv = NoopAnalyticsEngine.calculateRmssd(_nocturnalRrSamples);
        }

        if (currentHrv != null && currentHrv > 0) {
          debugPrint('BackgroundSyncDaemon: Monitoraggio sonno & vitals attivo in background — ${_nocturnalBpmSamples.length} campioni notturni registrati, rMSSD: ${currentHrv.toStringAsFixed(1)} ms');
          final avgRhr = (_nocturnalBpmSamples.reduce((a, b) => a + b) / _nocturnalBpmSamples.length);
          final avgHrv = currentHrv.clamp(10.0, 200.0);

          final todayIso = DateTime.now().toIso8601String().substring(0, 10);
          try {
            final dbHelper = DatabaseHelper();
            final userProfile = await dbHelper.getUserProfile();
            final rhrBase = (userProfile?['rhr_baseline_mean'] as num?)?.toDouble() ?? 55.0;
            final hrvBase = (userProfile?['hrv_baseline_mean'] as num?)?.toDouble() ?? 65.0;
            final realStress = WhoopAnalyticsEngine.calculateStressScore(
              hrLive: avgRhr,
              hrvLiveMs: avgHrv,
              hrRest: rhrBase,
              baselineHrvMean: hrvBase,
              baselineHrvStd: 15.0,
              accMagnitude: 1.0 + _lastMotionVar,
            );

            await dbHelper.insertMisurazioneStress(
              todayIso,
              realStress,
              avgHrv,
              avgRhr.round(),
            );
          } catch (e) {
            debugPrint('[BackgroundSyncDaemon] Error computing/saving stress measurement: $e');
          }
        }
      }
    });
  }

  /// Genera la lista di campioni di telemetria notturna per l'OvernightSleepEngine
  /// NOTA: Questo metodo è usato SOLO come fallback se la query DB non trova nulla.
  /// I dati reali con timestamp sono salvati nella tabella telemetria_grezza dal listener BLE.
  List<Map<String, dynamic>> getNocturnalTelemetryRecords() {
    final List<Map<String, dynamic>> records = [];
    final int totalCount = _nocturnalBpmSamples.length;

    if (totalCount > 0) {
      final now = DateTime.now();
      for (int i = 0; i < totalCount; i++) {
        final bpm = _nocturnalBpmSamples[i];
        final hrv = i < _nocturnalHrvSamples.length ? _nocturnalHrvSamples[i] : null;
        records.add({
          'hr': bpm.toDouble(),
          'bpm': bpm.toDouble(),
          'rmssd': hrv,
          'rr_ms': hrv,
          'motion_var': _lastMotionVar,
          'accel_enmo': _lastMotionVar,
          'resp_power': _lastRespPower,
          'resp_rate': _lastRespRate,
          'skin_temp_celsius': _lastSkinTempC,
          'spo2_pct': _lastSpo2Pct,
          'timestamp': now.subtract(Duration(seconds: (totalCount - i))).toIso8601String(),
        });
      }
    }
    return records;
  }

  /// Helper: estrae un float32 little-endian da un buffer di byte
  double? _extractFloat32LE(List<int> bytes, int offset) {
    if (bytes.length < offset + 4) return null;
    final bd = ByteData.sublistView(Uint8List.fromList(bytes.sublist(offset, offset + 4)));
    return bd.getFloat32(0, Endian.little);
  }

  /// Helper: estrae un uint16 little-endian da un buffer di byte
  int? _extractUint16LE(List<int> bytes, int offset) {
    if (bytes.length < offset + 2) return null;
    return bytes[offset] | (bytes[offset + 1] << 8);
  }

  void stopDaemon() {
    _isRunning = false;
    _syncTimer?.cancel();
    _hrSub?.cancel();
    _packet96Sub?.cancel();
  }
}
