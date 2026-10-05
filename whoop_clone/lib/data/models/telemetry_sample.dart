import 'dart:math' as math;
import 'package:flutter/foundation.dart';

/// Sorgente di acquisizione del campione telemetrico
enum TelemetrySource {
  hrService2a37,
  strapRealtime,
  strapHistorical,
}

/// Campione telemetrico tipizzato unificato (Fase 3: PRO-04)
/// Tutti i campi fisiologici sono nullable. Nessun valore fittizio è ammesso.
@immutable
class TelemetrySample {
  final DateTime timestamp;
  final int? hr;
  final List<double> rrIntervalsMs;
  final double? accelX; // In unità g
  final double? accelY; // In unità g
  final double? accelZ; // In unità g
  final double? skinTempCelsius;
  final double? spo2Ratio;
  final double? respiratoryRate;
  final int? sequenceNumber;
  final TelemetrySource source;

  const TelemetrySample({
    required this.timestamp,
    this.hr,
    this.rrIntervalsMs = const [],
    this.accelX,
    this.accelY,
    this.accelZ,
    this.skinTempCelsius,
    this.spo2Ratio,
    this.respiratoryRate,
    this.sequenceNumber,
    this.source = TelemetrySource.strapRealtime,
  });

  /// ENMO = max(0.0, |magnitude| - 1.0 g)
  /// Calcolato rigorosamente sui tre assi dell'accelerometro (in g).
  /// Se uno dei tre assi manca, restituisce null. Nessun floor fittizio 0.002 (PRO-04, DAT-06).
  double? get enmo {
    if (accelX == null || accelY == null || accelZ == null) return null;
    final mag = math.sqrt(accelX! * accelX! + accelY! * accelY! + accelZ! * accelZ!);
    return math.max(0.0, mag - 1.0);
  }

  /// Calcola rMSSD sui veri intervalli RR forniti (in ms)
  double? get rmssdFromRr {
    if (rrIntervalsMs.length < 2) return null;
    double sumSqDiff = 0.0;
    int count = 0;
    for (int i = 0; i < rrIntervalsMs.length - 1; i++) {
      final diff = rrIntervalsMs[i + 1] - rrIntervalsMs[i];
      sumSqDiff += diff * diff;
      count++;
    }
    return count > 0 ? math.sqrt(sumSqDiff / count) : null;
  }

  Map<String, dynamic> toMap() => {
        'timestamp': timestamp.toIso8601String(),
        'hr': hr,
        'rr_intervals_ms': rrIntervalsMs,
        'accel_x': accelX,
        'accel_y': accelY,
        'accel_z': accelZ,
        'enmo': enmo,
        'skin_temp_celsius': skinTempCelsius,
        'spo2_ratio': spo2Ratio,
        'respiratory_rate': respiratoryRate,
        'sequence_number': sequenceNumber,
        'source': source.name,
      };
}
