import 'package:flutter/material.dart';
import '../../../core/theme/nature_theme.dart';

/// Modello per una Zona Cardiaca
class HrZoneData {
  final int zoneIndex; // 1 to 5
  final String name;
  final String rangeLabel;
  final double percentage; // 0.0 to 100.0
  final int durationSeconds;
  final Color color;

  const HrZoneData({
    required this.zoneIndex,
    required this.name,
    required this.rangeLabel,
    required this.percentage,
    required this.durationSeconds,
    required this.color,
  });

  String get durationFormatted {
    final min = durationSeconds ~/ 60;
    final sec = durationSeconds % 60;
    if (min >= 60) {
      final hours = min ~/ 60;
      final remMin = min % 60;
      return '${hours}h ${remMin}m';
    }
    return '$min:${sec.toString().padLeft(2, '0')}';
  }
}

/// Grafico a barre orizzontali per la Distribuzione delle Zone Cardiache (Architettura NOOP, CHT-01..04)
/// Gestisce 4 stati espliciti: Caricamento, Vuoto, Dati parziali, Dati completi.
class HeartRateZonesChart extends StatelessWidget {
  final List<HrZoneData> zones;
  final int totalDurationSeconds;
  final bool isLoading;
  final bool isPartial;

  const HeartRateZonesChart({
    super.key,
    required this.zones,
    required this.totalDurationSeconds,
    this.isLoading = false,
    this.isPartial = false,
  });

  factory HeartRateZonesChart.fromPercentages({
    required double z1Pct,
    required double z2Pct,
    required double z3Pct,
    required double z4Pct,
    required double z5Pct,
    required int totalMinutes,
    bool isLoading = false,
    bool isPartial = false,
  }) {
    final totalSec = totalMinutes * 60;
    return HeartRateZonesChart(
      isLoading: isLoading,
      isPartial: isPartial,
      totalDurationSeconds: totalSec,
      zones: [
        HrZoneData(
          zoneIndex: 5,
          name: 'Zona 5',
          rangeLabel: '90 - 100%',
          percentage: z5Pct,
          durationSeconds: ((z5Pct / 100.0) * totalSec).round(),
          color: const Color(0xFFD9534F),
        ),
        HrZoneData(
          zoneIndex: 4,
          name: 'Zona 4',
          rangeLabel: '80 - 90%',
          percentage: z4Pct,
          durationSeconds: ((z4Pct / 100.0) * totalSec).round(),
          color: const Color(0xFFDF7B52),
        ),
        HrZoneData(
          zoneIndex: 3,
          name: 'Zona 3',
          rangeLabel: '70 - 80%',
          percentage: z3Pct,
          durationSeconds: ((z3Pct / 100.0) * totalSec).round(),
          color: const Color(0xFFD69E45),
        ),
        HrZoneData(
          zoneIndex: 2,
          name: 'Zona 2',
          rangeLabel: '60 - 70%',
          percentage: z2Pct,
          durationSeconds: ((z2Pct / 100.0) * totalSec).round(),
          color: const Color(0xFF38B27E),
        ),
        HrZoneData(
          zoneIndex: 1,
          name: 'Zona 1',
          rangeLabel: '50 - 60%',
          percentage: z1Pct,
          durationSeconds: ((z1Pct / 100.0) * totalSec).round(),
          color: const Color(0xFF439EB8),
        ),
      ],
    );
  }

  /// Crea il grafico dai dati aggregati restituiti da `getHrZoneDistribution` (CHT-02)
  factory HeartRateZonesChart.fromDistributionMap(
    Map<String, dynamic> map, {
    bool isLoading = false,
    bool isPartial = false,
  }) {
    final z1Pct = (map['z1_pct'] as num?)?.toDouble() ?? 0.0;
    final z2Pct = (map['z2_pct'] as num?)?.toDouble() ?? 0.0;
    final z3Pct = (map['z3_pct'] as num?)?.toDouble() ?? 0.0;
    final z4Pct = (map['z4_pct'] as num?)?.toDouble() ?? 0.0;
    final z5Pct = (map['z5_pct'] as num?)?.toDouble() ?? 0.0;

    final z1Sec = (map['z1_sec'] as num?)?.toInt() ?? 0;
    final z2Sec = (map['z2_sec'] as num?)?.toInt() ?? 0;
    final z3Sec = (map['z3_sec'] as num?)?.toInt() ?? 0;
    final z4Sec = (map['z4_sec'] as num?)?.toInt() ?? 0;
    final z5Sec = (map['z5_sec'] as num?)?.toInt() ?? 0;
    final totalSec = (map['total_sec'] as num?)?.toInt() ?? (z1Sec + z2Sec + z3Sec + z4Sec + z5Sec);

    return HeartRateZonesChart(
      isLoading: isLoading,
      isPartial: isPartial,
      totalDurationSeconds: totalSec,
      zones: [
        HrZoneData(
          zoneIndex: 5,
          name: 'Zona 5',
          rangeLabel: '90 - 100%',
          percentage: z5Pct,
          durationSeconds: z5Sec,
          color: const Color(0xFFD9534F),
        ),
        HrZoneData(
          zoneIndex: 4,
          name: 'Zona 4',
          rangeLabel: '80 - 90%',
          percentage: z4Pct,
          durationSeconds: z4Sec,
          color: const Color(0xFFDF7B52),
        ),
        HrZoneData(
          zoneIndex: 3,
          name: 'Zona 3',
          rangeLabel: '70 - 80%',
          percentage: z3Pct,
          durationSeconds: z3Sec,
          color: const Color(0xFFD69E45),
        ),
        HrZoneData(
          zoneIndex: 2,
          name: 'Zona 2',
          rangeLabel: '60 - 70%',
          percentage: z2Pct,
          durationSeconds: z2Sec,
          color: const Color(0xFF38B27E),
        ),
        HrZoneData(
          zoneIndex: 1,
          name: 'Zona 1',
          rangeLabel: '50 - 60%',
          percentage: z1Pct,
          durationSeconds: z1Sec,
          color: const Color(0xFF439EB8),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // 1. Stato: Caricamento (spinner discreto) (CHT-03)
    if (isLoading) {
      return Container(
        height: 220,
        alignment: Alignment.center,
        decoration: NatureTheme.organicCardDecoration(isDark: true),
        child: const SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(NatureColors.secondaryText),
          ),
        ),
      );
    }

    // 2. Stato: Vuoto / Nessun dato registrato (CHT-03)
    if (zones.isEmpty || totalDurationSeconds <= 0) {
      return Container(
        height: 120,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: NatureTheme.organicCardDecoration(isDark: true),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bar_chart_outlined, color: NatureColors.mutedText, size: 24),
            SizedBox(height: 8),
            Text(
              'Nessun dato registrato per questa finestra temporale',
              textAlign: TextAlign.center,
              style: TextStyle(color: NatureColors.secondaryText, fontSize: 12),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: NatureTheme.organicCardDecoration(isDark: true),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'DISTRIBUZIONE ZONE CARDIACHE',
                style: TextStyle(
                  color: NatureColors.secondaryText,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                ),
              ),
              if (isPartial)
                const Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, size: 12, color: NatureColors.amberWarm),
                    SizedBox(width: 4),
                    Text(
                      'Dati parziali',
                      style: TextStyle(color: NatureColors.amberWarm, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 14),

          // Barre orizzontali per ogni zona (dalla 5 alla 1)
          ...zones.map((zone) => _buildZoneRow(zone)),
        ],
      ),
    );
  }

  Widget _buildZoneRow(HrZoneData zone) {
    final widthFactor = (zone.percentage / 100.0).clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          // Nome Zona e Range
          SizedBox(
            width: 70,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  zone.name,
                  style: const TextStyle(
                    color: NatureColors.primaryText,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  zone.rangeLabel,
                  style: const TextStyle(
                    color: NatureColors.mutedText,
                    fontSize: 9,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Barra Proporzionale con animazione morbida
          Expanded(
            child: Stack(
              children: [
                Container(
                  height: 10,
                  decoration: BoxDecoration(
                    color: NatureColors.borderSubtle,
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
                if (widthFactor > 0)
                  FractionallySizedBox(
                    widthFactor: widthFactor,
                    child: Container(
                      height: 10,
                      decoration: BoxDecoration(
                        color: zone.color,
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),

          // Percentuale e Durata
          SizedBox(
            width: 80,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${zone.percentage.toStringAsFixed(0)}%',
                  style: TextStyle(
                    color: zone.percentage > 0 ? NatureColors.primaryText : NatureColors.mutedText,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                Text(
                  zone.durationFormatted,
                  style: const TextStyle(
                    color: NatureColors.secondaryText,
                    fontSize: 9.5,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
