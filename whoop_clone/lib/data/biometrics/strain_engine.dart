import 'dart:math';

enum Gender { male, female }

/// Modulo Strain Calculator (Whoop 5.0 / Patent US11574722B2)
/// Calcola HRmax (Tanaka/Gellish), HRR, TRIMP Cardio Load (b=1.92), Muscular Load
/// e compressione logaritmica saturante sulla scala 0.0 – 21.0.
class StrainEngine {
  /// Formula di Tanaka per la Frequenza Cardiaca Massima: HRmax = 208 - (0.7 * age)
  static double calculateTanakaHrMax(int age) {
    return 208.0 - (0.7 * age);
  }

  /// Formula di Gellish per la Frequenza Cardiaca Massima: HRmax = 192 - (0.007 * age^2)
  static double calculateGellishHrMax(int age) {
    return 192.0 - (0.007 * pow(age, 2));
  }

  /// Riserva di Frequenza Cardiaca Istantanea (Heart Rate Reserve - HRR(t)):
  /// HRR(t) = (HR(t) - HRrest) / (HRmax - HRrest)
  static double calculateHrr({
    required double currentBpm,
    required double hrRest,
    required double hrMax,
  }) {
    if (hrMax <= hrRest) return 0.0;
    return ((currentBpm - hrRest) / (hrMax - hrRest)).clamp(0.0, 1.0);
  }

  /// Carico Cardiovascolare TRIMP (Bannister Modificato):
  /// L_cardio = D * HRR * (a * e^(b * HRR)) con parametro b = 1.92 (uomini) / 1.67 (donne)
  static double calculateCardioTrimpLoad({
    required double durationMinutes,
    required double hrMean,
    required double hrRest,
    required double hrMax,
    Gender gender = Gender.male,
  }) {
    if (durationMinutes <= 0 || hrMax <= hrRest) return 0.0;

    final hrr = calculateHrr(currentBpm: hrMean, hrRest: hrRest, hrMax: hrMax);

    final double b = (gender == Gender.male) ? 1.92 : 1.67;
    final double a = (gender == Gender.male) ? 0.64 : 0.86;

    final trimp = durationMinutes * hrr * (a * exp(b * hrr));
    return trimp;
  }

  /// Carico Muscolare per allenamenti di forza:
  /// L_muscular = sum(Volume_i * Intensita_i * Meff)
  static double calculateMuscularLoad({
    required double totalVolumeKg,
    required double avgIntensityRpe, // 1.0 - 10.0 RPE
    double mEffFactor = 1.25, // Percentuale di massa corporea attiva
  }) {
    return (totalVolumeKg * (avgIntensityRpe / 10.0) * mEffFactor) / 100.0;
  }

  /// Compressione Logaritmica Saturante (Scala 0.0 – 21.0):
  /// Strain = 21.0 * (1 - e^(-k * L_total))
  static double trimpToWhoopStrain(double lTotal) {
    if (lTotal <= 0) return 0.0;

    const double k = 0.0075; // Costante di attenuazione calibrata
    final strain = 21.0 * (1.0 - exp(-k * lTotal));
    return strain.clamp(0.0, 21.0);
  }

  /// Calcola lo Sforzo Giornaliero o di un Allenamento a partire dai parametri di frequenza
  static double calculateStrain({
    required double durationMinutes,
    required double hrMean,
    required double hrRest,
    required int age,
    Gender gender = Gender.male,
    double muscularLoad = 0.0,
  }) {
    final hrMax = calculateTanakaHrMax(age);
    final cardioLoad = calculateCardioTrimpLoad(
      durationMinutes: durationMinutes,
      hrMean: hrMean,
      hrRest: hrRest,
      hrMax: hrMax,
      gender: gender,
    );
    final lTotal = cardioLoad + muscularLoad;
    return trimpToWhoopStrain(lTotal);
  }
}
