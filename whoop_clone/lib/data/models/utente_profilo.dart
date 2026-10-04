import 'package:flutter/foundation.dart';

/// Modello per la tabella `utente_profilo`
@immutable
class UtenteProfilo {
  final int id;
  final String nome;
  final int eta;
  final int hrMax;
  final int hrRestBaseline;
  final double hrvBaselineMean;
  final double hrvBaselineStd;
  final double rhrBaselineMean;
  final double rhrBaselineStd;
  final int sleepBaselineMin;
  final bool isBootstrapCompleted;
  final String? bootstrapTimestamp;
  final String? bootstrapVersion;
  final String baselineSource;
  final int baselineSampleCount;
  final String? baselineCalcPeriod;
  final String? pairedDeviceMac;
  final String? pairedDeviceName;

  const UtenteProfilo({
    this.id = 1,
    required this.nome,
    required this.eta,
    required this.hrMax,
    required this.hrRestBaseline,
    required this.hrvBaselineMean,
    required this.hrvBaselineStd,
    required this.rhrBaselineMean,
    required this.rhrBaselineStd,
    required this.sleepBaselineMin,
    this.isBootstrapCompleted = false,
    this.bootstrapTimestamp,
    this.bootstrapVersion,
    this.baselineSource = 'INITIAL_PROFILE',
    this.baselineSampleCount = 0,
    this.baselineCalcPeriod,
    this.pairedDeviceMac,
    this.pairedDeviceName,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nome': nome,
      'eta': eta,
      'hr_max': hrMax,
      'hr_rest_baseline': hrRestBaseline,
      'hrv_baseline_mean': hrvBaselineMean,
      'hrv_baseline_std': hrvBaselineStd,
      'rhr_baseline_mean': rhrBaselineMean,
      'rhr_baseline_std': rhrBaselineStd,
      'sleep_baseline_min': sleepBaselineMin,
      'is_bootstrap_completed': isBootstrapCompleted ? 1 : 0,
      'bootstrap_timestamp': bootstrapTimestamp,
      'bootstrap_version': bootstrapVersion,
      'baseline_source': baselineSource,
      'baseline_sample_count': baselineSampleCount,
      'baseline_calc_period': baselineCalcPeriod,
      'paired_device_mac': pairedDeviceMac,
      'paired_device_name': pairedDeviceName,
    };
  }

  factory UtenteProfilo.fromMap(Map<String, dynamic> map) {
    return UtenteProfilo(
      id: (map['id'] as num?)?.toInt() ?? 1,
      nome: map['nome'] as String? ?? 'Utente WHOOP',
      eta: (map['eta'] as num?)?.toInt() ?? 30,
      hrMax: (map['hr_max'] as num?)?.toInt() ?? 190,
      hrRestBaseline: (map['hr_rest_baseline'] as num?)?.toInt() ?? 55,
      hrvBaselineMean: (map['hrv_baseline_mean'] as num?)?.toDouble() ?? 65.0,
      hrvBaselineStd: (map['hrv_baseline_std'] as num?)?.toDouble() ?? 15.0,
      rhrBaselineMean: (map['rhr_baseline_mean'] as num?)?.toDouble() ?? 55.0,
      rhrBaselineStd: (map['rhr_baseline_std'] as num?)?.toDouble() ?? 3.5,
      sleepBaselineMin: (map['sleep_baseline_min'] as num?)?.toInt() ?? 480,
      isBootstrapCompleted: ((map['is_bootstrap_completed'] as num?)?.toInt() ?? 0) == 1,
      bootstrapTimestamp: map['bootstrap_timestamp'] as String?,
      bootstrapVersion: map['bootstrap_version'] as String?,
      baselineSource: map['baseline_source'] as String? ?? 'INITIAL_PROFILE',
      baselineSampleCount: (map['baseline_sample_count'] as num?)?.toInt() ?? 0,
      baselineCalcPeriod: map['baseline_calc_period'] as String?,
      pairedDeviceMac: map['paired_device_mac'] as String?,
      pairedDeviceName: map['paired_device_name'] as String?,
    );
  }

  UtenteProfilo copyWith({
    int? id,
    String? nome,
    int? eta,
    int? hrMax,
    int? hrRestBaseline,
    double? hrvBaselineMean,
    double? hrvBaselineStd,
    double? rhrBaselineMean,
    double? rhrBaselineStd,
    int? sleepBaselineMin,
    bool? isBootstrapCompleted,
    String? bootstrapTimestamp,
    String? bootstrapVersion,
    String? baselineSource,
    int? baselineSampleCount,
    String? baselineCalcPeriod,
    String? pairedDeviceMac,
    String? pairedDeviceName,
  }) {
    return UtenteProfilo(
      id: id ?? this.id,
      nome: nome ?? this.nome,
      eta: eta ?? this.eta,
      hrMax: hrMax ?? this.hrMax,
      hrRestBaseline: hrRestBaseline ?? this.hrRestBaseline,
      hrvBaselineMean: hrvBaselineMean ?? this.hrvBaselineMean,
      hrvBaselineStd: hrvBaselineStd ?? this.hrvBaselineStd,
      rhrBaselineMean: rhrBaselineMean ?? this.rhrBaselineMean,
      rhrBaselineStd: rhrBaselineStd ?? this.rhrBaselineStd,
      sleepBaselineMin: sleepBaselineMin ?? this.sleepBaselineMin,
      isBootstrapCompleted: isBootstrapCompleted ?? this.isBootstrapCompleted,
      bootstrapTimestamp: bootstrapTimestamp ?? this.bootstrapTimestamp,
      bootstrapVersion: bootstrapVersion ?? this.bootstrapVersion,
      baselineSource: baselineSource ?? this.baselineSource,
      baselineSampleCount: baselineSampleCount ?? this.baselineSampleCount,
      baselineCalcPeriod: baselineCalcPeriod ?? this.baselineCalcPeriod,
      pairedDeviceMac: pairedDeviceMac ?? this.pairedDeviceMac,
      pairedDeviceName: pairedDeviceName ?? this.pairedDeviceName,
    );
  }
}
