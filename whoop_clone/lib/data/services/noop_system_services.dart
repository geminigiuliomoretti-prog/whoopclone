import 'dart:async';
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
  Future<void> Function({String reason})? onAlarmTrigger;

  HapticAlarmScheduler({required this.bleManager, this.onAlarmTrigger});

  /// Programma una sveglia a vibrazione sul cinturino WHOOP
  Future<bool> scheduleHapticAlarm({
    required DateTime alarmTime,
    int vibrationPattern = 1,
  }) async {
    _scheduledAlarmTime = alarmTime;
    _lastPattern = vibrationPattern;

    if (bleManager.isConnected) {
      final payload = HapticClockEncoder.encodeAlarmTime(
        alarmTime: alarmTime,
        vibrationPattern: vibrationPattern,
      );
      await bleManager.writeAlarmCommand(payload);
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
          if (onAlarmTrigger != null) {
            _alarmCheckTimer?.cancel();
            await onAlarmTrigger!(reason: 'Orario Sveglia');
            return;
          }
          _isVibrating = true;
          debugPrint('HapticAlarmScheduler: SVEGLIA SCATTATA! Invio sequenza vibrazione haptic sul cinturino WHOOP...');
          final startTime = DateTime.now();
          try {
            while (_scheduledAlarmTime != null && _isVibrating) {
              if (DateTime.now().difference(startTime).inSeconds >= 60) {
                debugPrint('HapticAlarmScheduler: Timeout di 1 minuto raggiunto.');
                break;
              }
              await bleManager.sendStrapAlarmVibration(pattern: _lastPattern);
              await Future.delayed(const Duration(seconds: 3));
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

  // Coda rapida in memoria e flush periodico su SQLite (Fase 4: DAT-04)
  final List<Map<String, dynamic>> _flushQueue = [];
  Timer? _flushTimer;
  static const int maxQueueSize = 50;
  static const Duration flushInterval = Duration(seconds: 10);

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

    // Flush periodico ogni 10 secondi per prevenire perdita dati in background
    _flushTimer?.cancel();
    _flushTimer = Timer.periodic(flushInterval, (_) {
      flushTelemetry();
    });

    // Sottoscrizione al flusso pacchetti 96 byte usando il decoder canonico Whoop96BytePacket
    _packet96Sub?.cancel();
    _packet96Sub = bleManager.packet96ByteStream.listen((packet) async {
      if (packet.isValid && packet.rawBytes.length >= 24) {
        _lastMotionVar = packet.motionVariance;
        _lastRespPower = packet.respiratoryPower > 0 ? packet.respiratoryPower : null;
        _lastRespRate = packet.respiratoryRate > 0 ? packet.respiratoryRate : null;
        
        final rawTemp = packet.skinTempRaw;
        if (rawTemp > 1000 && rawTemp < 6000) {
          _lastSkinTempC = double.parse((rawTemp * 0.0078125).toStringAsFixed(2));
        } else {
          _lastSkinTempC = null;
        }

        final rRatio = packet.spo2Ratio;
        if (rRatio > 0 && rRatio <= 1.2) {
          _lastSpo2Pct = double.parse((110.0 - (25.0 * rRatio)).clamp(70.0, 100.0).toStringAsFixed(1));
        } else {
          _lastSpo2Pct = null;
        }

        // Aggiorna metriche con timestamp autentico del pacchetto
        final hrVal = packet.heartRateBpm > 0 ? packet.heartRateBpm : (_nocturnalBpmSamples.isNotEmpty ? _nocturnalBpmSamples.last : 0);
        if (hrVal > 0) {
          _lastPacket96Time = packet.timestamp;
          final rmssdVal = packet.hrvRmssdMs >= 5.0 && packet.hrvRmssdMs <= 300.0 ? packet.hrvRmssdMs : null;
          if (rmssdVal != null) {
            _nocturnalHrvSamples.add(rmssdVal);
            if (_nocturnalHrvSamples.length > 3600) {
              _nocturnalHrvSamples.removeAt(0);
            }
          }

          _recordNocturnalSample(
            timestamp: packet.timestamp,
            bpm: hrVal,
            hrv: rmssdVal,
            motion: _lastMotionVar,
            respPower: _lastRespPower,
            respRate: _lastRespRate,
            skinTempC: _lastSkinTempC,
            spo2Pct: _lastSpo2Pct,
          );
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
      }
    });

    _syncTimer = Timer.periodic(const Duration(minutes: 5), (timer) async {
      if (bleManager.isConnected && _nocturnalBpmSamples.isNotEmpty) {
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

          final todayIso = DateTime.now().toLocal().toIso8601String().substring(0, 10);
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

  final List<_NocturnalSample> _nocturnalSamples = [];

  void _recordNocturnalSample({
    required DateTime timestamp,
    required int bpm,
    double? hrv,
    required double motion,
    double? respPower,
    double? respRate,
    double? skinTempC,
    double? spo2Pct,
  }) {
    _nocturnalSamples.add(_NocturnalSample(
      timestamp: timestamp,
      bpm: bpm,
      hrv: hrv,
      motion: motion,
      respPower: respPower,
      respRate: respRate,
      skinTempC: skinTempC,
      spo2Pct: spo2Pct,
    ));
    if (_nocturnalSamples.length > 3600) {
      _nocturnalSamples.removeAt(0);
    }
  }

  /// Genera la lista di campioni di telemetria notturna per l'OvernightSleepEngine
  /// NOTA: I campioni contengono i timestamp reali registrati all'arrivo dei pacchetti.
  List<Map<String, dynamic>> getNocturnalTelemetryRecords() {
    final List<Map<String, dynamic>> records = [];
    for (final s in _nocturnalSamples) {
      records.add({
        'hr': s.bpm.toDouble(),
        'bpm': s.bpm.toDouble(),
        'rmssd': s.hrv,
        'rmssd_ms': s.hrv,
        'rr_ms': null,
        'motion_var': s.motion,
        'accel_enmo': s.motion,
        'resp_power': s.respPower,
        'resp_rate': s.respRate,
        'skin_temp_celsius': s.skinTempC,
        'spo2_pct': s.spo2Pct,
        'timestamp': s.timestamp.toIso8601String(),
        'timestamp_utc_ms': s.timestamp.toUtc().millisecondsSinceEpoch,
      });
    }
    return records;
  }

  /// Svuota immediatamente la coda in memoria su SQLite in batch (Fase 4: DAT-04)
  Future<int> flushTelemetry() async {
    if (_flushQueue.isEmpty) return 0;
    final List<Map<String, dynamic>> batch = List.from(_flushQueue);
    _flushQueue.clear();
    try {
      await DatabaseHelper().insertTelemetriaBatch(batch);
      return batch.length;
    } catch (e) {
      debugPrint('[BackgroundSyncDaemon] Errore inserimento batch telemetria: $e');
      return 0;
    }
  }

  Future<void> stopDaemon() async {
    _isRunning = false;
    _syncTimer?.cancel();
    _flushTimer?.cancel();
    _hrSub?.cancel();
    _packet96Sub?.cancel();
    await flushTelemetry();
  }
}

/// Campione con timestamp autentico per il buffer notturno
class _NocturnalSample {
  final DateTime timestamp;
  final int bpm;
  final double? hrv;
  final double motion;
  final double? respPower;
  final double? respRate;
  final double? skinTempC;
  final double? spo2Pct;

  const _NocturnalSample({
    required this.timestamp,
    required this.bpm,
    this.hrv,
    required this.motion,
    this.respPower,
    this.respRate,
    this.skinTempC,
    this.spo2Pct,
  });
}

