import 'dart:math';

enum VitalStatus {
  calibration, // < 7 misurazioni notturne nel DB
  inRange,     // Min <= val <= Max
  outOfRange,  // val < Min oppure val > Max
  noData,      // Nessuna misurazione del giorno
}

class VitalEvaluation {
  final String key;
  final String title;
  final double? currentVal;
  final String unit;
  final double? mean30d;
  final double? std30d;
  final double? minRange;
  final double? maxRange;
  final int sampleCount;
  final VitalStatus status;

  VitalEvaluation({
    required this.key,
    required this.title,
    this.currentVal,
    required this.unit,
    this.mean30d,
    this.std30d,
    this.minRange,
    this.maxRange,
    required this.sampleCount,
    required this.status,
  });

  String get badgeText {
    switch (status) {
      case VitalStatus.calibration:
        return 'Calibrazione in corso ($sampleCount/7 giorni)';
      case VitalStatus.inRange:
        return '✔ Nella norma (${minRange?.toStringAsFixed(1)} - ${maxRange?.toStringAsFixed(1)})';
      case VitalStatus.outOfRange:
        return '⚠ Fuori norma (${minRange?.toStringAsFixed(1)} - ${maxRange?.toStringAsFixed(1)})';
      case VitalStatus.noData:
        return 'In attesa di misurazione';
    }
  }
}

class HealthVitalsEngine {
  /// Valuta il parametro biologico rispetto alla baseline storica di 30 giorni (Min = mu - 1.5*std, Max = mu + 1.5*std).
  static VitalEvaluation evaluateVital({
    required String key,
    required String title,
    required double? currentValue,
    required List<double> historical30dValues,
    required String unit,
  }) {
    if (currentValue == null && historical30dValues.isEmpty) {
      return VitalEvaluation(
        key: key,
        title: title,
        currentVal: null,
        unit: unit,
        sampleCount: 0,
        status: VitalStatus.noData,
      );
    }

    final sampleCount = historical30dValues.length;

    if (sampleCount < 7) {
      return VitalEvaluation(
        key: key,
        title: title,
        currentVal: currentValue,
        unit: unit,
        sampleCount: sampleCount,
        status: VitalStatus.calibration,
      );
    }

    // Calcolo Media (mu) e Deviazione Standard (sigma)
    final mean = historical30dValues.reduce((a, b) => a + b) / sampleCount;
    final variance = historical30dValues
            .map((x) => pow(x - mean, 2))
            .reduce((a, b) => a + b) /
        sampleCount;
    double std = sqrt(variance);
    if (std == 0) {
      std = mean * 0.05;
      if (std == 0) std = 1.0;
    }

    final minRange = mean - (1.5 * std);
    final maxRange = mean + (1.5 * std);

    if (currentValue == null) {
      return VitalEvaluation(
        key: key,
        title: title,
        currentVal: null,
        unit: unit,
        mean30d: mean,
        std30d: std,
        minRange: minRange,
        maxRange: maxRange,
        sampleCount: sampleCount,
        status: VitalStatus.noData,
      );
    }

    final inRange = currentValue >= minRange && currentValue <= maxRange;

    return VitalEvaluation(
      key: key,
      title: title,
      currentVal: currentValue,
      unit: unit,
      mean30d: mean,
      std30d: std,
      minRange: minRange,
      maxRange: maxRange,
      sampleCount: sampleCount,
      status: inRange ? VitalStatus.inRange : VitalStatus.outOfRange,
    );
  }
}
