import 'dart:math';

enum SmartAlarmMode {
  exactTime,
  sleepGoal,
  inTheGreen,
}

enum SleepGoalType {
  peak, // 100% del fabbisogno sonno
  perform, // 85% del fabbisogno sonno
  getBy, // 70% del fabbisogno sonno
}

class SmartAlarmStatus {
  final bool shouldTriggerNow;
  final String triggerReason;
  final SmartAlarmMode mode;

  SmartAlarmStatus({
    required this.shouldTriggerNow,
    required this.triggerReason,
    required this.mode,
  });
}

/// Modulo Sleep Calculator (Whoop 5.0 / coaching-service/v2/sleepneed)
/// Formula: N_sleep = S_baseline + S_debt + f(S_day) - T_nap
/// f(S_day) = alpha * (S_day)^beta (funzione conica: da +30 a +60 min per Strain > 17.0)
class SleepNeedEngine {
  /// Impatto dello Strain Giornaliero tramite funzione conica f(S_day):
  /// f(S_day) = alpha * (S_day)^beta
  static double calculateStrainSleepImpact(double dailyStrain) {
    if (dailyStrain <= 0) return 0.0;
    const double alpha = 0.12;
    const double beta = 2.1;
    final extraMin = alpha * pow(dailyStrain, beta);
    return extraMin.clamp(0.0, 75.0); // Da +0 a +75 minuti max
  }

  /// Debito di sonno cumulativo con fattore di decadimento esponenziale lambda:
  /// S_debt = sum(unrecovered_i * e^(-lambda * i))
  static double calculateExponentialSleepDebt(List<double> pastUnrecoveredMin, {double lambda = 0.15}) {
    double debt = 0.0;
    for (int i = 0; i < pastUnrecoveredMin.length; i++) {
      debt += pastUnrecoveredMin[i] * exp(-lambda * i);
    }
    return debt.clamp(0.0, 180.0); // Capped a 3 ore max
  }

  /// Calcola il Fabbisogno Sonno Totale N_sleep in minuti:
  /// N_sleep = S_baseline + S_debt + f(S_day) - T_nap
  static double calculateSleepNeedMinutes({
    double baselineSleepMin = 480.0, // 8 ore
    required double dailyStrain,
    double accumulatedSleepDebtMin = 0.0,
    double napsMin = 0.0,
  }) {
    final strainImpactMin = calculateStrainSleepImpact(dailyStrain);
    final totalNeed = baselineSleepMin + accumulatedSleepDebtMin + strainImpactMin - napsMin;
    return max(300.0, totalNeed); // Minimo 5 ore
  }

  /// Calcola la Prestazione del Sonno (Sleep Performance %):
  /// SleepPerformance % = min(100, (SonnoEffettivo / N_sleep) * 100)
  static double calculateSleepPerformancePct({
    required double actualSleepMin,
    required double sleepNeedMin,
  }) {
    if (sleepNeedMin <= 0) return 100.0;
    final pct = (actualSleepMin / sleepNeedMin) * 100.0;
    return pct.clamp(1.0, 100.0);
  }

  /// Calcola i tre target di sonno: Peak (100%), Perform (85%), Get By (70%)
  static double getTargetSleepMinutes({
    required double sleepNeedMin,
    SleepGoalType goal = SleepGoalType.perform,
  }) {
    switch (goal) {
      case SleepGoalType.peak:
        return sleepNeedMin * 1.00; // Peak 100%
      case SleepGoalType.perform:
        return sleepNeedMin * 0.85; // Perform 85%
      case SleepGoalType.getBy:
        return sleepNeedMin * 0.70; // Get By 70%
    }
  }

  /// Valuta se il trigger della Sveglia Smart Aptica deve scattare
  static SmartAlarmStatus evaluateSmartAlarm({
    required DateTime currentTime,
    required DateTime latestWakeUpTime,
    required SmartAlarmMode mode,
    required double currentSleepDurationMin,
    required double sleepNeedMin,
    required double estimatedCurrentRecoveryPct,
    SleepGoalType goal = SleepGoalType.perform,
  }) {
    if (currentTime.isAfter(latestWakeUpTime) || currentTime.isAtSameMomentAs(latestWakeUpTime)) {
      return SmartAlarmStatus(
        shouldTriggerNow: true,
        triggerReason: 'Raggiunto l\'orario massimo limite sveglia',
        mode: mode,
      );
    }

    switch (mode) {
      case SmartAlarmMode.exactTime:
        return SmartAlarmStatus(
          shouldTriggerNow: false,
          triggerReason: 'In attesa dell\'orario esatto',
          mode: mode,
        );

      case SmartAlarmMode.sleepGoal:
        final targetMin = getTargetSleepMinutes(sleepNeedMin: sleepNeedMin, goal: goal);
        if (currentSleepDurationMin >= targetMin) {
          return SmartAlarmStatus(
            shouldTriggerNow: true,
            triggerReason: 'Obiettivo Sonno ($goal - ${targetMin.toInt()} min) Raggiunto!',
            mode: mode,
          );
        }
        break;

      case SmartAlarmMode.inTheGreen:
        if (estimatedCurrentRecoveryPct >= 67.0) {
          return SmartAlarmStatus(
            shouldTriggerNow: true,
            triggerReason: 'Recupero "In the Green" (${estimatedCurrentRecoveryPct.toInt()}%) Raggiunto!',
            mode: mode,
          );
        }
        break;
    }

    return SmartAlarmStatus(
      shouldTriggerNow: false,
      triggerReason: 'Sonno in corso...',
      mode: mode,
    );
  }
}
