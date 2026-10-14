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

        final epochTime = firstTs.add(Duration(seconds: i * 30));
        final localHour = epochTime.toLocal().hour;

        final double strictSleepHrCeiling = profileRhr + 9.0; // es. 50 + 9 = 59 bpm max per confermare sonno quieto
        final bool isQuiet;
        if (localHour >= 21 || localHour < 7) {
          // Fascia notturna (21:00 - 07:00):
          final double allowedHr = (localHour >= 21 && localHour < 23)
              ? (profileRhr + 6.5) // Sul divano tra le 21 e le 22:35 la FC è > RHR + 6.5: non è sonno!
              : strictSleepHrCeiling;
          isQuiet = avgEnmo <= effectiveEnmoQuietThresh && avgHr <= allowedHr;
        } else {
          // Dopo le 07:00 del mattino (07:00 - 21:00): per restare addormentato serve FC basale stretta e zero moto
          isQuiet = avgEnmo <= 0.008 && avgHr <= (profileRhr + 4.5);
        }
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
    const int sustainedWakeEpochs = 12;       // 6 min attività motoria per confermare risveglio

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
      int morningHighHrStreak = 0;
      int cursor = i + 1;

      while (cursor < totalEpochs) {
        final bucket = epochBuckets[cursor];
        double sumHr = 0.0;
        int hrCount = 0;
        double maxEnmo = 0.0;
        for (final r in bucket) {
          final enmo = (r['accel_enmo'] ?? r['motion_var'] ?? r['enmo'] as num?)?.toDouble();
          if (enmo != null && enmo > maxEnmo) {
            maxEnmo = enmo;
          }
          final hr = (r['bpm'] ?? r['hr'] as num?)?.toDouble();
          if (hr != null && hr > 0) {
            sumHr += hr;
            hrCount++;
          }
        }
        final double avgHr = hrCount > 0 ? sumHr / hrCount : profileRhr;
        final epochTime = firstTs.add(Duration(seconds: cursor * 30));
        final localHour = epochTime.toLocal().hour;

        if (avgHr >= profileRhr + 18.0) {
          morningHighHrStreak++;
        } else {
          morningHighHrStreak = 0;
        }

        int recentWakeCount = 0;
        final int checkStart = math.max(0, cursor - 11);
        for (int k = checkStart; k <= cursor; k++) {
          if (epochStatus[k] == false) {
            recentWakeCount++;
          }
        }

        if (localHour >= 6) {
          final bool isFrankWake = (morningHighHrStreak >= 3) ||
              (avgHr >= 85.0) ||
              (cursor >= candidateStartIdx + 11 && recentWakeCount >= 8);
          if (isFrankWake) {
            // Risveglio franco mattutino: interrompi immediatamente e fissa lastQuietIdx
            // all'ultima epoca quieta prima dell'innalzamento cardiaco mattutino (~07:00)
            int quietBeforeRise = lastQuietIdx;
            while (quietBeforeRise > candidateStartIdx) {
              final b = epochBuckets[quietBeforeRise];
              double bSum = 0.0;
              int bCount = 0;
              for (final r in b) {
                final h = (r['bpm'] ?? r['hr'] as num?)?.toDouble();
                if (h != null && h > 0) {
                  bSum += h;
                  bCount++;
                }
              }
              final bHr = bCount > 0 ? bSum / bCount : profileRhr;
              if (bHr <= profileRhr + 6.0 && epochStatus[quietBeforeRise] == true) {
                break;
              }
              quietBeforeRise--;
            }
            if (quietBeforeRise >= candidateStartIdx) {
              lastQuietIdx = quietBeforeRise;
            }
            break;
          }
        }

        final st = epochStatus[cursor];
        if (st == true) {
          lastQuietIdx = cursor;
          activeWakeStreak = 0;
          gapStreak = 0;
        } else if (st == false) {
          activeWakeStreak++;
          final int wakeThreshold = (localHour >= 6) ? sustainedWakeEpochs : 30;
          if (activeWakeStreak >= wakeThreshold) {
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

      final int couchSearchLimit = math.min(lastQuietIdx, candidateStartIdx + 180);
      int tInBedIdx = candidateStartIdx;
      double hrAtInBed = profileRhr + 10.0;
      int wakeBoutLen = 0;

      for (int k = candidateStartIdx; k <= couchSearchLimit; k++) {
        final bucket = epochBuckets[k];
        double maxEnmoInEpoch = 0.0;
        double avgHrInEpoch = profileRhr;
        if (bucket.isNotEmpty) {
          for (final r in bucket) {
            final e = (r['accel_enmo'] ?? r['motion_var'] ?? r['enmo'] as num?)?.toDouble() ?? 0.0;
            if (e > maxEnmoInEpoch) maxEnmoInEpoch = e;
          }
          final hrs = bucket
              .map((r) => (r['bpm'] ?? r['hr'] as num?)?.toDouble() ?? 0.0)
              .where((h) => h > 0)
              .toList();
          if (hrs.isNotEmpty) {
            avgHrInEpoch = hrs.reduce((a, b) => a + b) / hrs.length;
          }
        }

        final bool isWalkingToBed = epochStatus[k] == false &&
            (maxEnmoInEpoch >= 0.035 || avgHrInEpoch >= profileRhr + 12.0);

        if (isWalkingToBed) {
          wakeBoutLen++;
          hrAtInBed = avgHrInEpoch;
        } else {
          if (wakeBoutLen >= 4 && (lastQuietIdx - k) >= 240) {
            tInBedIdx = k;
          }
          wakeBoutLen = 0;
        }
      }

      // Risolve l'orario di addormentamento anticipato (Sleep Onset Latency):
      // Quando l'utente si mette a letto (t_in_bed), NON far partire subito il sonno alla prima epoca quieta!
      // Mantieni le epoche iniziali come WAKE finché non si verificano per almeno 6 epoche consecutive (3 min):
      // 1) Quiescenza motoria stabile ENMO <= 0.010g in almeno 5 epoche su 6;
      // 2) Discesa parasimpatica: HR <= min(rhrBaseline + 5.0, nightHrMean + 0.35 * nightHrStd) e calo di almeno 3.0 bpm rispetto all'ingresso a letto.
      final double nightHrMean = hrValues.isNotEmpty ? (hrValues.reduce((a, b) => a + b) / hrValues.length) : profileRhr;
      final double nightHrStd = hrValues.length > 1
          ? math.sqrt(hrValues.map((h) => math.pow(h - nightHrMean, 2)).reduce((a, b) => a + b) / hrValues.length)
          : 6.0;
      final double sleepHrThreshold = math.min(profileRhr + 5.0, nightHrMean + 0.35 * nightHrStd);

      int actualOnsetIdx = tInBedIdx;
      for (int m = tInBedIdx; m <= math.max(tInBedIdx, lastQuietIdx - 6); m++) {
        int quietEnmoCount = 0;
        bool allDropHr = true;

        for (int offset = 0; offset < 6; offset++) {
          final targetIdx = m + offset;
          if (targetIdx >= totalEpochs) break;
          final bucket = epochBuckets[targetIdx];
          double epEnmo = 0.0;
          double epHr = profileRhr;
          if (bucket.isNotEmpty) {
            final eVals = bucket.map<double>((r) => (r['accel_enmo'] ?? r['motion_var'] ?? r['enmo'] as num?)?.toDouble() ?? 0.0);
            if (eVals.isNotEmpty) epEnmo = eVals.reduce((a, b) => a > b ? a : b);
            final hVals = bucket.map<double>((r) => (r['bpm'] ?? r['hr'] as num?)?.toDouble() ?? 0.0).where((h) => h > 0);
            if (hVals.isNotEmpty) epHr = hVals.reduce((a, b) => a + b) / hVals.length;
          }

          if (epEnmo <= 0.010) quietEnmoCount++;
          if (epHr > sleepHrThreshold || (hrAtInBed > 0 && epHr > (hrAtInBed - 3.0))) {
            allDropHr = false;
          }
        }

        if (quietEnmoCount >= 5 && allDropHr) {
          actualOnsetIdx = m;
          break;
        }
      }

      for (int w = tInBedIdx; w < actualOnsetIdx; w++) {
        epochStatus[w] = false;
      }
      candidateStartIdx = tInBedIdx;

      final startTs = firstTs.add(Duration(seconds: candidateStartIdx * 30));
      final endTs = firstTs.add(Duration(seconds: (lastQuietIdx + 1) * 30));
      final durationMin = endTs.difference(startTs).inMinutes;

      // 5. Valuta durata e tipologia (Main Sleep >= 180m, Nap >= 20m e < 180m)
      if (durationMin >= 20) {
        final isNap = durationMin < 180;
        final localStartHour = startTs.toLocal().hour;
        final isDaytime = localStartHour >= 9 && localStartHour < 21;
        // Un pisolino diurno richiede almeno 30 minuti continui di sonno fisiologico confermato
        if (isNap && isDaytime && durationMin < 30) {
          i = lastQuietIdx + 1;
          continue;
        }

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
          startTime: startTs.toLocal(),
          endTime: endTs.toLocal(),
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
    bool forceOverwrite = false,
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
        final existing = await _dbHelper.getSonnoByDate(session.wakeDateIso);
        if (existing != null && existing['provenance'] == 'WHOOP_IMPORT' && !forceOverwrite) {
          debugPrint('[PosteriorSleepDetector] Ignorata sovrascrittura sessione WHOOP_IMPORT per ${session.wakeDateIso}');
          continue;
        }

        final cycleMap = await _dbHelper.getCicloByDate(session.wakeDateIso);
        final cycleNeed = (cycleMap?['sleep_need_min'] as num?)?.toDouble();
        final sessionBaseline = Map<String, dynamic>.from(baseline);
        if (cycleNeed != null && cycleNeed > 0) {
          sessionBaseline['sleep_need_min'] = cycleNeed;
        }

        await _sleepEngine.processNightlyTelemetry(
          rawTelemetryRecords: session.records,
          userBaseline30d: sessionBaseline,
          windowStart: session.startTime,
          windowEnd: session.endTime,
          targetDateIso: session.wakeDateIso, // SLP-02: data locale del risveglio
          forceOverwrite: forceOverwrite,
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
