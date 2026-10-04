import 'dart:math';

class StrengthSet {
  final String exerciseName;
  final int sets;
  final int reps;
  final double loadKg;
  final double accelVelocityMs; // Vettore velocità 3 assi accelerometro/giroscopio (m/s)
  final double rpe; // Borg Scale 1 - 20

  StrengthSet({
    required this.exerciseName,
    required this.sets,
    required this.reps,
    required this.loadKg,
    this.accelVelocityMs = 1.0,
    this.rpe = 10.0,
  });
}

/// Modulo 8: Strength Trainer Engine (Whoop 5.0)
/// Calcola il Muscular Load (Volume, Serie, Reps, Carico kg e Vettori Accelerometro 3 Assi)
/// e la combinazione con l'RPE (1-20) per lo Strain totale della forza.
class StrengthTrainerEngine {
  /// Calcola il Muscular Load di una singola serie/esercizio
  static double calculateSetMuscularLoad(StrengthSet set) {
    // 1. Volume Meccanico (Serie * Reps * Carico kg)
    final volume = set.sets * set.reps * set.loadKg;

    // 2. Moltiplicatore Dinamico Cinematico da Accelerometro/Giroscopio 3 Assi (m/s)
    final velocityMultiplier = 1.0 + (0.4 * set.accelVelocityMs.clamp(0.2, 3.0));

    // 3. Moltiplicatore RPE (Scala 1 - 20)
    final rpeMultiplier = 0.5 + (0.05 * set.rpe.clamp(1.0, 20.0));

    return volume * velocityMultiplier * rpeMultiplier;
  }

  /// Calcola il Muscular Load totale della sessione e lo converte in Strain Muscolare (0.0 – 21.0)
  static double calculateMuscularStrain(List<StrengthSet> exerciseSets) {
    if (exerciseSets.isEmpty) return 0.0;

    double totalMuscularLoad = 0.0;
    for (var set in exerciseSets) {
      totalMuscularLoad += calculateSetMuscularLoad(set);
    }

    // Mappatura logaritmica del Muscular Load sulla scala 0.0 – 21.0
    const double k = 0.0005;
    const double maxLoadRef = 6000.0;

    final num = log(1.0 + k * totalMuscularLoad);
    final den = log(1.0 + k * maxLoadRef);

    final muscularStrain = 21.0 * (num / den);
    return muscularStrain.clamp(0.0, 21.0);
  }

  /// Combina Cardio Strain (TRIMP) e Muscular Strain in uno Strain Totale Allenamento Forza
  static double combineCardioAndMuscularStrain({
    required double cardioStrain,
    required double muscularStrain,
  }) {
    // Combinazione quadratica non lineare (Root Sum of Squares ponderata)
    final combined = sqrt(pow(cardioStrain, 2) + pow(muscularStrain, 2));
    return combined.clamp(0.0, 21.0);
  }
}
