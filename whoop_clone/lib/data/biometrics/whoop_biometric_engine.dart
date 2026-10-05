import 'strain_engine.dart';
import 'strength_trainer_engine.dart';
import 'recovery_engine.dart';
import 'sleep_need_engine.dart';
import 'stress_monitor_engine.dart';
import 'journal_impact_engine.dart';

/// WhoopBiometricEngine è la Facade principale che coordina i 6 algoritmi biometrici Whoop 5.0:
/// 1. Strain Engine (HRmax Tanaka, HRR, TRIMP Bannister, Scala Log 0.0–21.0)
/// 2. Strength Trainer Engine (Muscular Load, Velocità 3 Assi, RPE)
/// 3. Recovery Engine (lnRMSSD, Cold Start Baseline, Z-score, Curva Sigmoidale %)
/// 4. Sleep Need Engine & Sveglia Smart Aptica
/// 5. Stress Monitor 24H (Smoothing EMA & Cyclic Sighing)
/// 6. Journal Impact Engine (Soglia di Validità Statistica 5 Sì / 5 No)
class WhoopBiometricEngine {
  final StressMonitorEngine _stressEngine = StressMonitorEngine(alpha: 0.20);

  // Getters diretti ai singoli motori biometrici
  StressMonitorEngine get stressEngine => _stressEngine;

  /// 1. Strain Engine: Calcola lo Strain da Frequenza Cardiaca
  double calculateCardioStrain({
    required double durationMinutes,
    required double hrMean,
    required double hrRest,
    required int userAge,
    Gender gender = Gender.male,
  }) {
    return StrainEngine.calculateStrain(
      durationMinutes: durationMinutes,
      hrMean: hrMean,
      hrRest: hrRest,
      age: userAge,
      gender: gender,
    );
  }

  /// 2. Strength Trainer Engine: Calcola lo Strain Totale (Cardio + Muscular Load)
  double calculateStrengthWorkoutStrain({
    required List<StrengthSet> sets,
    required double cardioStrain,
  }) {
    final muscularStrain = StrengthTrainerEngine.calculateMuscularStrain(sets);
    return StrengthTrainerEngine.combineCardioAndMuscularStrain(
      cardioStrain: cardioStrain,
      muscularStrain: muscularStrain,
    );
  }

  /// 3. Recovery Engine: Calcola il Punteggio di Recupero % con gestione del Cold Start
  double? calculateRecoveryScore({
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
    return RecoveryEngine.calculateRecoveryScore(
      currentRmssdMs: currentRmssdMs,
      historicalLnRmssd: historicalLnRmssd,
      currentFcrBpm: currentFcrBpm,
      historicalRhr: historicalRhr,
      currentRespRateRpm: currentRespRateRpm,
      baselineRespRateRpm: baselineRespRateRpm,
      sleepEfficiencyPct: sleepEfficiencyPct,
      sleepPerformancePct: sleepPerformancePct,
      nightlyStress: nightlyStress,
      skinTempDeltaC: skinTempDeltaC,
    );
  }

  /// 4. Sleep Need & Sveglia Smart
  double calculateSleepNeedMinutes({
    required double dailyStrain,
    double baselineSleepMin = 480.0,
    double accumulatedSleepDebtMin = 0.0,
    double napsMin = 0.0,
  }) {
    return SleepNeedEngine.calculateSleepNeedMinutes(
      dailyStrain: dailyStrain,
      baselineSleepMin: baselineSleepMin,
      accumulatedSleepDebtMin: accumulatedSleepDebtMin,
      napsMin: napsMin,
    );
  }

  SmartAlarmStatus evaluateSmartAlarm({
    required DateTime currentTime,
    required DateTime latestWakeUpTime,
    required SmartAlarmMode mode,
    required double currentSleepDurationMin,
    required double sleepNeedMin,
    required double estimatedCurrentRecoveryPct,
    SleepGoalType goal = SleepGoalType.perform,
  }) {
    return SleepNeedEngine.evaluateSmartAlarm(
      currentTime: currentTime,
      latestWakeUpTime: latestWakeUpTime,
      mode: mode,
      currentSleepDurationMin: currentSleepDurationMin,
      sleepNeedMin: sleepNeedMin,
      estimatedCurrentRecoveryPct: estimatedCurrentRecoveryPct,
      goal: goal,
    );
  }

  /// 5. Stress Monitor 24H: Calcolo dell'Indice di Stress smussato con EMA
  double updateLiveStressIndex({
    required double currentBpm,
    required double hrRest,
    required double hrMax,
    required double currentRmssdMs,
    required double baselineRmssdMs,
  }) {
    return _stressEngine.updateSmoothedStressIndex(
      currentBpm: currentBpm,
      hrRest: hrRest,
      hrMax: hrMax,
      currentRmssdMs: currentRmssdMs,
      baselineRmssdMs: baselineRmssdMs,
    );
  }

  /// 6. Journal Impact Engine: Calcolo dell'impatto statistico con soglia 5 Sì / 5 No
  HabitImpactResult calculateJournalHabitImpact({
    required String habitQuestion,
    required List<JournalHabitRecord> records,
  }) {
    return JournalImpactEngine.calculateHabitImpact(
      habitQuestion: habitQuestion,
      records: records,
    );
  }
}
