class JournalHabitRecord {
  final String habitQuestion;
  final bool answeredYes;
  final DateTime date;
  final double nextDayRecoveryPct;
  final double nextDaySleepPct;

  JournalHabitRecord({
    required this.habitQuestion,
    required this.answeredYes,
    required this.date,
    required this.nextDayRecoveryPct,
    required this.nextDaySleepPct,
  });
}

class HabitImpactResult {
  final String habitQuestion;
  final double recoveryImpactPct; // Impatto netto (+/- %) sul Recupero
  final double sleepImpactPct; // Impatto netto (+/- %) sul Sonno
  final int countYes;
  final int countNo;
  final bool hasStatisticalValidity; // True se registrato >= 5 Sì e >= 5 No nei 90 giorni
  final String statusMessage;

  HabitImpactResult({
    required this.habitQuestion,
    required this.recoveryImpactPct,
    required this.sleepImpactPct,
    required this.countYes,
    required this.countNo,
    required this.hasStatisticalValidity,
    required this.statusMessage,
  });
}

/// Modulo 10 & 11: Journal Impact Engine (Whoop 5.0)
/// Analizza le correlazioni tra le abitudini del Diario e i punteggi di Recupero/Sonno.
/// Applica la regola di validità statistica (almeno 5 "Sì" e 5 "No" negli ultimi 90 giorni).
class JournalImpactEngine {
  /// Soglia minima di campioni per la validità statistica
  static const int minSamplesRequired = 5;
  static const int maxWindowDays = 90;

  /// Calcola l'impatto percentuale (+/- %) di una specifica abitudine
  static HabitImpactResult calculateHabitImpact({
    required String habitQuestion,
    required List<JournalHabitRecord> records,
    DateTime? referenceDate,
  }) {
    final now = referenceDate ?? DateTime.now();
    final cutoffDate = now.subtract(const Duration(days: maxWindowDays));

    // Filtriamo i record negli ultimi 90 giorni per la domanda specifica
    final filtered = records.where((r) {
      return r.habitQuestion == habitQuestion && r.date.isAfter(cutoffDate);
    }).toList();

    final yesRecords = filtered.where((r) => r.answeredYes).toList();
    final noRecords = filtered.where((r) => !r.answeredYes).toList();

    final countYes = yesRecords.length;
    final countNo = noRecords.length;

    // Regola di Validità Statistica: Almeno 5 "Sì" e 5 "No"
    final isValid = countYes >= minSamplesRequired && countNo >= minSamplesRequired;

    if (!isValid) {
      return HabitImpactResult(
        habitQuestion: habitQuestion,
        recoveryImpactPct: 0.0,
        sleepImpactPct: 0.0,
        countYes: countYes,
        countNo: countNo,
        hasStatisticalValidity: false,
        statusMessage:
            'Servono almeno $minSamplesRequired registrazioni "Sì" e $minSamplesRequired "No" (Attuali: $countYes Sì, $countNo No)',
      );
    }

    // Media Recupero nei giorni "Sì" vs "No"
    final meanRecoveryYes =
        yesRecords.map((r) => r.nextDayRecoveryPct).reduce((a, b) => a + b) / countYes;
    final meanRecoveryNo =
        noRecords.map((r) => r.nextDayRecoveryPct).reduce((a, b) => a + b) / countNo;

    // Media Sonno nei giorni "Sì" vs "No"
    final meanSleepYes =
        yesRecords.map((r) => r.nextDaySleepPct).reduce((a, b) => a + b) / countYes;
    final meanSleepNo =
        noRecords.map((r) => r.nextDaySleepPct).reduce((a, b) => a + b) / countNo;

    final recoveryImpact = meanRecoveryYes - meanRecoveryNo;
    final sleepImpact = meanSleepYes - meanSleepNo;

    final sign = recoveryImpact >= 0 ? '+' : '';
    final message =
        'Impatto Statistico Convalidato ($countYes Sì, $countNo No): $sign${recoveryImpact.toStringAsFixed(1)}% su Recupero';

    return HabitImpactResult(
      habitQuestion: habitQuestion,
      recoveryImpactPct: recoveryImpact,
      sleepImpactPct: sleepImpact,
      countYes: countYes,
      countNo: countNo,
      hasStatisticalValidity: true,
      statusMessage: message,
    );
  }
}
