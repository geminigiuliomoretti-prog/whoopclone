import 'dart:math';

enum CyclicSighingPhase {
  inhaleDeep, // Inalazione profonda dal naso (3s)
  inhaleSecond, // Seconda inalazione aggiuntiva dal naso (1.5s)
  exhaleLong, // Espirazione lenta e lunga dalla bocca (6s)
}

class CyclicSighingState {
  final CyclicSighingPhase phase;
  final String instruction;
  final int durationSeconds;

  CyclicSighingState({
    required this.phase,
    required this.instruction,
    required this.durationSeconds,
  });
}

/// Modulo Stress Monitor 24H (Whoop 5.0 / Patent US11574722B2)
/// 1. Indice di Stress di Baevsky (SI = AMo / (2 * Mo * MxDM)).
/// 2. Filtro Accelerometro ENMO (Euclidean Norm Minus One): ENMO = max(0, sqrt(ax^2 + ay^2 + az^2) - 1g).
/// 3. Soppressione movimento: Se ENMO > theta_motion, l'elevazione cardio alimenta lo Strain e il valore di Stress viene soppresso.
class StressMonitorEngine {
  double _smoothedStressIndex = 0.0;
  final double alpha; // Coefficente EMA (0.20)
  final double thetaMotion; // Soglia di movimento ENMO (g)

  StressMonitorEngine({this.alpha = 0.20, this.thetaMotion = 0.15});

  void resetSmoothing() {
    _smoothedStressIndex = 0.0;
  }

  /// Calcola la metrica ENMO dall'accelerometro 3 assi:
  /// ENMO = max(0, sqrt(ax^2 + ay^2 + az^2) - 1.0g)
  static double calculateEnmo({
    required double ax,
    required double ay,
    required double az,
  }) {
    final magnitude = sqrt(ax * ax + ay * ay + az * az);
    return max(0.0, magnitude - 1.0);
  }

  /// Indice di Stress di Baevsky (SI):
  /// SI = AMo / (2 * Mo * MxDM)
  /// AMo: Percentuale di battiti nella classe modale (%)
  /// Mo: Valore modale degli intervalli RR (secondi)
  /// MxDM: Differenza tra intervallo massimo e minimo (secondi)
  static double calculateBaevskyStressIndex({
    required double aMoPct,
    required double moSec,
    required double mxDmSec,
  }) {
    if (moSec <= 0 || mxDmSec <= 0) return 0.0;
    final si = aMoPct / (2.0 * moSec * mxDmSec);
    // Normalizzazione in scala 0.0 - 3.0
    return (si / 150.0).clamp(0.0, 3.0);
  }

  /// Calcola l'Indice di Stress Istantaneo Grezzo (0.0 - 3.0) con filtro ENMO
  double calculateRawStressIndex({
    required double currentBpm,
    required double hrRest,
    required double hrMax,
    required double currentRmssdMs,
    required double baselineRmssdMs,
    double enmo = 0.0,
  }) {
    // Regola Soppressione Movimento ENMO:
    // Se ENMO > thetaMotion, la frequenza cardiaca è dovuta al movimento (Strain) e lo Stress psicofisico viene soppresso.
    if (enmo > thetaMotion) {
      return 0.0; // Soppresso durante attività motoria
    }

    if (hrMax <= hrRest || baselineRmssdMs <= 0) return 0.0;

    // Componente HR & HRV
    final hrRatio = ((currentBpm - hrRest) / (hrMax - hrRest)).clamp(0.0, 1.0);
    final stressHr = hrRatio * 3.0;

    final hrvRatio = (currentRmssdMs / baselineRmssdMs).clamp(0.1, 2.0);
    final stressHrv = ((1.5 - hrvRatio) * 2.0).clamp(0.0, 3.0);

    final rawStress = (0.60 * stressHr) + (0.40 * stressHrv);
    return rawStress.clamp(0.0, 3.0);
  }

  /// Smoothing Exponential Moving Average (EMA)
  double updateSmoothedStressIndex({
    required double currentBpm,
    required double hrRest,
    required double hrMax,
    required double currentRmssdMs,
    required double baselineRmssdMs,
    double enmo = 0.0,
  }) {
    final raw = calculateRawStressIndex(
      currentBpm: currentBpm,
      hrRest: hrRest,
      hrMax: hrMax,
      currentRmssdMs: currentRmssdMs,
      baselineRmssdMs: baselineRmssdMs,
      enmo: enmo,
    );

    if (_smoothedStressIndex == 0.0) {
      _smoothedStressIndex = raw;
    } else {
      _smoothedStressIndex = (alpha * raw) + ((1.0 - alpha) * _smoothedStressIndex);
    }

    return _smoothedStressIndex.clamp(0.0, 3.0);
  }

  static String getStressCategory(double stressIndex) {
    if (stressIndex < 1.0) {
      return 'Basso / Riposo';
    } else if (stressIndex < 2.0) {
      return 'Moderato';
    } else {
      return 'Elevato';
    }
  }

  static CyclicSighingState getCyclicSighingPhase(int secondInCycle) {
    final cycleTime = secondInCycle % 11;

    if (cycleTime < 3) {
      return CyclicSighingState(
        phase: CyclicSighingPhase.inhaleDeep,
        instruction: 'Inspira profondamente dal naso...',
        durationSeconds: 3,
      );
    } else if (cycleTime < 5) {
      return CyclicSighingState(
        phase: CyclicSighingPhase.inhaleSecond,
        instruction: 'Seconda inalazione nasale (riempi i polmoni)!',
        durationSeconds: 2,
      );
    } else {
      return CyclicSighingState(
        phase: CyclicSighingPhase.exhaleLong,
        instruction: 'Espira lentamente e completamente dalla bocca...',
        durationSeconds: 6,
      );
    }
  }
}
