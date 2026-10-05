import 'dart:math';

enum RecoveryZone { green, yellow, red }

class RecoveryBaselineResult {
  final double meanLnRmssd;
  final double stdDevLnRmssd;
  final double meanRhr;
  final double stdDevRhr;
  final int daysCount;
  final bool isCalibrating;
  final String statusMessage;

  RecoveryBaselineResult({
    required this.meanLnRmssd,
    required this.stdDevLnRmssd,
    required this.meanRhr,
    required this.stdDevRhr,
    required this.daysCount,
    required this.isCalibrating,
    required this.statusMessage,
  });
}

/// Modulo Recovery Calculator (Whoop 5.0 / SWS Phase Analysis)
/// Esegue il calcolo del Recovery Score esclusivamente sui dati di Slow Wave Sleep (SWS):
/// 1. Normalizzazione Z-score su baseline 30 giorni per ln(rMSSD) e RHR.
/// 2. Combinazione lineare pesata: 0.50*zHRV - 0.30*zRHR - 0.10*zRR + 0.10*SleepEff
/// 3. Mappatura sigmoidale/clamp (1% – 99%) e classificazione zone (Verde, Gialla, Rossa).
class RecoveryEngine {
  /// Trasformata logaritmica naturale di rMSSD: ln(rMSSD)
  static double calculateLnRmssd(double rmssdMs) {
    if (rmssdMs <= 0) return 0.0;
    return log(rmssdMs);
  }

  /// Calcolo Z-Score: z = (x - μ) / σ
  static double calculateZScore({
    required double value,
    required double mean,
    required double stdDev,
  }) {
    if (stdDev <= 0) return 0.0;
    return (value - mean) / stdDev;
  }

  /// Calcolo progressivo della Baseline 30 giorni (μ, σ) con gestione Cold Start
  static RecoveryBaselineResult calculateBaseline(List<double> historicalLnRmssd, List<double> historicalRhr) {
    final daysCount = historicalLnRmssd.length;

    if (daysCount < 4) {
      final meanLn = historicalLnRmssd.isNotEmpty
          ? historicalLnRmssd.reduce((a, b) => a + b) / daysCount
          : log(65.0);
      final meanRhr = historicalRhr.isNotEmpty
          ? historicalRhr.reduce((a, b) => a + b) / historicalRhr.length
          : 52.0;

      return RecoveryBaselineResult(
        meanLnRmssd: meanLn,
        stdDevLnRmssd: 0.25,
        meanRhr: meanRhr,
        stdDevRhr: 3.0,
        daysCount: daysCount,
        isCalibrating: true,
        statusMessage: 'Calibrazione Iniziale ($daysCount/4 giorni)',
      );
    }

    final windowLn = daysCount > 30 ? historicalLnRmssd.sublist(daysCount - 30) : historicalLnRmssd;
    final windowRhr = historicalRhr.length > 30 ? historicalRhr.sublist(historicalRhr.length - 30) : historicalRhr;

    final meanLn = windowLn.reduce((a, b) => a + b) / windowLn.length;
    final meanRhr = windowRhr.reduce((a, b) => a + b) / windowRhr.length;

    double varLnSum = 0.0;
    for (var val in windowLn) {
      varLnSum += pow(val - meanLn, 2);
    }
    double stdDevLn = sqrt(varLnSum / windowLn.length);
    if (stdDevLn < 0.05) stdDevLn = 0.05;

    double varRhrSum = 0.0;
    for (var val in windowRhr) {
      varRhrSum += pow(val - meanRhr, 2);
    }
    double stdDevRhr = sqrt(varRhrSum / windowRhr.length);
    if (stdDevRhr < 1.0) stdDevRhr = 1.0;

    return RecoveryBaselineResult(
      meanLnRmssd: meanLn,
      stdDevLnRmssd: stdDevLn,
      meanRhr: meanRhr,
      stdDevRhr: stdDevRhr,
      daysCount: windowLn.length,
      isCalibrating: false,
      statusMessage: windowLn.length < 30 ? 'Baseline Progressiva (${windowLn.length}/30d)' : 'Baseline 30d a Regime',
    );
  }

  /// Combinazione Lineare Pesata & Mappatura Sigmoidale (1 - 99%) - Sprint 8
  /// Z_tot = (0.45 * zHRV) + (0.30 * zRHR) + (0.15 * (SleepPerf - 70)/15)
  /// Penalty_stress = max(0, (nightlyStress - 1.0) * 15.0) applicata al recovery score
  /// Penalty_vitals = -5.0% se Skin Temp devia di > +-1.2 °C o Resp Rate devia di > +-1.5 rpm
  static double? calculateRecoveryScore({
    required double? currentRmssdMs,
    required List<double> historicalLnRmssd,
    required double? currentFcrBpm,
    required List<double> historicalRhr,
    double? currentRespRateRpm,
    double? baselineRespRateRpm,
    double? sleepEfficiencyPct,
    double? sleepPerformancePct,
    double? nightlyStress,
    double? skinTempDeltaC,
  }) {
    if (currentRmssdMs == null || currentRmssdMs <= 0 || currentFcrBpm == null || currentFcrBpm <= 0) {
      return null;
    }

    final currentLnRmssd = calculateLnRmssd(currentRmssdMs);
    final baseline = calculateBaseline(historicalLnRmssd, historicalRhr);

    // 1. zHRV & zRHR (lower RHR is better, so meanRhr - currentFcrBpm)
    final zHrv = calculateZScore(value: currentLnRmssd, mean: baseline.meanLnRmssd, stdDev: baseline.stdDevLnRmssd);
    final zRhr = (baseline.meanRhr - currentFcrBpm) / (baseline.stdDevRhr > 0 ? baseline.stdDevRhr : 1.0);

    // 2. Penalty Stress Notturno
    final penaltyStress = (nightlyStress != null && nightlyStress > 1.0) ? (nightlyStress - 1.0) * 15.0 : 0.0;

    // 3. Factor Prestazione Sonno
    final sleepPerfFactor = sleepPerformancePct != null ? (sleepPerformancePct - 70.0) / 15.0 : 0.0;

    // 4. Z_tot pesato (z-scores biometrici e prestazione sonno)
    final zTot = (0.45 * zHrv) + (0.30 * zRhr) + (0.15 * sleepPerfFactor);

    // 5. Penalità Vitals Fuori Norma (-5%)
    double penaltyVitals = 0.0;
    final bool hasRespAnomaly = (currentRespRateRpm != null && baselineRespRateRpm != null) &&
        (currentRespRateRpm - baselineRespRateRpm).abs() > 1.5;
    final bool hasTempAnomaly = skinTempDeltaC != null && skinTempDeltaC.abs() > 1.2;

    if (hasRespAnomaly || hasTempAnomaly) {
      penaltyVitals = 5.0;
    }

    // 6. Mappatura e Clamp (1 - 99%)
    final mappedScore = (((zTot + 3.0) / 6.0) * 100.0) - penaltyStress - penaltyVitals;
    return mappedScore.clamp(1.0, 99.0);
  }

  /// Classifica la zona prestazionale: Verde (67-99%), Gialla (34-66%), Rossa (1-33%)
  static RecoveryZone getRecoveryZone(double recoveryScorePct) {
    if (recoveryScorePct >= 67.0) {
      return RecoveryZone.green;
    } else if (recoveryScorePct >= 34.0) {
      return RecoveryZone.yellow;
    } else {
      return RecoveryZone.red;
    }
  }
}
