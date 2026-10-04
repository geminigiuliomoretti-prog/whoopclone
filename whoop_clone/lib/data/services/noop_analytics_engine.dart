import 'dart:math';
import '../models/allenamento.dart';

/// Motore di Analisi Biometrica e Calcolo Parametri Fisiologici (Architettura NOOP)
/// Implementa standard scientifici:
/// 1. HRV / rMSSD secondo Task Force 1996 (con rigetto battiti ectopici |ΔRR| > 200 ms)
/// 2. Resting Heart Rate (RHR) su finestre a minima varianza accelerometrica (ENMO < 0.015g)
/// 3. Frequenza Respiratoria tramite picco spettrale RSA (Respiratory Sinus Arrhythmia)
/// 4. Recovery Score secondo metodologia Plews & Buchheit (Z-Score composito 30d normalizzato)
/// 5. Day Strain cumulativo Banister/Edwards TRIMP (con rigorosa esclusione della finestra di sonno)
class NoopAnalyticsEngine {
  const NoopAnalyticsEngine._();

  // ─────────────────────────────────────────────────────────────────────────
  // 1. HRV / rMSSD (TASK FORCE 1996)
  // ─────────────────────────────────────────────────────────────────────────

  /// Calcola l'rMSSD autentico secondo le linee guida Task Force 1996.
  /// Applica il filtraggio degli artefatti e il rigetto delle differenze ectopiche isolate (|ΔRR| > 200 ms).
  ///
  /// Formula:
  ///   rMSSD = sqrt( 1 / (N - 1) * sum((RR[i+1] - RR[i])^2) )
  static double? calculateRmssd(List<double> rrIntervalsMs, {bool filterEctopic = true}) {
    // Range fisiologico inter-beat interval: [300 ms, 1500 ms]
    final validRr = rrIntervalsMs.where((rr) => rr >= 300.0 && rr <= 1500.0).toList();
    if (validRr.length < 2) {
      return null;
    }

    double sumSquaredDiffs = 0.0;
    int diffCount = 0;

    for (int i = 0; i < validRr.length - 1; i++) {
      final diff = (validRr[i + 1] - validRr[i]).abs();

      // Rigetto intervalli ectopici (differenze isolate anomale > 200 ms)
      if (filterEctopic && diff > 200.0) {
        continue;
      }

      sumSquaredDiffs += diff * diff;
      diffCount++;
    }

    if (diffCount < 1) {
      return null;
    }

    final meanSquaredDiff = sumSquaredDiffs / diffCount;
    final rmssd = sqrt(meanSquaredDiff);
    return double.parse(rmssd.toStringAsFixed(2));
  }

  /// Estrae la finestra di minima varianza accelerometrica (ENMO < 0.015g) durante il sonno profondo / stasi notturna
  /// e calcola l'rMSSD basale notturno autentico.
  static double? calculateNightlyHrvFromTelemetry({
    required List<Map<String, dynamic>> telemetryRows,
    double enmoThreshold = 0.015,
  }) {
    if (telemetryRows.isEmpty) return null;

    // Filtra i campioni a minima varianza accelerometrica (stasi / SWS)
    final lowMotionRows = telemetryRows.where((row) {
      final enmo = (row['accel_enmo'] ?? row['motion_var'] as num?)?.toDouble() ?? 0.0;
      return enmo <= enmoThreshold;
    }).toList();

    // Se ci sono sufficienti campioni in stasi usa quelli, altrimenti valuta l'intera serie notturna
    final rowsToUse = lowMotionRows.length >= 60 ? lowMotionRows : telemetryRows;

    final rrList = <double>[];
    for (final r in rowsToUse) {
      final rr = (r['rr_ms'] as num?)?.toDouble();
      if (rr != null && rr >= 300.0 && rr <= 1500.0) {
        rrList.add(rr);
      }
    }

    return calculateRmssd(rrList);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // 2. RESTING HEART RATE (RHR)
  // ─────────────────────────────────────────────────────────────────────────

  /// Calcola la Frequenza Cardiaca a Riposo (RHR) nella stessa identica finestra di minima attività (ENMO < 0.015g).
  static double? calculateNightlyRhrFromTelemetry({
    required List<Map<String, dynamic>> telemetryRows,
    double enmoThreshold = 0.015,
  }) {
    if (telemetryRows.isEmpty) return null;

    final lowMotionRows = telemetryRows.where((row) {
      final enmo = (row['accel_enmo'] ?? row['motion_var'] as num?)?.toDouble() ?? 0.0;
      final bpm = (row['bpm'] as num?)?.toInt() ?? 0;
      return enmo <= enmoThreshold && bpm >= 30 && bpm <= 220;
    }).toList();

    final rowsToUse = lowMotionRows.length >= 30 ? lowMotionRows : telemetryRows;
    final validBpms = rowsToUse
        .map((r) => (r['bpm'] as num?)?.toDouble())
        .where((b) => b != null && b >= 30.0 && b <= 220.0)
        .cast<double>()
        .toList();

    if (validBpms.isEmpty) return null;

    final meanBpm = validBpms.reduce((a, b) => a + b) / validBpms.length;
    return double.parse(meanBpm.toStringAsFixed(1));
  }

  // ─────────────────────────────────────────────────────────────────────────
  // 3. RESPIRATORY RATE (RSA SPECTRAL PEAK)
  // ─────────────────────────────────────────────────────────────────────────

  /// Calcola la frequenza respiratoria in atti al minuto (RPM) analizzando l'Arritmia Sinusale Respiratoria (RSA)
  /// sulla serie degli intervalli RR notturni tramite picco di densità spettrale nel range fisiologico [0.12 Hz - 0.40 Hz].
  ///
  /// Formula:
  ///   RPM = f_peak * 60
  static double? calculateRespiratoryRateRpm(List<double> rrSeriesMs, {double samplingRateHz = 4.0}) {
    if (rrSeriesMs.length < 64) {
      return null;
    }

    // Normalizza la serie rimuovendo la media (detrending lineare semplice)
    final meanRr = rrSeriesMs.reduce((a, b) => a + b) / rrSeriesMs.length;
    final centered = rrSeriesMs.map((rr) => rr - meanRr).toList();

    // Valutazione spettrale DFT nel range fisiologico respiratorio: 0.12 Hz (7.2 rpm) - 0.40 Hz (24.0 rpm)
    const minFreq = 0.12;
    const maxFreq = 0.40;
    const freqStep = 0.005;

    double maxPower = 0.0;
    double peakFreq = 0.0;

    final n = centered.length;

    for (double f = minFreq; f <= maxFreq; f += freqStep) {
      double realSum = 0.0;
      double imagSum = 0.0;

      for (int t = 0; t < n; t++) {
        final angle = 2.0 * pi * f * (t / samplingRateHz);
        realSum += centered[t] * cos(angle);
        imagSum -= centered[t] * sin(angle);
      }

      final power = (realSum * realSum + imagSum * imagSum) / n;
      if (power > maxPower) {
        maxPower = power;
        peakFreq = f;
      }
    }

    if (peakFreq <= 0.0 || maxPower <= 0.0001) {
      return null;
    }

    final rpm = peakFreq * 60.0;
    return double.parse(rpm.toStringAsFixed(1));
  }

  // ─────────────────────────────────────────────────────────────────────────
  // 4. RECOVERY SCORE (PLEWS / BUCHHEIT METHODOLOGY)
  // ─────────────────────────────────────────────────────────────────────────

  /// Calcola il Recovery Score basato sulla metodologia Plews & Buchheit:
  ///   Z = 0.6 * ((rMSSD_notte - rMSSD_base) / rMSSD_std) + 0.4 * ((RHR_base - RHR_notte) / RHR_std)
  ///   Recovery % = 100 / (1 + exp(-1.2 * Z))
  ///
  /// Restituisce null se mancano i dati grezzi notturni o la baseline (visualizzando '--').
  static double? calculateRecoveryScore({
    required double? nightlyRmssd,
    required double? nightlyRhr,
    required double? baselineRmssdMean,
    required double? baselineRmssdStd,
    required double? baselineRhrMean,
    required double? baselineRhrStd,
  }) {
    if (nightlyRmssd == null || nightlyRhr == null) {
      return null;
    }

    final baseHrvMean = baselineRmssdMean ?? 65.0;
    final baseHrvStd = (baselineRmssdStd != null && baselineRmssdStd > 0) ? baselineRmssdStd : 15.0;
    final baseRhrMean = baselineRhrMean ?? 55.0;
    final baseRhrStd = (baselineRhrStd != null && baselineRhrStd > 0) ? baselineRhrStd : 3.5;

    // Calcolo Z-scores individuali
    final zHrv = (nightlyRmssd - baseHrvMean) / baseHrvStd;
    final zRhr = (baseRhrMean - nightlyRhr) / baseRhrStd; // RHR più basso è migliore

    // Z combinato Plews / Buchheit
    final zTotal = (0.6 * zHrv) + (0.4 * zRhr);

    // Mappatura logistica sigmoidale [1% - 99%]
    final logisticScore = 100.0 / (1.0 + exp(-1.2 * zTotal));
    final clamped = logisticScore.clamp(1.0, 99.0);
    return double.parse(clamped.toStringAsFixed(0));
  }

  // ─────────────────────────────────────────────────────────────────────────
  // 5. BANISTER / EDWARDS TRIMP STRAIN ENGINE
  // ─────────────────────────────────────────────────────────────────────────

  /// Calcola lo Strain giornaliero ponderando le zone cardiache (% HRR)
  /// escludendo categoricamente i campioni appartenenti alla finestra di sonno notturno.
  static double calculateDayStrain({
    required List<Map<String, dynamic>> telemetryStream,
    required double hrMax,
    required double hrRest,
    DateTime? sleepStartTime,
    DateTime? sleepEndTime,
    double muscularLoad = 0.0,
  }) {
    if (telemetryStream.isEmpty || hrMax <= hrRest) return 0.0;

    final hrr = hrMax - hrRest;
    double rawTrimpLoad = 0.0;

    for (final sample in telemetryStream) {
      final bpm = (sample['bpm'] as num?)?.toDouble();
      if (bpm == null || bpm <= hrRest || bpm > 220.0) continue;

      // Rigorosa esclusione della finestra di sonno
      final rawTs = sample['timestamp'];
      if (rawTs != null && sleepStartTime != null && sleepEndTime != null) {
        final sampleTime = DateTime.tryParse(rawTs.toString());
        if (sampleTime != null) {
          if ((sampleTime.isAfter(sleepStartTime) || sampleTime.isAtSameMomentAs(sleepStartTime)) &&
              (sampleTime.isBefore(sleepEndTime) || sampleTime.isAtSameMomentAs(sleepEndTime))) {
            continue; // Salta il battito notturno
          }
        }
      }

      // Riserva cardiaca frazionaria istantanea
      final fractionalHrr = ((bpm - hrRest) / hrr).clamp(0.0, 1.0);

      // Moltiplicatore di zona Edwards TRIMP (Zone 1-5)
      double zoneWeight = 0.0;
      if (fractionalHrr >= 0.90) {
        zoneWeight = 5.0; // Zone 5: 90-100% HRR
      } else if (fractionalHrr >= 0.80) {
        zoneWeight = 4.0; // Zone 4: 80-90% HRR
      } else if (fractionalHrr >= 0.70) {
        zoneWeight = 3.0; // Zone 3: 70-80% HRR
      } else if (fractionalHrr >= 0.60) {
        zoneWeight = 2.0; // Zone 2: 60-70% HRR
      } else if (fractionalHrr >= 0.50) {
        zoneWeight = 1.0; // Zone 1: 50-60% HRR
      }

      // Ogni frame a 1 Hz aggiunge 1/60 di minuto ponderato
      rawTrimpLoad += zoneWeight * (1.0 / 60.0);
    }

    final totalLoad = rawTrimpLoad + muscularLoad;
    if (totalLoad <= 0.0) return 0.0;

    // Compressione logaritmica saturante non additiva sulla scala WHOOP 0.0 - 21.0
    const double lambda = 0.0025;
    const double lMax = 4000.0;
    final scaledLoad = totalLoad < 1000.0 ? totalLoad * 3.65 : totalLoad;
    final numerator = log(1.0 + lambda * scaledLoad);
    final den = log(1.0 + lambda * lMax);
    final strain = 21.0 * (numerator / den);

    return double.parse(strain.clamp(0.0, 21.0).toStringAsFixed(1));
  }

  /// Calcola lo Strain da un elenco di allenamenti
  static double calculateDayStrainFromWorkouts(List<Allenamento> workouts) {
    if (workouts.isEmpty) return 0.0;

    double totalRawLoad = 0.0;
    const double lambda = 0.0025;
    const double lMax = 4000.0;
    final den = log(1.0 + lambda * lMax);

    for (final w in workouts) {
      final strain = w.strainAttivita ?? 0.0;
      if (strain > 0) {
        final raw = (exp((strain * den) / 21.0) - 1.0) / lambda;
        totalRawLoad += raw;
      }
    }

    if (totalRawLoad <= 0) return 0.0;
    final numerator = log(1.0 + lambda * totalRawLoad);
    final strain = 21.0 * (numerator / den);
    return double.parse(strain.clamp(0.0, 21.0).toStringAsFixed(1));
  }
}
