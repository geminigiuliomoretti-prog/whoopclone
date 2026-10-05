import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import '../database/database_helper.dart';
import 'overnight_sleep_engine.dart';
import '../../core/utils/clock.dart';

/// Rappresenta una finestra di sonno identificata a posteriori dalla telemetria (Fase 5: SLP-01..08)
class DetectedSleepWindow {
  final DateTime startTime;
  final DateTime endTime;
  final bool isNap;
  final String wakeDateIso; // Data locale del risveglio (SLP-02)
  final double coveragePct;
  final String provenance; // 'REAL' se coverage >= 70%, 'PARTIAL' altrimenti (SLP-04)
  final List<Map<String, dynamic>> records;

  const DetectedSleepWindow({
    required this.startTime,
    required this.endTime,
    required this.isNap,
    required this.wakeDateIso,
    required this.coveragePct,
    required this.provenance,
    required this.records,
  });

  Duration get duration => endTime.difference(startTime);
  int get durationMinutes => duration.inMinutes;

  @override
  String toString() =>
      'DetectedSleepWindow(start: $startTime, end: $endTime, dur: ${durationMinutes}m, isNap: $isNap, wakeDate: $wakeDateIso, cov: ${coveragePct.toStringAsFixed(1)}%, prov: $provenance)';
}

/// Rilevatore di Sonno a Posteriori (Fase 5: SLP-01..08)
/// Analizza a posteriori la telemetria memorizzata su SQLite per rilevare sonno notturno e pisolini
/// in modo deterministico, idempotente e indipendente dal ciclo di vita della UI.
class PosteriorSleepDetector {
  final DatabaseHelper _dbHelper;
  final OvernightSleepEngine _sleepEngine;

  PosteriorSleepDetector({
    DatabaseHelper? dbHelper,
    OvernightSleepEngine? sleepEngine,
  })  : _dbHelper = dbHelper ?? DatabaseHelper(),
        _sleepEngine = sleepEngine ?? OvernightSleepEngine(dbHelper: dbHelper);

  /// Rileva finestre di sonno analizzando la telemetria nell'intervallo specificato (default: ultime 24h)
  Future<List<DetectedSleepWindow>> detectSleepSessions({
    DateTime? windowStart,
    DateTime? windowEnd,
    double? rhrBaseline,
  }) async {
    final now = Clock.current.now();
    final end = windowEnd ?? now;
    final start = windowStart ?? end.subtract(const Duration(hours: 24));

    // Estrae i punti telemetrici registrati su SQLite
    final rawPoints = await _dbHelper.getTelemetriaInTimeRange(start, end);
    if (rawPoints.isEmpty) {
      return [];
    }

    return analyzeTelemetryRecords(rawPoints, rhrBaseline: rhrBaseline);
  }

  /// Analizza una sequenza di record telemetrici per identificare le sessioni di sonno
  List<DetectedSleepWindow> analyzeTelemetryRecords(
    List<Map<String, dynamic>> records, {
    double? rhrBaseline,
  }) {
    if (records.isEmpty) return [];

    // Ordina i record per timestamp
    final sortedRecords = List<Map<String, dynamic>>.from(records);
    sortedRecords.sort((a, b) {
      final tA = _extractTimestamp(a).millisecondsSinceEpoch;
      final tB = _extractTimestamp(b).millisecondsSinceEpoch;
      return tA.compareTo(tB);
    });

    final profileRhr = rhrBaseline ?? 55.0;

    // 1. Calcola soglie relative basate sulla distribuzione dei dati
    final enmoValues = <double>[];
    final hrValues = <double>[];

    for (final r in sortedRecords) {
      final enmo = (r['accel_enmo'] ?? r['motion_var'] ?? r['enmo'] as num?)?.toDouble();
      if (enmo != null && enmo >= 0.0) {
        enmoValues.add(enmo);
      }
      final hr = (r['bpm'] ?? r['hr'] as num?)?.toDouble();
      if (hr != null && hr > 30.0) {
        hrValues.add(hr);
      }
    }

    final p30Enmo = enmoValues.isNotEmpty ? _percentile(enmoValues, 0.30) : 0.015;
    final effectiveEnmoQuietThresh = math.max(0.012, math.min(p30Enmo, 0.030));

    final medianHr = hrValues.isNotEmpty ? _percentile(hrValues, 0.50) : profileRhr * 1.25;
    final maxSleepHr = math.max(profileRhr * 1.20, medianHr);

    // 2. Suddivide in epoche da 30 secondi
    final firstTs = _extractTimestamp(sortedRecords.first);
    final lastTs = _extractTimestamp(sortedRecords.last);

    final totalEpochs = (lastTs.difference(firstTs).inSeconds / 30).ceil();
    if (totalEpochs <= 0) return [];

    // Mappa i record nelle epoche da 30s
    final List<List<Map<String, dynamic>>> epochBuckets = List.generate(totalEpochs, (_) => []);
    for (final r in sortedRecords) {
      final ts = _extractTimestamp(r);
      final idx = (ts.difference(firstTs).inSeconds / 30).floor();
      if (idx >= 0 && idx < totalEpochs) {
        epochBuckets[idx].add(r);
      }
    }

    // 3. Valuta ogni epoca come quieta (true), sveglia (false), o gap (null)
    final List<bool?> epochStatus = []; // true = quiet, false = active, null = missing
    for (int i = 0; i < totalEpochs; i++) {
      final bucket = epochBuckets[i];
      if (bucket.isEmpty) {
        epochStatus.add(null);
      } else {
        double sumEnmo = 0.0;
        double sumHr = 0.0;
        int enmoCount = 0;
        int hrCount = 0;

        for (final r in bucket) {
          final enmo = (r['accel_enmo'] ?? r['motion_var'] ?? r['enmo'] as num?)?.toDouble();
          if (enmo != null) {
            sumEnmo += enmo;
            enmoCount++;
          }
          final hr = (r['bpm'] ?? r['hr'] as num?)?.toDouble();
          if (hr != null && hr > 0) {
            sumHr += hr;
            hrCount++;
          }
        }

        final avgEnmo = enmoCount > 0 ? sumEnmo / enmoCount : 0.0;
        final avgHr = hrCount > 0 ? sumHr / hrCount : profileRhr;

        final isQuiet = avgEnmo <= effectiveEnmoQuietThresh && avgHr <= maxSleepHr;
        epochStatus.add(isQuiet);
      }
    }

    // 4. Identifica i blocchi di sonno
    // Regole:
    // - Inizio: almeno 20 minuti quieti consecutivi (40 epoche da 30s)
    // - Tolleranza risvegli intermedi: max 20 minuti di veglia/gap (40 epoche)
    // - Fine: ultima epoca quieta prima di >= 15 minuti (30 epoche) di veglia sostenuta
    final List<DetectedSleepWindow> detectedWindows = [];

    const int minConsecutiveQuietEpochs = 30; // ~15-20 min di sonno quieto per confermare inizio
    const int maxWakeGapEpochs = 40;          // 20 min tolleranza buchi/microrisvegli
    const int sustainedWakeEpochs = 30;       // 15 min attività motoria per confermare risveglio

    int i = 0;
    while (i < totalEpochs) {
      int quietCount = 0;
      int activeWakeCount = 0;
      int candidateStartIdx = -1;

      while (i < totalEpochs) {
        final st = epochStatus[i];
        if (st == true) {
          if (candidateStartIdx == -1) candidateStartIdx = i;
          quietCount++;
          activeWakeCount = 0;
          if (quietCount >= minConsecutiveQuietEpochs) {
            break; // Trovato inizio sonno valido!
          }
        } else if (st == false) {
          activeWakeCount++;
          if (activeWakeCount >= 6) { // 3 minuti di veglia attiva rompono l'inizio sonno
            candidateStartIdx = -1;
            quietCount = 0;
          }
        }
        i++;
      }

      if (candidateStartIdx == -1 || quietCount < minConsecutiveQuietEpochs) {
        break; // Nessun altro sonno trovato
      }

      // Estendi il sonno fino a risveglio confermato
      int lastQuietIdx = i;
      int activeWakeStreak = 0;
      int gapStreak = 0;
      int cursor = i + 1;

      while (cursor < totalEpochs) {
        final st = epochStatus[cursor];
        if (st == true) {
          lastQuietIdx = cursor;
          activeWakeStreak = 0;
          gapStreak = 0;
        } else if (st == false) {
          activeWakeStreak++;
          if (activeWakeStreak >= sustainedWakeEpochs) {
            // Risveglio confermato: fine sonno all'ultima epoca quieta
            break;
          }
        } else {
          // Gap di campionamento
          gapStreak++;
          if (gapStreak >= maxWakeGapEpochs * 2) { // 40 min consecutivi di assenza dati interrompono la sessione
            break;
          }
        }
        cursor++;
      }

      final startTs = firstTs.add(Duration(seconds: candidateStartIdx * 30));
      final endTs = firstTs.add(Duration(seconds: (lastQuietIdx + 1) * 30));
      final durationMin = endTs.difference(startTs).inMinutes;

      // 5. Valuta durata e tipologia (Main Sleep >= 180m, Nap >= 20m e < 180m)
      if (durationMin >= 20) {
        final isNap = durationMin < 180;

        // Calcola copertura reale
        int recordedEpochs = 0;
        for (int k = candidateStartIdx; k <= lastQuietIdx; k++) {
          if (epochStatus[k] != null) recordedEpochs++;
        }
        final totalCandidateEpochs = lastQuietIdx - candidateStartIdx + 1;
        final coveragePct = totalCandidateEpochs > 0
            ? (recordedEpochs / totalCandidateEpochs) * 100.0
            : 0.0;

        final provenance = coveragePct >= 70.0 ? 'REAL' : 'PARTIAL';

        // Calcolo tassativo data_iso: SEMPRE la data locale del risveglio (SLP-02)
        final localEnd = endTs.toLocal();
        final wakeDateIso = '${localEnd.year.toString().padLeft(4, '0')}-'
            '${localEnd.month.toString().padLeft(2, '0')}-'
            '${localEnd.day.toString().padLeft(2, '0')}';

        // Estrai tutti i record compresi nella finestra temporale
        final windowRecords = sortedRecords.where((r) {
          final t = _extractTimestamp(r);
          return !t.isBefore(startTs) && !t.isAfter(endTs);
        }).toList();

        detectedWindows.add(DetectedSleepWindow(
          startTime: startTs,
          endTime: endTs,
          isNap: isNap,
          wakeDateIso: wakeDateIso,
          coveragePct: coveragePct,
          provenance: provenance,
          records: windowRecords,
        ));
      }

      i = math.max(cursor, lastQuietIdx + 1);
    }

    return detectedWindows;
  }

  /// Esegue il rilevamento e persiste le sessioni scoperte tramite OvernightSleepEngine
  Future<int> runPosteriorDetectionAndPersist({
    DateTime? windowStart,
    DateTime? windowEnd,
  }) async {
    final sessions = await detectSleepSessions(
      windowStart: windowStart,
      windowEnd: windowEnd,
    );

    if (sessions.isEmpty) return 0;

    int saved = 0;
    final profile = await _dbHelper.getUserProfile();
    final baseline = {
      'rhr_mean': (profile?['rhr_baseline_mean'] as num?)?.toDouble() ?? 55.0,
      'rmssd_mean': (profile?['hrv_baseline_mean'] as num?)?.toDouble() ?? 65.0,
      'rmssd_std': (profile?['hrv_baseline_std'] as num?)?.toDouble() ?? 15.0,
      'sleep_need_min': (profile?['sleep_baseline_min'] as num?)?.toDouble() ?? 480.0,
    };

    for (final session in sessions) {
      try {
        await _sleepEngine.processNightlyTelemetry(
          rawTelemetryRecords: session.records,
          userBaseline30d: baseline,
          windowStart: session.startTime,
          windowEnd: session.endTime,
          targetDateIso: session.wakeDateIso, // SLP-02: data locale del risveglio
        );
        saved++;
      } catch (e) {
        debugPrint('[PosteriorSleepDetector] Errore persistenza sessione ${session.wakeDateIso}: $e');
      }
    }

    return saved;
  }

  DateTime _extractTimestamp(Map<String, dynamic> map) {
    final ms = (map['timestamp_utc_ms'] as num?)?.toInt();
    if (ms != null && ms > 0) {
      return DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
    }
    final tsStr = map['timestamp']?.toString();
    if (tsStr != null) {
      return DateTime.tryParse(tsStr)?.toUtc() ?? Clock.current.now().toUtc();
    }
    return Clock.current.now().toUtc();
  }

  double _percentile(List<double> values, double p) {
    if (values.isEmpty) return 0.0;
    final sorted = List<double>.from(values)..sort();
    final idx = (p * (sorted.length - 1)).round();
    return sorted[idx.clamp(0, sorted.length - 1)];
  }
}
