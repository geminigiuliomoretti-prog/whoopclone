import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import '../../domain/analytics/whoop_analytics_engine.dart';
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
  final List<double?> _legacyEnmoHistory = [];

  static const int minWorkoutDurationSec = 600; // 10 min standard WHOOP 2026

  AutoWorkoutDetector({
    this.restHr = 60.0,
    this.maxHr = 190.0,
    this.minDurationMinutes = 10,
    this.hrThresholdMultiplier = 1.3,
    this.alphaTrigger = 0.35,
    this.betaEnd = 0.12,
    this.enmoMotionThresh = 0.120,
    int? tSustainSec,
    int? tCooldownSec,
    this.bufferCapacity = 45 * 60,
    DatabaseHelper? dbHelper,
  })  : _dbHelper = dbHelper ?? DatabaseHelper(),
        tSustainSec = tSustainSec ?? minWorkoutDurationSec,
        tCooldownSec = tCooldownSec ?? 5 * 60 {
    hrr = maxHr - restHr;
    hrTrigger = math.max(restHr + 28.0, restHr + (alphaTrigger * hrr));
    hrEndThresh = restHr + (betaEnd * hrr);
  }

  /// Calcolo della metrica ENMO (Euclidean Norm Minus One)
  static double calculateEnmo(double accX, double accY, double accZ) {
    final vm = math.sqrt(accX * accX + accY * accY + accZ * accZ);
    return math.max(0.0, vm - 1.0);
  }

  /// Calcola le 5 percentuali reali delle Zone FC (0.0 - 100.0) in base a %HRR (Karvonen WHOOP)
  static ({double z1, double z2, double z3, double z4, double z5}) calculateHrZonePercentages({
    required List<int> bpmSamples,
    required double hrRest,
    required double hrMax,
  }) {
    if (bpmSamples.isEmpty) {
      return (z1: 0.0, z2: 0.0, z3: 0.0, z4: 0.0, z5: 0.0);
    }
    final double hrrSpan = math.max(20.0, hrMax - hrRest);
    int z1Count = 0, z2Count = 0, z3Count = 0, z4Count = 0, z5Count = 0;

    for (final bpm in bpmSamples) {
      final double hrrPct = (bpm - hrRest) / hrrSpan;
      if (hrrPct >= 0.90) {
        z5Count++;
      } else if (hrrPct >= 0.80) {
        z4Count++;
      } else if (hrrPct >= 0.70) {
        z3Count++;
      } else if (hrrPct >= 0.60) {
        z2Count++;
      } else if (hrrPct >= 0.50) {
        z1Count++;
      }
    }

    final int activeZonesCount = z1Count + z2Count + z3Count + z4Count + z5Count;
    final double denom = (activeZonesCount > 0 ? activeZonesCount : bpmSamples.length).toDouble();

    return (
      z1: double.parse(((z1Count / denom) * 100.0).toStringAsFixed(1)),
      z2: double.parse(((z2Count / denom) * 100.0).toStringAsFixed(1)),
      z3: double.parse(((z3Count / denom) * 100.0).toStringAsFixed(1)),
      z4: double.parse(((z4Count / denom) * 100.0).toStringAsFixed(1)),
      z5: double.parse(((z5Count / denom) * 100.0).toStringAsFixed(1)),
    );
  }

  /// Formula calorica di Keytel et al.: durataMin * ((0.6309 * avgHr + 0.1988 * 75.0 + 0.2017 * 25.0 - 55.0969) / 4.184)
  static int calculateKeytelCalories({
    required int durationMin,
    required double avgHr,
  }) {
    if (durationMin <= 0) return 0;
    final kcalPerMin = (0.6309 * avgHr + 0.1988 * 75.0 + 0.2017 * 25.0 - 55.0969) / 4.184;
    return math.max(durationMin * 2, (durationMin * kcalPerMin).round());
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
  void processBpmSample(
    int bpm,
    DateTime timestamp, {
    double? enmo,
    bool isSleeping = false,
  }) {
    if (isSleeping) {
      _legacyStartTime = null;
      _legacyBpmHistory.clear();
      _legacyEnmoHistory.clear();
      return;
    }

    // Inseriamo nel Ring Buffer 1Hz
    ingestSensorFrame(timestamp, bpm, enmo: enmo);

    // Soglia di attivazione: bpm >= max(restHr + 28, restHr + 0.35 * (maxHr - restHr))
    final double hrrTrigger = math.max(restHr + 28.0, restHr + 0.35 * (maxHr - restHr));
    final double threshold = math.min(restHr * hrThresholdMultiplier, hrrTrigger);

    if (bpm >= threshold) {
      _legacyStartTime ??= timestamp;
      _legacyBpmHistory.add(bpm);
      _legacyEnmoHistory.add(enmo);
      final durationSec = timestamp.difference(_legacyStartTime!).inSeconds;
      if (durationSec >= minDurationMinutes * 60 && _legacyBpmHistory.length % 60 == 0) {
        debugPrint('AutoWorkoutDetector: Rilevato potenziale allenamento in corso (${durationSec ~/ 60} min)');
      }
    } else {
      if (_legacyStartTime != null && _legacyBpmHistory.isNotEmpty) {
        final durationMin = timestamp.difference(_legacyStartTime!).inMinutes;
        if (durationMin >= minDurationMinutes) {
          // Filtro movimento ENMO: se enmo è stato fornito, almeno il 40% dei campioni deve avere enmo >= 0.025g
          final nonNullEnmo = _legacyEnmoHistory.whereType<double>().toList();
          final bool motionValid = nonNullEnmo.isEmpty ||
              (nonNullEnmo.where((e) => e >= 0.025).length / nonNullEnmo.length) >= 0.40;

          if (motionValid) {
            final avgBpm = (_legacyBpmHistory.reduce((a, b) => a + b) / _legacyBpmHistory.length).round();
            final maxBpm = _legacyBpmHistory.reduce(math.max);
            final totalSec = timestamp.difference(_legacyStartTime!).inSeconds;
            final dtSec = _legacyBpmHistory.length > 1
                ? (totalSec / _legacyBpmHistory.length).clamp(0.5, 60.0)
                : 1.0;

            final strain = WhoopAnalyticsEngine.calculateStrain(
              heartRateStream: _legacyBpmHistory,
              hrMax: maxHr.round(),
              hrRest: restHr.round(),
              enmoStream: nonNullEnmo.length == _legacyBpmHistory.length ? nonNullEnmo : null,
              sampleIntervalSeconds: dtSec,
              age: 30,
            );
            final calories = calculateKeytelCalories(
              durationMin: durationMin,
              avgHr: avgBpm.toDouble(),
            );
            final zones = calculateHrZonePercentages(
              bpmSamples: _legacyBpmHistory,
              hrRest: restHr,
              hrMax: maxHr,
            );

            final autoWorkout = Allenamento(
              dataIso: _legacyStartTime!.toLocal().toIso8601String().substring(0, 10),
              nomeAttivita: 'Allenamento Generico',
              oraInizioAllenamento: _legacyStartTime!.toLocal(),
              oraFineAllenamento: timestamp.toLocal(),
              durataMin: durationMin,
              hrMedia: avgBpm,
              hrMax: maxBpm,
              strainAttivita: strain,
              calorie: calories,
              zoneZ1Pct: zones.z1,
              zoneZ2Pct: zones.z2,
              zoneZ3Pct: zones.z3,
              zoneZ4Pct: zones.z4,
              zoneZ5Pct: zones.z5,
            );

            _persistAndNotify(autoWorkout);
            debugPrint('AutoWorkoutDetector: Allenamento di $durationMin min registrato automaticamente!');
          }
        }
        _legacyStartTime = null;
        _legacyBpmHistory.clear();
        _legacyEnmoHistory.clear();
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

        // Se l'80% rispetta la soglia HRR e almeno il 40% la soglia di movimento dinamico ENMO (>= 0.025g)
        if (hrRatio >= 0.80 && motionRatio >= 0.40) {
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
      if (f.hr <= (restHr + 0.10 * hrr) || f.enmo < 0.025) {
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

    final bpmList = framesToUse.map((f) => f.hr).toList();
    final enmoList = framesToUse.map((f) => f.enmo).toList();
    final avgHr = (bpmList.reduce((a, b) => a + b) / bpmList.length).round();
    final maxHrVal = bpmList.reduce(math.max);
    final durationSec = endTimestamp.difference(startTimestamp).inSeconds;
    final durationMin = math.max(1, (durationSec / 60).round());
    final dtSec = framesToUse.length > 1
        ? (durationSec / framesToUse.length).clamp(0.5, 60.0)
        : 1.0;

    final strain = WhoopAnalyticsEngine.calculateStrain(
      heartRateStream: bpmList,
      hrMax: maxHr.round(),
      hrRest: restHr.round(),
      enmoStream: enmoList,
      sampleIntervalSeconds: dtSec,
      age: 30,
    );
    final calories = calculateKeytelCalories(
      durationMin: durationMin,
      avgHr: avgHr.toDouble(),
    );
    final zones = calculateHrZonePercentages(
      bpmSamples: bpmList,
      hrRest: restHr,
      hrMax: maxHr,
    );

    final autoWorkout = Allenamento(
      dataIso: startTimestamp.toLocal().toIso8601String().substring(0, 10),
      nomeAttivita: activityLabel,
      oraInizioAllenamento: startTimestamp.toLocal(),
      oraFineAllenamento: endTimestamp.toLocal(),
      durataMin: durationMin,
      hrMedia: avgHr,
      hrMax: maxHrVal,
      strainAttivita: strain,
      calorie: calories,
      zoneZ1Pct: zones.z1,
      zoneZ2Pct: zones.z2,
      zoneZ3Pct: zones.z3,
      zoneZ4Pct: zones.z4,
      zoneZ5Pct: zones.z5,
    );

    await _persistAndNotify(autoWorkout);
    // Svuotamento Ring Buffer a fine attività per impedire ricalcoli sulla stessa finestra oraria
    _ringBuffer.clear();
  }

  /// Scansiona i record diurni di telemetria_grezza (escludendo finestre di sonno),
  /// individua le sessioni di attività fisica sostenuta (>= 10 min con FC media >= hrRest + 28 e Strain >= 4.5),
  /// e applica la Regola di Fusione a 60 Minuti di WHOOP (60-Minute Merge Rule).
  static List<Allenamento> detectWorkoutsFromTelemetryRecords(
    List<Map<String, dynamic>> records, {
    required int hrRest,
    required int hrMax,
    required int age,
    List<(DateTime, DateTime)> sleepWindows = const [],
  }) {
    if (records.isEmpty) return [];

    // 1. Estrai e ordina i campioni validi diurni (fuori dalle finestre di sonno)
    final List<({DateTime ts, int bpm, double enmo})> validSamples = [];
    for (final r in records) {
      final int? bpm = (r['bpm'] ?? r['hr']) as int?;
      if (bpm == null || bpm <= 35 || bpm > 220) continue;

      DateTime? ts;
      final utcMs = r['timestamp_utc_ms'] as int?;
      if (utcMs != null && utcMs > 0) {
        ts = DateTime.fromMillisecondsSinceEpoch(utcMs, isUtc: true).toLocal();
      } else if (r['timestamp'] != null) {
        ts = DateTime.tryParse(r['timestamp'].toString())?.toLocal();
      }
      if (ts == null) continue;

      bool inSleep = false;
      for (final w in sleepWindows) {
        final sStart = w.$1.toLocal();
        final sEnd = w.$2.toLocal();
        if (!ts.isBefore(sStart) && !ts.isAfter(sEnd)) {
          inSleep = true;
          break;
        }
      }
      if (inSleep) continue;

      final double enmo = ((r['accel_enmo'] ?? r['motion_var'] ?? r['enmo']) as num?)?.toDouble() ?? 0.0;
      validSamples.add((ts: ts, bpm: bpm, enmo: enmo));
    }

    if (validSamples.length < 30) return [];
    validSamples.sort((a, b) => a.ts.compareTo(b.ts));

    final double effectiveHrMax = hrMax > 0
        ? hrMax.toDouble()
        : WhoopAnalyticsEngine.calculateGellishHrMax(age);
    final double minActiveHr = math.max(
      hrRest + 28.0,
      hrRest + 0.35 * (effectiveHrMax - hrRest),
    );
    final double sustainDropThresh = hrRest + 18.0;

    // 2. Individua segmenti candidati di attività fisica sostenuta
    // Consentiamo brevi recuperi interni (fino a 3 min sotto soglia) prima di chiudere un candidato
    final List<({int startIdx, int endIdx})> rawSegments = [];
    int? segStart;
    int? lastElevatedIdx;

    for (int i = 0; i < validSamples.length; i++) {
      final s = validSamples[i];
      // Se c'è un buco di telemetria > 10 minuti, chiudi eventuale segmento aperto
      if (segStart != null && lastElevatedIdx != null) {
        final gapSec = s.ts.difference(validSamples[i - 1].ts).inSeconds;
        if (gapSec > 600) {
          rawSegments.add((startIdx: segStart, endIdx: lastElevatedIdx));
          segStart = null;
          lastElevatedIdx = null;
        }
      }

      if (s.bpm >= minActiveHr - 4.0) {
        segStart ??= i;
        lastElevatedIdx = i;
      } else if (segStart != null && lastElevatedIdx != null) {
        final lowDurationSec = s.ts.difference(validSamples[lastElevatedIdx].ts).inSeconds;
        if (s.bpm < sustainDropThresh && lowDurationSec >= 180) {
          rawSegments.add((startIdx: segStart, endIdx: lastElevatedIdx));
          segStart = null;
          lastElevatedIdx = null;
        }
      }
    }
    if (segStart != null && lastElevatedIdx != null) {
      rawSegments.add((startIdx: segStart, endIdx: lastElevatedIdx));
    }

    // Filtra i segmenti che durano almeno 10 minuti (600s) e hanno FC media >= hrRest + 28
    final List<({int startIdx, int endIdx})> qualifiedSegments = [];
    for (final seg in rawSegments) {
      final startTs = validSamples[seg.startIdx].ts;
      final endTs = validSamples[seg.endIdx].ts;
      final durSec = endTs.difference(startTs).inSeconds;
      if (durSec < minWorkoutDurationSec) continue;

      final sub = validSamples.sublist(seg.startIdx, seg.endIdx + 1);
      final avgHr = sub.map((e) => e.bpm).reduce((a, b) => a + b) / sub.length;
      if (avgHr < hrRest + 28) continue;

      // Verifica movimento dinamico se sono presenti dati ENMO non nulli (>0)
      final hasEnmoData = sub.any((e) => e.enmo > 0.001);
      if (hasEnmoData) {
        final movingCount = sub.where((e) => e.enmo >= 0.025).length;
        if ((movingCount / sub.length) < 0.40) continue;
      }

      qualifiedSegments.add(seg);
    }

    if (qualifiedSegments.isEmpty) return [];

    // 3. Regola di Fusione a 60 Minuti di WHOOP (60-Minute Merge Rule):
    // Se due attività terminano e iniziano a meno di 60 minuti di distanza, fondile in un'unica attività continua
    final List<({int startIdx, int endIdx})> mergedSegments = [qualifiedSegments.first];
    for (int i = 1; i < qualifiedSegments.length; i++) {
      final prev = mergedSegments.last;
      final curr = qualifiedSegments[i];
      final prevEndTs = validSamples[prev.endIdx].ts;
      final currStartTs = validSamples[curr.startIdx].ts;

      if (currStartTs.difference(prevEndTs).inMinutes < 60) {
        mergedSegments[mergedSegments.length - 1] = (startIdx: prev.startIdx, endIdx: curr.endIdx);
      } else {
        mergedSegments.add(curr);
      }
    }

    // 4. Costruisci gli oggetti Allenamento completi e verifica Strain >= 4.5
    final List<Allenamento> detectedWorkouts = [];
    for (final seg in mergedSegments) {
      final sub = validSamples.sublist(seg.startIdx, seg.endIdx + 1);
      final startLocal = sub.first.ts.toLocal();
      final endLocal = sub.last.ts.toLocal();
      final durSec = endLocal.difference(startLocal).inSeconds;
      final durMin = math.max(10, (durSec / 60.0).round());

      final bpms = sub.map((e) => e.bpm).toList();
      final enmos = sub.map((e) => e.enmo).toList();
      final avgHrDouble = bpms.reduce((a, b) => a + b) / bpms.length;
      if (avgHrDouble < hrRest + 28) continue;

      final dtSec = sub.length > 1 ? (durSec / (sub.length - 1)).clamp(0.5, 60.0) : 1.0;
      final strain = WhoopAnalyticsEngine.calculateStrain(
        heartRateStream: bpms,
        hrMax: effectiveHrMax.round(),
        hrRest: hrRest,
        enmoStream: enmos,
        sampleIntervalSeconds: dtSec,
        age: age,
      );

      if (strain < 4.5) continue;

      final avgHr = avgHrDouble.round();
      final maxHrVal = bpms.reduce(math.max);
      final calories = calculateKeytelCalories(durationMin: durMin, avgHr: avgHrDouble);
      final zones = calculateHrZonePercentages(
        bpmSamples: bpms,
        hrRest: hrRest.toDouble(),
        hrMax: effectiveHrMax,
      );

      final avgEnmo = enmos.reduce((a, b) => a + b) / enmos.length;
      String activityName = 'Allenamento Rilevato';
      if (avgEnmo > 0.250) {
        activityName = 'Corsa';
      } else if (avgEnmo >= 0.040 && avgEnmo <= 0.120) {
        activityName = 'Sollevamento Pesi';
      }

      detectedWorkouts.add(
        Allenamento(
          dataIso: startLocal.toIso8601String().substring(0, 10),
          nomeAttivita: activityName,
          oraInizio: startLocal.toIso8601String(),
          oraFine: endLocal.toIso8601String(),
          oraInizioAllenamento: startLocal,
          oraFineAllenamento: endLocal,
          durataMin: durMin,
          hrMedia: avgHr,
          hrMax: maxHrVal,
          strainAttivita: strain,
          calorie: calories,
          zoneZ1Pct: zones.z1,
          zoneZ2Pct: zones.z2,
          zoneZ3Pct: zones.z3,
          zoneZ4Pct: zones.z4,
          zoneZ5Pct: zones.z5,
        ),
      );
    }

    return detectedWorkouts;
  }

  Future<void> _persistAndNotify(Allenamento workout) async {
    try {
      final db = await _dbHelper.database;
      await db.execute('PRAGMA journal_mode=WAL;');

      // Overlap Check e Regola di Fusione a 60 Minuti per prevenire sessioni duplicate o frammentate
      final mergeBeforeStr = workout.oraInizioAllenamento.subtract(const Duration(minutes: 60)).toIso8601String();
      final mergeAfterStr = workout.oraFineAllenamento.add(const Duration(minutes: 60)).toIso8601String();

      final existingMaps = await db.query(
        DatabaseHelper.tableAllenamenti,
        where: 'ora_inizio <= ? AND ora_fine >= ?',
        whereArgs: [mergeAfterStr, mergeBeforeStr],
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

        final combinedRaw = WhoopAnalyticsEngine.convertStrainToRawLoad(existingWorkout.strainAttivita ?? 0.0) +
            WhoopAnalyticsEngine.convertStrainToRawLoad(workout.strainAttivita ?? 0.0);
        final mergedStrain = math.max(
          math.max(workout.strainAttivita ?? 0.0, existingWorkout.strainAttivita ?? 0.0),
          WhoopAnalyticsEngine.convertRawLoadToStrain(combinedRaw),
        );

        final mergedWorkout = existingWorkout.copyWith(
          oraInizioAllenamento: newStart,
          oraFineAllenamento: newEnd,
          durataMin: newDur,
          hrMax: math.max(workout.hrMax ?? 0, existingWorkout.hrMax ?? 0),
          hrMedia: (((workout.hrMedia ?? 0) + (existingWorkout.hrMedia ?? 0)) / 2).round(),
          strainAttivita: mergedStrain,
          calorie: math.max(workout.calorie ?? 0, existingWorkout.calorie ?? 0),
        );

        await db.update(
          DatabaseHelper.tableAllenamenti,
          mergedWorkout.toMap(),
          where: 'id = ?',
          whereArgs: [existingWorkout.id],
        );
        _autoWorkoutController.add(mergedWorkout);
        debugPrint('AutoWorkoutDetector: Unificata sessione (60-min merge rule) su SQLite ID=${existingWorkout.id}');
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
