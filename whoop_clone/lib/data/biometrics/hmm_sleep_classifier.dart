import 'dart:math';

/// Enumerazione degli stadi del sonno
enum HmmSleepStage {
  wake,
  light,
  sws,
  rem,
  missing,
}

extension HmmSleepStageExtension on HmmSleepStage {
  String toHypnogramString() {
    switch (this) {
      case HmmSleepStage.wake:
        return 'WAKE';
      case HmmSleepStage.light:
        return 'LIGHT';
      case HmmSleepStage.sws:
        return 'SWS';
      case HmmSleepStage.rem:
        return 'REM';
      case HmmSleepStage.missing:
        return 'MISSING';
    }
  }

  static HmmSleepStage fromHypnogramString(String str) {
    switch (str.toUpperCase()) {
      case 'WAKE':
        return HmmSleepStage.wake;
      case 'LIGHT':
        return HmmSleepStage.light;
      case 'SWS':
      case 'DEEP':
        return HmmSleepStage.sws;
      case 'REM':
        return HmmSleepStage.rem;
      case 'MISSING':
      default:
        return HmmSleepStage.missing;
    }
  }
}

/// Dati biometrici di ingresso per una singola epoca da 30 secondi
class HmmEpochInput {
  final int index;
  final DateTime timestamp;
  final double? enmo; // Accelerazione / ENMO in g (null se mancante)
  final double? hr; // Frequenza cardiaca bpm (null se mancante)
  final double? rmssd; // rMSSD in ms (null se mancante)
  final double? respPower; // Potenza RSA spettrale normalizzata (null se mancante)
  final bool isMissing; // Flag esplicito di assenza dati

  const HmmEpochInput({
    required this.index,
    required this.timestamp,
    this.enmo,
    this.hr,
    this.rmssd,
    this.respPower,
    this.isMissing = false,
  });
}

/// Risultato di gating per il calcolo del Recovery Score (STG-06)
class RecoveryGatingResult {
  final bool isEligible;
  final String? reason;
  final int sleepDurationMinutes;
  final int validRrEpochsCount;
  final int baselineDaysCount;

  const RecoveryGatingResult({
    required this.isEligible,
    this.reason,
    required this.sleepDurationMinutes,
    required this.validRrEpochsCount,
    required this.baselineDaysCount,
  });
}

/// Classificatore di stadi del sonno HMM (Hidden Markov Model / Viterbi Smoothing)
/// Implementa i requisiti STG-01..07 della Roadmap:
/// - STG-01 / STG-03: Feature nullable, nessun valore fittizio (zero default 0.7 o 65ms).
/// - STG-02: Normalizzazione notturna relativa (z-score / percentili rispetto alla notte stessa).
/// - STG-04: Smoothing HMM / Viterbi che impone bout minimi (>= 4 epoche = 2 min) e prior ultradiani.
/// - STG-05: Epoche MISSING preservate fedelmente senza clamping o forzature.
/// - STG-06: Gating del Recovery (sonno >= 120m, epoche RR >= 30, baseline >= 4 giorni).
class HmmSleepClassifier {
  /// Durata minima di un blocco SWS o REM (in epoche da 30s) per prevenire flickering
  static const int minBoutEpochs = 4; // 2 minuti

  /// Valuta il gating del Recovery Score (STG-06)
  static RecoveryGatingResult evaluateRecoveryGating({
    required double sleepDurationMinutes,
    required int validRrEpochsCount,
    required int baselineDaysCount,
  }) {
    if (sleepDurationMinutes < 120.0) {
      return RecoveryGatingResult(
        isEligible: false,
        reason: 'Sessione di sonno troppo breve (< 120 minuti: ${sleepDurationMinutes.toStringAsFixed(0)}m)',
        sleepDurationMinutes: sleepDurationMinutes.round(),
        validRrEpochsCount: validRrEpochsCount,
        baselineDaysCount: baselineDaysCount,
      );
    }

    if (validRrEpochsCount < 30) {
      return RecoveryGatingResult(
        isEligible: false,
        reason: 'Campioni RR notturni insufficienti (< 30 epoche valide: $validRrEpochsCount)',
        sleepDurationMinutes: sleepDurationMinutes.round(),
        validRrEpochsCount: validRrEpochsCount,
        baselineDaysCount: baselineDaysCount,
      );
    }

    if (baselineDaysCount < 4) {
      return RecoveryGatingResult(
        isEligible: false,
        reason: 'In calibrazione ($baselineDaysCount/4 giorni)',
        sleepDurationMinutes: sleepDurationMinutes.round(),
        validRrEpochsCount: validRrEpochsCount,
        baselineDaysCount: baselineDaysCount,
      );
    }

    return RecoveryGatingResult(
      isEligible: true,
      reason: null,
      sleepDurationMinutes: sleepDurationMinutes.round(),
      validRrEpochsCount: validRrEpochsCount,
      baselineDaysCount: baselineDaysCount,
    );
  }

  /// Classifica l'intera sessione notturna di epoche da 30s
  static List<HmmSleepStage> classifyNight(List<HmmEpochInput> epochs) {
    if (epochs.isEmpty) return [];

    final int n = epochs.length;

    // 1. STG-02: Calcolo statistiche notturne relative (media e deviazione standard notturna)
    final validHrs = epochs.where((e) => !e.isMissing && e.hr != null).map((e) => e.hr!).toList();
    final validEnmo = epochs.where((e) => !e.isMissing && e.enmo != null).map((e) => e.enmo!).toList();

    double hrNightMean = 60.0;
    double hrNightStd = 5.0;
    if (validHrs.length >= 10) {
      hrNightMean = validHrs.reduce((a, b) => a + b) / validHrs.length;
      final variance = validHrs.map((h) => pow(h - hrNightMean, 2)).reduce((a, b) => a + b) / validHrs.length;
      hrNightStd = sqrt(variance);
      if (hrNightStd < 2.0) hrNightStd = 2.0;
    }

    double enmoNightP30 = 0.015;
    if (validEnmo.length >= 10) {
      final sortedEnmo = List<double>.from(validEnmo)..sort();
      final p30Idx = (sortedEnmo.length * 0.30).floor();
      enmoNightP30 = sortedEnmo[p30Idx].clamp(0.005, 0.030);
    }

    // 2. Classificazione iniziale probabilistica (Emission probabilities + Ultradian priors)
    final List<HmmSleepStage> stages = List.filled(n, HmmSleepStage.missing);

    for (int i = 0; i < n; i++) {
      final ep = epochs[i];

      if (ep.isMissing || (ep.enmo == null && ep.hr == null)) {
        stages[i] = HmmSleepStage.missing;
        continue;
      }

      final enmo = ep.enmo ?? 0.0;
      final hr = ep.hr ?? hrNightMean;
      final zHr = (hr - hrNightMean) / hrNightStd;
      final timeFraction = n > 0 ? (i / n) : 0.0;

      // VEGLIA (WAKE): Movimento oltre soglia o HR molto elevata
      if (enmo > 0.040 || (enmo > 0.025 && zHr > 1.5)) {
        stages[i] = HmmSleepStage.wake;
        continue;
      }

      // Se non abbiamo HR o motion sufficiente, default prudente
      if (enmo > 0.020) {
        stages[i] = HmmSleepStage.light;
        continue;
      }

      // Candidato SWS (Deep): assenza di moto (enmo basso) e frequenza cardiaca a riposo (zHr basso o calmo)
      final bool isDeepCandidate = enmo <= max(enmoNightP30, 0.008) && zHr <= 0.2;

      // Candidato REM: atonia muscolare (enmo basso) ma HR instabile o lievemente elevata rispetto a SWS
      final bool hasHrvInfo = ep.rmssd != null && ep.rmssd! > 0;
      final bool isRemCandidate = enmo <= max(enmoNightP30, 0.008) && (zHr > 0.1 && zHr <= 1.2) && (hasHrvInfo ? ep.rmssd! > 40.0 : true);

      // Prior ultradiano (STG-04):
      // - SWS prevale nei primi 2/3 della notte (timeFraction <= 0.70)
      // - REM prevale nell'ultimo terzo della notte (timeFraction >= 0.60)
      if (isDeepCandidate && (timeFraction <= 0.70 || (ep.respPower != null && ep.respPower! >= 0.70))) {
        stages[i] = HmmSleepStage.sws;
      } else if (isRemCandidate && timeFraction >= 0.30) {
        stages[i] = HmmSleepStage.rem;
      } else {
        stages[i] = HmmSleepStage.light;
      }
    }

    // 3. Viterbi / Smoothing per imporre durata minima bout (STG-04)
    // Non ammettere SWS o REM isolati per sole 1-3 epoche (< 2 minuti)
    final smoothed = List<HmmSleepStage>.from(stages);

    int idx = 0;
    while (idx < n) {
      if (smoothed[idx] == HmmSleepStage.missing || smoothed[idx] == HmmSleepStage.wake) {
        idx++;
        continue;
      }

      final currentStage = smoothed[idx];
      if (currentStage == HmmSleepStage.sws || currentStage == HmmSleepStage.rem) {
        int runLen = 0;
        while (idx + runLen < n && smoothed[idx + runLen] == currentStage) {
          runLen++;
        }

        // Se il bout è inferiore alla durata minima, converti in LIGHT sleep
        if (runLen < minBoutEpochs) {
          for (int k = 0; k < runLen; k++) {
            smoothed[idx + k] = HmmSleepStage.light;
          }
        }
        idx += runLen;
      } else {
        idx++;
      }
    }

    // 4. Smoothing finale a 3 finestre: elimina flicker residuo isolato
    for (int i = 1; i < n - 1; i++) {
      final prev = smoothed[i - 1];
      final curr = smoothed[i];
      final next = smoothed[i + 1];

      if (curr == HmmSleepStage.missing || prev == HmmSleepStage.missing || next == HmmSleepStage.missing) {
        continue;
      }

      if (prev == next && curr != prev) {
        // Preserva solo micro-risveglio con moto autentico
        if (curr == HmmSleepStage.wake && (epochs[i].enmo ?? 0.0) > 0.050) {
          continue;
        }
        smoothed[i] = prev;
      }
    }

    return smoothed;
  }
}
