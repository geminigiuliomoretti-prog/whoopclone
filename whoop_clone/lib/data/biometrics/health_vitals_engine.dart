import 'dart:math';
import '../models/personal_baseline.dart';

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
  final bool isBaselinePersonal;

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
    this.isBaselinePersonal = false,
  });

  double? get currentValue => currentVal;
  double? get baselineValue => mean30d;

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
  /// Valuta il parametro biologico rispetto alla baseline storica o alla baseline personale calcolata.
  static VitalEvaluation evaluateVital({
    required String key,
    required String title,
    required double? currentValue,
    required List<double> historical30dValues,
    required String unit,
    PersonalBaseline? personalBaseline,
  }) {
    final int effectiveSampleCount = (personalBaseline != null && personalBaseline.sampleCount >= 7)
        ? personalBaseline.sampleCount
        : (historical30dValues.length >= 7 ? historical30dValues.length : (personalBaseline?.sampleCount ?? historical30dValues.length));

    if (currentValue == null && effectiveSampleCount == 0) {
      return VitalEvaluation(
        key: key,
        title: title,
        currentVal: null,
        unit: unit,
        sampleCount: 0,
        status: VitalStatus.noData,
      );
    }

    if (effectiveSampleCount < 7) {
      return VitalEvaluation(
        key: key,
        title: title,
        currentVal: currentValue,
        unit: unit,
        sampleCount: effectiveSampleCount,
        status: VitalStatus.calibration,
      );
    }

    // Calcolo Media (mu) e Deviazione Standard (sigma)
    final double mean;
    final double std;
    final double minRange;
    final double maxRange;

    if (personalBaseline != null && personalBaseline.sampleCount >= 7) {
      mean = personalBaseline.mean;
      std = personalBaseline.stdDev > 0 ? personalBaseline.stdDev : (mean * 0.05);
      minRange = personalBaseline.normalRangeMin;
      maxRange = personalBaseline.normalRangeMax;
    } else if (historical30dValues.isNotEmpty) {
      mean = historical30dValues.reduce((a, b) => a + b) / effectiveSampleCount;
      final variance = historical30dValues
              .map((x) => pow(x - mean, 2))
              .reduce((a, b) => a + b) /
          effectiveSampleCount;
      double calcStd = sqrt(variance);
      if (calcStd == 0) {
        calcStd = mean * 0.05;
        if (calcStd == 0) calcStd = 1.0;
      }
      std = calcStd;
      minRange = mean - (1.5 * std);
      maxRange = mean + (1.5 * std);
    } else if (personalBaseline != null) {
      mean = personalBaseline.mean;
      std = personalBaseline.stdDev > 0 ? personalBaseline.stdDev : (mean * 0.05);
      minRange = personalBaseline.normalRangeMin;
      maxRange = personalBaseline.normalRangeMax;
    } else {
      mean = currentValue ?? 0.0;
      std = 1.0;
      minRange = mean - (1.5 * std);
      maxRange = mean + (1.5 * std);
    }

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
        sampleCount: effectiveSampleCount,
        status: VitalStatus.noData,
        isBaselinePersonal: personalBaseline != null,
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
      sampleCount: effectiveSampleCount,
      status: inRange ? VitalStatus.inRange : VitalStatus.outOfRange,
      isBaselinePersonal: personalBaseline != null,
    );
  }
}
