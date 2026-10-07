import 'dart:math';
import '../../data/models/allenamento.dart';

/// WHOOP Analytics Engine — Algoritmi Biometrici Reverse-Engineered
/// 
/// 1. STRESS SCORE ENGINE (0.0 - 3.0):
///    - Trasformazione Logaritmica & Z-Score (14 giorni)
///    - Motion Gating (Filtro Accelerometrico ENMO/Acc)
///    - Integratore Simpatovagale Z_SVB (65% HRV, 35% HR)
///    - Mappatura Sigmoidale Bounded [0.0 - 3.0]
/// 
/// 2. STRAIN SCORE ENGINE (0.0 - 21.0):
///    - Frequenza Cardiaca di Riserva (HRR) e 6 Zone (w_z 0.0 a 5.0)
///    - Carico Grezzo Cumulativo L_Total = L_CV + L_Musc
///    - Trasformazione Logaritmica Saturante (Non-Additiva)
class WhoopAnalyticsEngine {
  const WhoopAnalyticsEngine._();

  // ─────────────────────────────────────────────────────────────────────
  // 1. STRESS SCORE ENGINE (0.0 - 3.0)
  // ─────────────────────────────────────────────────────────────────────

  /// Calcola lo Stress Istantaneo (0.0 - 3.0) seguendo la formulazione a 5 passaggi:
  ///
  /// A. Trasformazione Logaritmica & Z-Score (14 giorni):
  ///    lnRMSSD(t) = ln(RMSSD(t))
  ///    z_HRV(t) = (meanLnRmssd14d - lnRMSSD(t)) / stdLnRmssd14d
  ///    z_HR(t) = (HR(t) - rhr14d) / stdRhr14d
  ///
  /// B. Motion Gating (Filtro Accelerometrico):
  ///    Se Acc > 1.2 => f(Acc) = 1.0 / (1.0 + 0.8 * (Acc - 1.2)), altrimenti 1.0
  ///
  /// C. Integratore Simpatovagale & Sigmoide:
  ///    Z_SVB(t) = (0.65 * z_HRV(t)) + (0.35 * f(Acc) * z_HR(t))
  ///    Stress(t) = 3.0 / (1.0 + exp(-0.85 * Z_SVB(t)))
  static double calculateStressScore({
    required double hrLive,
    required double hrvLiveMs,
    double? meanLnRmssd14d,
    double? stdLnRmssd14d,
    double? rhr14d,
    double stdRhr14d = 3.5,
    double accMagnitude = 1.0,
    // Parametri di retrocompatibilità
    double? hrRest,
    double? baselineHrvMean,
    double baselineHrvStd = 15.0,
    double? zHrvOverride,
    double? zHrOverride,
  }) {
    if (hrLive <= 0) return 0.0;

    final double effectiveRhr = rhr14d ?? hrRest ?? 55.0;

    // A.1 Z-Score HRV (trasformazione logaritmica)
    double zHrv = 0.0;
    if (zHrvOverride != null) {
      zHrv = zHrvOverride;
    } else {
      final double effectiveHrvMean = baselineHrvMean ?? 65.0;
      final double targetMeanLn = meanLnRmssd14d ?? log(max(1.0, effectiveHrvMean));
      final double targetStdLn = stdLnRmssd14d ?? (baselineHrvStd / max(1.0, effectiveHrvMean));

      final double safeHrv = max(1.0, hrvLiveMs);
      final double lnHrvAtt = log(safeHrv);
      final double safeStdLn = targetStdLn > 0 ? targetStdLn : 0.23;

      zHrv = (targetMeanLn - lnHrvAtt) / safeStdLn;
    }

    // A.2 Z-Score HR
    double zHr = 0.0;
    if (zHrOverride != null) {
      zHr = zHrOverride;
    } else {
      final double safeStdRhr = stdRhr14d > 0 ? stdRhr14d : 3.5;
      zHr = (hrLive - effectiveRhr) / safeStdRhr;
    }

    // B. Motion Gating (Filtro Accelerometrico - Brevetto US11574722B2)
    const double sogliaAcc = 1.2;
    double fattoreMovimento = 1.0;
    if (accMagnitude > sogliaAcc) {
      final double deltaAcc = accMagnitude - sogliaAcc;
      fattoreMovimento = 1.0 / (1.0 + 8.0 * deltaAcc + 15.0 * pow(deltaAcc, 2));
    }

    // C. Integratore Simpatovagale Z_SVB
    // Limita z-score a range fisiologico [-3.0, 4.0] e attenua l'attivazione simpatica durante movimento
    const double pesoHrv = 0.65;
    const double pesoHr = 0.35;
    final double zSvb = fattoreMovimento * ((pesoHrv * zHrv.clamp(-3.0, 4.0)) + (pesoHr * zHr.clamp(-3.0, 4.0)));

    // Sigmoide Modificata (k = 0.85, z0 = 0.0)
    const double kPendenza = 0.85;
    const double zZero = 0.0;
    final double stress = 3.0 / (1.0 + exp(-kPendenza * (zSvb - zZero)));

    return double.parse(stress.clamp(0.0, 3.0).toStringAsFixed(2));
  }

  /// Ritorna la categoria di Stress in base al punteggio (0.0 - 3.0)
  static String getStressCategory(double stressIndex) {
    if (stressIndex < 1.0) {
      return 'Basso / Riposo';
    } else if (stressIndex <= 2.0) {
      return 'Moderato';
    } else {
      return 'Elevato';
    }
  }

  // ─────────────────────────────────────────────────────────────────────
  // 2. STRAIN SCORE ENGINE (0.0 - 21.0)
  // ─────────────────────────────────────────────────────────────────────

  /// Estimazione non lineare di Gellish per HRmax: 192 - (0.007 * age^2)
  static double calculateGellishHrMax(int age) {
    return 192.0 - (0.007 * pow(age, 2));
  }

  /// Riserva Cardiaca HRR = HRmax - RHR
  static double calculateHrr({required double hrMax, required double hrRest}) {
    return max(0.0, hrMax - hrRest);
  }

  /// Moltiplicatore di Zona Cardiaca w_z (Zone 0 a Zone 5) basato su %HRR
  static double getZoneMultiplier(double hr, double hrMax, double hrRest) {
    final hrr = calculateHrr(hrMax: hrMax, hrRest: hrRest);
    if (hrr <= 0) return 0.0;

    final z0Soglia = hrRest + 0.50 * hrr;
    final z1Soglia = hrRest + 0.60 * hrr;
    final z2Soglia = hrRest + 0.70 * hrr;
    final z3Soglia = hrRest + 0.80 * hrr;
    final z4Soglia = hrRest + 0.90 * hrr;

    if (hr < z0Soglia) {
      return 0.0;
    } else if (hr < z1Soglia) {
      return 1.0;
    } else if (hr < z2Soglia) {
      return 2.0;
    } else if (hr < z3Soglia) {
      return 3.0;
    } else if (hr < z4Soglia) {
      return 4.0;
    } else {
      return 5.0;
    }
  }

  /// Carico Muscolare: L_Musc = 0.05 * ln(1.0 + volMuscolare)
  static double calculateMuscularLoad(double volMuscolare) {
    if (volMuscolare <= 0) return 0.0;
    return 0.05 * log(1.0 + volMuscolare);
  }

  /// Trasformazione Logaritmica Saturante (Non-Additiva):
  /// Strain = 21.0 * ln(1.0 + 0.0025 * (rawLoad * 3.65)) / ln(1.0 + 0.0025 * 4000.0)
  static double convertRawLoadToStrain(double rawLoad) {
    if (rawLoad <= 0) return 0.0;
    const double scaleFactor = 3.65;
    final double scaledLoad = rawLoad * scaleFactor;
    const double lambda = 0.0025;
    const double lMax = 4000.0;
    final num = log(1.0 + lambda * scaledLoad);
    final den = log(1.0 + lambda * lMax);
    final strain = 21.0 * (num / den);
    return double.parse(strain.clamp(0.0, 21.0).toStringAsFixed(1));
  }

  /// Inverte la trasformazione logaritmica saturante per ottenere L_Total da uno Strain
  static double convertStrainToRawLoad(double strain) {
    if (strain <= 0) return 0.0;
    const double scaleFactor = 3.65;
    const double lambda = 0.0025;
    const double lMax = 4000.0;
    final den = log(1.0 + lambda * lMax);
    final rawLoad = ((exp((strain * den) / 21.0) - 1.0) / lambda) / scaleFactor;
    return rawLoad;
  }

  /// Calcola lo Strain da un flusso di battiti a 1 Hz
  static double calculateStrain({
    required List<int> heartRateStream,
    required int hrMax,
    required int hrRest,
    double muscularLoad = 0.0,
    int age = 30,
  }) {
    if (heartRateStream.isEmpty) return 0.0;

    final effectiveHrMax = hrMax > 0 ? hrMax.toDouble() : calculateGellishHrMax(age);
    final effectiveHrRest = hrRest.toDouble();

    double rawCardioLoad = 0.0;
    for (final hr in heartRateStream) {
      // Filtraggio Artefatti da Movimento: scarta picchi spuri > 220 bpm o HR <= RHR
      if (hr <= 0 || hr > 220 || hr <= effectiveHrRest) continue;

      final wz = getZoneMultiplier(hr.toDouble(), effectiveHrMax, effectiveHrRest);
      // Ogni secondo corrisponde a (1 / 60) minuti di carico della zona
      rawCardioLoad += wz * (1.0 / 60.0);
    }

    final totalRawLoad = rawCardioLoad + muscularLoad;
    return convertRawLoadToStrain(totalRawLoad);
  }

  /// Calcola lo Sforzo Giornaliero (Day Strain) non-additivo aggregando gli allenamenti del giorno
  static double calculateDayStrain(List<Allenamento> workouts) {
    if (workouts.isEmpty) return 0.0;

    double totalRawLoad = 0.0;
    for (final w in workouts) {
      final strain = w.strainAttivita ?? 0.0;
      if (strain > 0) {
        totalRawLoad += convertStrainToRawLoad(strain);
      }
    }

    return convertRawLoadToStrain(totalRawLoad);
  }

  // ─────────────────────────────────────────────────────────────────────
  // 3. RECOVERY & SLEEP NEED ENGINE
  // ─────────────────────────────────────────────────────────────────────

  /// Calcola il Recovery Score (1 - 99 %)
  static int calculateRecovery({
    required double hrvMssd,
    required double hrv30dMean,
    required double hrv30dStd,
    required int rhrNight,
    required double rhr30dMean,
    required double rhr30dStd,
    required double sleepPerformancePct,
  }) {
    if (hrvMssd <= 0 || hrv30dMean <= 0) return 50;
    if (hrv30dStd <= 0 || rhr30dStd <= 0) return 50;

    final double lnHrv = log(hrvMssd);
    final double lnHrvMean = log(hrv30dMean);
    final double sigmaLnHrv = hrv30dStd / hrv30dMean;
    final double zHrv = (lnHrv - lnHrvMean) / (sigmaLnHrv > 0 ? sigmaLnHrv : 0.2);

    final double zRhr = (rhr30dMean - rhrNight) / rhr30dStd;
    final double sleepComponent = (sleepPerformancePct - 70.0) / 15.0;

    final double zTot = (0.55 * zHrv) + (0.35 * zRhr) + (0.10 * sleepComponent);
    final double recoveryRaw = 100.0 / (1.0 + exp(-1.2 * zTot));
    return recoveryRaw.round().clamp(1, 99);
  }

  static double calculateRecoveryScorePct({
    required double currentHrvMs,
    required double baselineHrvMean,
    required double baselineHrvStd,
    required double currentRhrBpm,
    required double baselineRhrMean,
    required double baselineRhrStd,
    required double sleepPerformancePct,
    double nightlyStress = 0.5,
    double skinTempDeltaC = 0.0,
    double currentRespRateRpm = 14.5,
    double baselineRespRateRpm = 14.0,
  }) {
    final rec = calculateRecovery(
      hrvMssd: currentHrvMs,
      hrv30dMean: baselineHrvMean,
      hrv30dStd: baselineHrvStd,
      rhrNight: currentRhrBpm.round(),
      rhr30dMean: baselineRhrMean,
      rhr30dStd: baselineRhrStd,
      sleepPerformancePct: sleepPerformancePct,
    );

    double penalty = max(0.0, (nightlyStress - 1.0) * 15.0);
    if (skinTempDeltaC.abs() > 1.2 || (currentRespRateRpm - baselineRespRateRpm).abs() > 1.5) {
      penalty += 5.0;
    }

    final finalScore = (rec - penalty).clamp(1.0, 99.0);
    return double.parse(finalScore.toStringAsFixed(0));
  }

  /// Calcola il Fabbisogno di Sonno in minuti
  static int calculateSleepNeed({
    required int baselineMinutes,
    required int sleepDebtMinutes,
    required double dayStrain,
    required int napMinutes,
  }) {
    final int strainImpact = (2.5 * pow(dayStrain, 1.2)).round();
    final int sleepNeed = baselineMinutes + sleepDebtMinutes + strainImpact - napMinutes;
    return max(0, sleepNeed);
  }

  /// Calcola il Debito di Sonno accumulato (in minuti) con decadimento progressivo su finestra rolling
  static double calculateAccumulatedSleepDebt({
    required List<({double sleepNeedMin, double actualSleepMin})> historicalSleeps,
    double decayFactor = 0.80,
  }) {
    if (historicalSleeps.isEmpty) return 0.0;
    double debt = 0.0;
    for (final day in historicalSleeps) {
      final deficit = day.sleepNeedMin - day.actualSleepMin;
      debt = (debt * decayFactor) + (deficit > 0 ? deficit : 0.0);
    }
    return double.parse(debt.clamp(0.0, 300.0).toStringAsFixed(1));
  }

  static int calculateSleepNeedMinutes({
    double baselineNeedMin = 480.0,
    required double dayStrain,
    double sleepDebtMin = 0.0,
    double napMinutes = 0.0,
  }) {
    return calculateSleepNeed(
      baselineMinutes: baselineNeedMin.round(),
      sleepDebtMinutes: sleepDebtMin.round(),
      dayStrain: dayStrain,
      napMinutes: napMinutes.round(),
    );
  }

  static double calculateSleepPerformancePct({
    required double actualDurationMin,
    required double sleepNeedMin,
  }) {
    if (sleepNeedMin <= 0) return 100.0;
    final pct = (actualDurationMin / sleepNeedMin) * 100.0;
    return double.parse(pct.clamp(1.0, 100.0).toStringAsFixed(1));
  }
}
