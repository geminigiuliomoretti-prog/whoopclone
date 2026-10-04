import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import '../database/database_helper.dart';
import '../models/allenamento.dart';

/// Frame dati dei sensori (1Hz: HR, ENMO, Varianza Giroscopio)
class SensorFrame {
  final DateTime timestamp;
  final int hr;
  final double enmo;
  final double gyroVar;

  SensorFrame({
    required this.timestamp,
    required this.hr,
    required this.enmo,
    required this.gyroVar,
  });

  Map<String, dynamic> toMap() => {
        'timestamp': timestamp.millisecondsSinceEpoch ~/ 1000,
        'hr': hr,
        'enmo': enmo,
        'gyro_var': gyroVar,
      };
}

/// Stati FSM dell'Auto Workout Detection Engine
enum AutoWorkoutState {
  idleMonitoring,
  candidateBuffering,
  workoutActive,
  cooldownPending,
  terminatedPersisted,
}

/// Rilevatore Automatico di Allenamenti basato su FSM, HRR, ENMO e Backdating
/// (AutoWorkoutDetector da StrandAnalytics & Brevetti WHOOP)
class AutoWorkoutDetector {
  final double restHr;
  final double maxHr;
  final int minDurationMinutes;
  final double hrThresholdMultiplier;
  final DatabaseHelper _dbHelper;

  // Soglie Fisiologiche e Cinematiche (Modello HRR)
  late final double hrr;
  final double alphaTrigger; // 0.25 (25% HRR)
  final double betaEnd; // 0.12 (12% HRR)
  late final double hrTrigger;
  late final double hrEndThresh;
  final double enmoMotionThresh; // 0.050g (50 mg)

  // Durate Finestre Temporali (in secondi)
  int tSustainSec; // 15 min = 900s (valutazione sostenuta)
  int tCooldownSec; // 5 min = 300s (cooldown di riposo)
  final int bufferCapacity; // Capacity FIFO Ring Buffer (45 min @ 1Hz = 2700)

  // Buffer Circolare in RAM (FIFO)
  final List<SensorFrame> _ringBuffer = [];
  List<SensorFrame> get ringBuffer => List.unmodifiable(_ringBuffer);

  // Stato FSM
  AutoWorkoutState state = AutoWorkoutState.idleMonitoring;
  DateTime? activeWorkoutStart;

  // Stream per notificare l'avvenuta rilevazione e persistenza
  final StreamController<Allenamento> _autoWorkoutController = StreamController<Allenamento>.broadcast();
  Stream<Allenamento> get autoWorkoutDetectedStream => _autoWorkoutController.stream;

  // Variabili per supporto retro-compatibilità legacy bpm stream
  DateTime? _legacyStartTime;
  final List<int> _legacyBpmHistory = [];

  AutoWorkoutDetector({
    this.restHr = 60.0,
    this.maxHr = 190.0,
    this.minDurationMinutes = 15,
    this.hrThresholdMultiplier = 1.3,
    this.alphaTrigger = 0.35,
    this.betaEnd = 0.12,
    this.enmoMotionThresh = 0.120,
    int? tSustainSec,
    int? tCooldownSec,
    this.bufferCapacity = 45 * 60,
    DatabaseHelper? dbHelper,
  })  : _dbHelper = dbHelper ?? DatabaseHelper(),
        tSustainSec = tSustainSec ?? 15 * 60,
        tCooldownSec = tCooldownSec ?? 5 * 60 {
    hrr = maxHr - restHr;
    hrTrigger = restHr + (alphaTrigger * hrr);
    hrEndThresh = restHr + (betaEnd * hrr);
  }

  /// Calcolo della metrica ENMO (Euclidean Norm Minus One)
  static double calculateEnmo(double accX, double accY, double accZ) {
    final vm = math.sqrt(accX * accX + accY * accY + accZ * accZ);
    return math.max(0.0, vm - 1.0);
  }

  /// Ingestione di un frame di sensore ad 1Hz
  void ingestSensorFrame(
    DateTime timestamp,
    int hrVal, {
    double? enmo,
    List<double>? accTuple,
    double gyroVar = 0.0,
  }) {
    final double enmoVal = enmo ??
        (accTuple != null
            ? calculateEnmo(accTuple[0], accTuple[1], accTuple[2])
            : (hrVal >= hrTrigger ? 0.080 : 0.010));

    final frame = SensorFrame(
      timestamp: timestamp,
      hr: hrVal,
      enmo: enmoVal,
      gyroVar: gyroVar,
    );

    _ringBuffer.add(frame);
    if (_ringBuffer.length > bufferCapacity) {
      _ringBuffer.removeAt(0);
    }

    _evaluateFsm(timestamp);
  }

  /// Processa un campione di BPM istantaneo dal sensore BLE (Supporto Legacy & Stream Adaptor)
  void processBpmSample(int bpm, DateTime timestamp) {
    // Inseriamo nel Ring Buffer 1Hz
    ingestSensorFrame(timestamp, bpm);

    // Gestione legacy per test trasversali
    final threshold = restHr * hrThresholdMultiplier;
    if (bpm >= threshold) {
      _legacyStartTime ??= timestamp;
      _legacyBpmHistory.add(bpm);
      final durationSec = timestamp.difference(_legacyStartTime!).inSeconds;
      if (durationSec >= minDurationMinutes * 60 && _legacyBpmHistory.length % 60 == 0) {
        debugPrint('AutoWorkoutDetector: Rilevato potenziale allenamento in corso (${durationSec ~/ 60} min)');
      }
    } else {
      if (_legacyStartTime != null && _legacyBpmHistory.isNotEmpty) {
        final durationMin = timestamp.difference(_legacyStartTime!).inMinutes;
        if (durationMin >= minDurationMinutes) {
          final avgBpm = (_legacyBpmHistory.reduce((a, b) => a + b) / _legacyBpmHistory.length).round();
          final maxBpm = _legacyBpmHistory.reduce((a, b) => a > b ? a : b);

          final autoWorkout = Allenamento(
            dataIso: _legacyStartTime!.toIso8601String().substring(0, 10),
            nomeAttivita: 'Allenamento Generico',
            oraInizioAllenamento: _legacyStartTime!,
            oraFineAllenamento: timestamp,
            durataMin: durationMin,
            hrMedia: avgBpm,
            hrMax: maxBpm,
            strainAttivita: (durationMin * 0.12).clamp(4.0, 20.5),
            calorie: durationMin * 8,
          );

          _persistAndNotify(autoWorkout);
          debugPrint('AutoWorkoutDetector: Allenamento di $durationMin min registrato automaticamente!');
        }
        _legacyStartTime = null;
        _legacyBpmHistory.clear();
      }
    }
  }

  /// Valutazione della Macchina a Stati (FSM)
  void _evaluateFsm(DateTime currentTime) {
    if (state == AutoWorkoutState.idleMonitoring) {
      final windowSize = math.min(_ringBuffer.length, tSustainSec);
      if (windowSize >= tSustainSec) {
        final recentWindow = _ringBuffer.sublist(_ringBuffer.length - windowSize);
        final elevatedHrCount = recentWindow.where((f) => f.hr >= hrTrigger).length;
        final activeMotionCount = recentWindow.where((f) => f.enmo >= enmoMotionThresh).length;

        final hrRatio = elevatedHrCount / windowSize;
        final motionRatio = activeMotionCount / windowSize;

        // Se l'80% rispetta la soglia HRR (35%) e il 50% la soglia di movimento ENMO (>0.120g) per 15 min continui
        if (hrRatio >= 0.80 && motionRatio >= 0.50) {
          activeWorkoutStart = _backdateStartTime();
          state = AutoWorkoutState.workoutActive;
          debugPrint('AutoWorkoutDetector [FSM]: Innesco Allenamento! Start retrodatato a $activeWorkoutStart');
        }
      }
    } else if (state == AutoWorkoutState.workoutActive) {
      final cooldownSize = math.min(_ringBuffer.length, tCooldownSec);
      if (cooldownSize >= math.min(tCooldownSec, 30)) {
        final recentCooldown = _ringBuffer.sublist(_ringBuffer.length - cooldownSize);
        final avgHr = recentCooldown.map((f) => f.hr).reduce((a, b) => a + b) / cooldownSize;
        final avgEnmo = recentCooldown.map((f) => f.enmo).reduce((a, b) => a + b) / cooldownSize;

        // Condizione di Cooldown & Autoterminazione
        if (avgHr < hrEndThresh && avgEnmo < enmoMotionThresh) {
          final tEnd = _backdateEndTime();
          state = AutoWorkoutState.terminatedPersisted;
          _terminateAndPersistWorkout(activeWorkoutStart ?? _ringBuffer.first.timestamp, tEnd);
          state = AutoWorkoutState.idleMonitoring;
          activeWorkoutStart = null;
        }
      }
    }
  }

  /// Retrodatazione di Inizio (Start-Backdating)
  /// Scorre il Ring Buffer a ritroso per individuare l'istante di primo innalzamento HR o movimento ENMO
  DateTime _backdateStartTime() {
    for (int i = _ringBuffer.length - 1; i > 0; i--) {
      final f = _ringBuffer[i];
      if (f.hr <= (restHr + 0.10 * hrr) || f.enmo < enmoMotionThresh) {
        return f.timestamp;
      }
    }
    return _ringBuffer.first.timestamp;
  }

  /// Retrodatazione di Fine (End-Backdating)
  /// Esclude i minuti finali di riposo del cooldown
  DateTime _backdateEndTime() {
    final cooldownFrames = math.min(_ringBuffer.length, tCooldownSec);
    final targetIndex = _ringBuffer.length - cooldownFrames;
    if (targetIndex >= 0 && targetIndex < _ringBuffer.length) {
      return _ringBuffer[targetIndex].timestamp;
    }
    return _ringBuffer.last.timestamp;
  }

  /// Classificatore Euristico/Cinematico Multi-Stadio
  String _classifyActivityType(List<SensorFrame> frames) {
    if (frames.isEmpty) return 'Allenamento Generico';

    final avgEnmo = frames.map((f) => f.enmo).reduce((a, b) => a + b) / frames.length;
    final avgGyro = frames.map((f) => f.gyroVar).reduce((a, b) => a + b) / frames.length;
    final avgHr = frames.map((f) => f.hr).reduce((a, b) => a + b) / frames.length;

    if (avgEnmo > 0.250) {
      return 'Corsa';
    } else if (avgEnmo < 0.040 && avgHr > hrTrigger) {
      return 'Ciclismo';
    } else if (avgGyro > 0.180) {
      return 'Padel / Tennis';
    } else if (avgEnmo >= 0.040 && avgEnmo <= 0.120) {
      return 'Sollevamento Pesi';
    } else {
      return 'Allenamento Generico';
    }
  }

  /// Terminazione e Persistenza su SQLite (`PRAGMA journal_mode=WAL; BEGIN TRANSACTION`)
  Future<void> _terminateAndPersistWorkout(DateTime startTimestamp, DateTime endTimestamp) async {
    final workoutFrames = _ringBuffer
        .where((f) => !f.timestamp.isBefore(startTimestamp) && !f.timestamp.isAfter(endTimestamp))
        .toList();

    final framesToUse = workoutFrames.isNotEmpty ? workoutFrames : _ringBuffer;
    final String activityLabel = _classifyActivityType(framesToUse);

    final avgHr = (framesToUse.map((f) => f.hr).reduce((a, b) => a + b) / framesToUse.length).round();
    final maxHr = framesToUse.map((f) => f.hr).reduce(math.max);
    final durationSec = endTimestamp.difference(startTimestamp).inSeconds;
    final durationMin = math.max(1, (durationSec / 60).round());
    final strain = (durationMin * 0.12).clamp(4.0, 20.5);
    final calories = durationMin * 8;

    final autoWorkout = Allenamento(
      dataIso: startTimestamp.toIso8601String().substring(0, 10),
      nomeAttivita: activityLabel,
      oraInizioAllenamento: startTimestamp,
      oraFineAllenamento: endTimestamp,
      durataMin: durationMin,
      hrMedia: avgHr,
      hrMax: maxHr,
      strainAttivita: strain,
      calorie: calories,
    );

    await _persistAndNotify(autoWorkout);
    // Svuotamento Ring Buffer a fine attività per impedire ricalcoli sulla stessa finestra oraria
    _ringBuffer.clear();
  }

  Future<void> _persistAndNotify(Allenamento workout) async {
    try {
      final db = await _dbHelper.database;
      await db.execute('PRAGMA journal_mode=WAL;');

      // Overlap Check per prevenire la creazione di sessioni duplicate per la stessa finestra temporale
      final startStr = workout.oraInizioAllenamento.toIso8601String();
      final endStr = workout.oraFineAllenamento.toIso8601String();

      final existingMaps = await db.query(
        DatabaseHelper.tableAllenamenti,
        where: 'ora_inizio <= ? AND ora_fine >= ?',
        whereArgs: [endStr, startStr],
      );

      if (existingMaps.isNotEmpty) {
        final existingMap = existingMaps.first;
        final existingWorkout = Allenamento.fromMap(existingMap);

        final newStart = workout.oraInizioAllenamento.isBefore(existingWorkout.oraInizioAllenamento)
            ? workout.oraInizioAllenamento
            : existingWorkout.oraInizioAllenamento;
        final newEnd = workout.oraFineAllenamento.isAfter(existingWorkout.oraFineAllenamento)
            ? workout.oraFineAllenamento
            : existingWorkout.oraFineAllenamento;
        final newDur = math.max(1, newEnd.difference(newStart).inMinutes);

        final mergedWorkout = existingWorkout.copyWith(
          oraInizioAllenamento: newStart,
          oraFineAllenamento: newEnd,
          durataMin: newDur,
          hrMax: math.max(workout.hrMax ?? 0, existingWorkout.hrMax ?? 0),
          hrMedia: (((workout.hrMedia ?? 0) + (existingWorkout.hrMedia ?? 0)) / 2).round(),
          strainAttivita: math.max(workout.strainAttivita ?? 0.0, existingWorkout.strainAttivita ?? 0.0),
          calorie: math.max(workout.calorie ?? 0, existingWorkout.calorie ?? 0),
        );

        await db.update(
          DatabaseHelper.tableAllenamenti,
          mergedWorkout.toMap(),
          where: 'id = ?',
          whereArgs: [existingWorkout.id],
        );
        _autoWorkoutController.add(mergedWorkout);
        debugPrint('AutoWorkoutDetector: Unificata sessione sovrapposta su SQLite ID=${existingWorkout.id}');
        return;
      }

      await db.transaction((txn) async {
        await txn.insert(
          DatabaseHelper.tableAllenamenti,
          workout.toMap(),
        );
      });
      _autoWorkoutController.add(workout);
      debugPrint('AutoWorkoutDetector: Salvato allenamento su SQLite (${workout.nomeAttivita}, ${workout.durataMin} min)');
    } catch (e) {
      _autoWorkoutController.add(workout);
      debugPrint('AutoWorkoutDetector Warning: Scrittura SQLite fallback/test: $e');
    }
  }

  void dispose() {
    _autoWorkoutController.close();
  }
}

/// Stimatore di Autonomia Batteria WHOOP (BatteryEstimator da StrandAnalytics di noop)
class BatteryEstimator {
  final List<Map<String, dynamic>> _batteryHistory = [];

  void recordBatteryLevel(int levelPct, DateTime timestamp) {
    _batteryHistory.add({
      'pct': levelPct,
      'time': timestamp,
    });
    if (_batteryHistory.length > 50) {
      _batteryHistory.removeAt(0);
    }
  }

  /// Calcola il tasso di scarica (% all'ora)
  double getDischargeRatePerHour() {
    if (_batteryHistory.length < 2) return 0.8;

    final first = _batteryHistory.first;
    final last = _batteryHistory.last;

    final durationHours = (last['time'] as DateTime).difference(first['time'] as DateTime).inSeconds / 3600.0;
    if (durationHours < 0.1) return 0.8;

    final dropPct = (first['pct'] as int) - (last['pct'] as int);
    if (dropPct <= 0) return 0.8;

    return (dropPct / durationHours).clamp(0.2, 5.0);
  }

  double calculateDischargeRatePctPerHour() => getDischargeRatePerHour();

  /// Stima le ore di funzionamento rimanenti
  double estimateRemainingHours(int currentBatteryPct) {
    final rate = getDischargeRatePerHour();
    if (rate <= 0) return 120.0;
    return (currentBatteryPct / rate).clamp(0.0, 168.0);
  }

  double estimateHoursRemaining(int currentBatteryPct) => estimateRemainingHours(currentBatteryPct);

  /// Stima i giorni di funzionamento rimanenti
  double estimateRemainingDays(int currentBatteryPct) {
    return estimateRemainingHours(currentBatteryPct) / 24.0;
  }
}
