import 'dart:convert';
import 'package:flutter/foundation.dart';

/// Modello per una baseline personale calcolata da dati storici autentici.
/// Supporta media, mediana, deviazione standard, percentili e personal range.
@immutable
class PersonalBaseline {
  final String metricKey; // e.g. 'hrv', 'rhr', 'respiratory_rate', 'skin_temp', etc.
  final String displayName; // e.g. 'Variabilità Frequenza Cardiaca (HRV)'
  final String unit; // e.g. 'ms', 'bpm', 'rpm', '°C', '%', 'min'
  final double baselineValue; // Valore di riferimento (media o mediana)
  final double mean;
  final double median;
  final double stdDev;
  final double minVal;
  final double maxVal;
  final double p10;
  final double p25;
  final double p75;
  final double p90;
  final int sampleCount;
  final String calcPeriod; // e.g. '2025-12-25 - 2026-05-03'
  final String updatedAt;
  final Map<String, dynamic> extraStats;

  const PersonalBaseline({
    required this.metricKey,
    required this.displayName,
    required this.unit,
    required this.baselineValue,
    required this.mean,
    required this.median,
    required this.stdDev,
    required this.minVal,
    required this.maxVal,
    required this.p10,
    required this.p25,
    required this.p75,
    required this.p90,
    required this.sampleCount,
    required this.calcPeriod,
    required this.updatedAt,
    this.extraStats = const {},
  });

  /// Range personale normale (interquartile p25 - p75)
  double get personalRangeMin => p25;
  double get personalRangeMax => p75;

  /// Range esteso normale (media ± 1.5 * deviazione standard)
  double get normalRangeMin => mean - (1.5 * stdDev);
  double get normalRangeMax => mean + (1.5 * stdDev);

  /// Verifica se un valore rientra nel range personale (Q1-Q3)
  bool isInPersonalRange(double value) {
    return value >= personalRangeMin && value <= personalRangeMax;
  }

  /// Verifica se un valore rientra nel range normale allargato (±1.5 sigma)
  bool isInNormalRange(double value) {
    return value >= normalRangeMin && value <= normalRangeMax;
  }

  /// Calcola lo Z-Score rispetto alla baseline personale: z = (x - mu) / sigma
  double zScore(double value) {
    if (stdDev <= 0) return 0.0;
    return (value - mean) / stdDev;
  }

  /// Calcola la deviazione assoluta rispetto alla baseline: delta = x - mu
  double deviation(double value) {
    return value - baselineValue;
  }

  /// Valore formattato con unità di misura
  String get formattedValue {
    if (unit == 'min') {
      final hours = (baselineValue / 60).floor();
      final mins = (baselineValue % 60).round();
      return hours > 0 ? '${hours}h ${mins}m' : '${mins}m';
    } else if (unit == '°C' || unit == 'cal') {
      return '${baselineValue.toStringAsFixed(1)} $unit';
    } else if (unit == '%' || unit == 'ms' || unit == 'bpm' || unit == 'rpm') {
      return '${baselineValue.toStringAsFixed(1)} $unit';
    }
    return '${baselineValue.toStringAsFixed(1)} $unit';
  }

  /// Range personale formattato
  String get formattedPersonalRange {
    if (unit == 'min') {
      final h1 = (p25 / 60).floor();
      final m1 = (p25 % 60).round();
      final h2 = (p75 / 60).floor();
      final m2 = (p75 % 60).round();
      return '${h1}h ${m1}m - ${h2}h ${m2}m';
    }
    return '${p25.toStringAsFixed(1)} - ${p75.toStringAsFixed(1)} $unit';
  }

  Map<String, dynamic> toMap() {
    return {
      'metric_key': metricKey,
      'display_name': displayName,
      'unit': unit,
      'baseline_value': baselineValue,
      'mean': mean,
      'median': median,
      'std_dev': stdDev,
      'min_val': minVal,
      'max_val': maxVal,
      'p10': p10,
      'p25': p25,
      'p75': p75,
      'p90': p90,
      'sample_count': sampleCount,
      'calc_period': calcPeriod,
      'updated_at': updatedAt,
      'extra_stats_json': jsonEncode(extraStats),
    };
  }

  factory PersonalBaseline.fromMap(Map<String, dynamic> map) {
    Map<String, dynamic> parsedExtra = {};
    if (map['extra_stats_json'] != null) {
      try {
        parsedExtra = jsonDecode(map['extra_stats_json'] as String) as Map<String, dynamic>;
      } catch (_) {}
    }

    return PersonalBaseline(
      metricKey: map['metric_key'] as String,
      displayName: map['display_name'] as String? ?? map['metric_key'] as String,
      unit: map['unit'] as String? ?? '',
      baselineValue: (map['baseline_value'] as num).toDouble(),
      mean: (map['mean'] as num).toDouble(),
      median: (map['median'] as num).toDouble(),
      stdDev: (map['std_dev'] as num).toDouble(),
      minVal: (map['min_val'] as num).toDouble(),
      maxVal: (map['max_val'] as num).toDouble(),
      p10: (map['p10'] as num).toDouble(),
      p25: (map['p25'] as num).toDouble(),
      p75: (map['p75'] as num).toDouble(),
      p90: (map['p90'] as num).toDouble(),
      sampleCount: (map['sample_count'] as num).toInt(),
      calcPeriod: map['calc_period'] as String? ?? '',
      updatedAt: map['updated_at'] as String? ?? DateTime.now().toIso8601String(),
      extraStats: parsedExtra,
    );
  }

  PersonalBaseline copyWith({
    String? metricKey,
    String? displayName,
    String? unit,
    double? baselineValue,
    double? mean,
    double? median,
    double? stdDev,
    double? minVal,
    double? maxVal,
    double? p10,
    double? p25,
    double? p75,
    double? p90,
    int? sampleCount,
    String? calcPeriod,
    String? updatedAt,
    Map<String, dynamic>? extraStats,
  }) {
    return PersonalBaseline(
      metricKey: metricKey ?? this.metricKey,
      displayName: displayName ?? this.displayName,
      unit: unit ?? this.unit,
      baselineValue: baselineValue ?? this.baselineValue,
      mean: mean ?? this.mean,
      median: median ?? this.median,
      stdDev: stdDev ?? this.stdDev,
      minVal: minVal ?? this.minVal,
      maxVal: maxVal ?? this.maxVal,
      p10: p10 ?? this.p10,
      p25: p25 ?? this.p25,
      p75: p75 ?? this.p75,
      p90: p90 ?? this.p90,
      sampleCount: sampleCount ?? this.sampleCount,
      calcPeriod: calcPeriod ?? this.calcPeriod,
      updatedAt: updatedAt ?? this.updatedAt,
      extraStats: extraStats ?? this.extraStats,
    );
  }
}
