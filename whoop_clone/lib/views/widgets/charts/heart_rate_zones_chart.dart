import 'package:flutter/material.dart';
import '../../../core/constants/whoop_theme.dart';

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
          color: const Color(0xFFFF3B30), // Rosso picco
        ),
        HrZoneData(
          zoneIndex: 4,
          name: 'Zona 4',
          rangeLabel: '80 - 90%',
          percentage: z4Pct,
          durationSeconds: ((z4Pct / 100.0) * totalSec).round(),
          color: const Color(0xFFFF9500), // Arancione soglia
        ),
        HrZoneData(
          zoneIndex: 3,
          name: 'Zona 3',
          rangeLabel: '70 - 80%',
          percentage: z3Pct,
          durationSeconds: ((z3Pct / 100.0) * totalSec).round(),
          color: const Color(0xFF34C759), // Verde aerobico
        ),
        HrZoneData(
          zoneIndex: 2,
          name: 'Zona 2',
          rangeLabel: '60 - 70%',
          percentage: z2Pct,
          durationSeconds: ((z2Pct / 100.0) * totalSec).round(),
          color: const Color(0xFF007AFF), // Blu fondo
        ),
        HrZoneData(
          zoneIndex: 1,
          name: 'Zona 1',
          rangeLabel: '50 - 60%',
          percentage: z1Pct,
          durationSeconds: ((z1Pct / 100.0) * totalSec).round(),
          color: const Color(0xFF8E8E93), // Grigio recupero
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
    final totalSec = (map['total_seconds'] as num?)?.toInt() ??
        ((map['total_samples'] as num?)?.toInt() ?? 0);

    return HeartRateZonesChart.fromPercentages(
      z1Pct: z1Pct,
      z2Pct: z2Pct,
      z3Pct: z3Pct,
      z4Pct: z4Pct,
      z5Pct: z5Pct,
      totalMinutes: (totalSec / 60.0).round(),
      isLoading: isLoading,
      isPartial: isPartial,
    );
  }

  @override
  Widget build(BuildContext context) {
    // 1. Stato: Caricamento (spinner discreto) (CHT-03)
    if (isLoading) {
      return Container(
        height: 220,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFF141920),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: WhoopTheme.cardBorder),
        ),
        child: const SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(WhoopTheme.textSecondary),
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
        decoration: BoxDecoration(
          color: const Color(0xFF141920),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: WhoopTheme.cardBorder),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bar_chart_outlined, color: WhoopTheme.textMuted, size: 24),
            SizedBox(height: 8),
            Text(
              'Nessun dato registrato per questa finestra temporale',
              textAlign: TextAlign.center,
              style: TextStyle(color: WhoopTheme.textMuted, fontSize: 12),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF141920),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: WhoopTheme.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'DISTRIBUZIONE ZONE CARDIACHE',
                style: TextStyle(
                  color: WhoopTheme.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.1,
                ),
              ),
              if (isPartial)
                const Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, size: 12, color: Color(0xFFFF9F0A)),
                    SizedBox(width: 4),
                    Text(
                      'Dati parziali',
                      style: TextStyle(color: Color(0xFFFF9F0A), fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 14),

          ...zones.map((zone) => _buildZoneBar(zone)),
        ],
      ),
    );
  }

  Widget _buildZoneBar(HrZoneData zone) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(color: zone.color, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    zone.name,
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '(${zone.rangeLabel})',
                    style: const TextStyle(color: WhoopTheme.textMuted, fontSize: 10),
                  ),
                ],
              ),
              Row(
                children: [
                  Text(
                    '${zone.percentage.toStringAsFixed(0)}%',
                    style: TextStyle(color: zone.color, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    zone.durationFormatted,
                    style: const TextStyle(color: WhoopTheme.textSecondary, fontSize: 11),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (zone.percentage / 100.0).clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: const Color(0xFF1F2833),
              valueColor: AlwaysStoppedAnimation<Color>(zone.color),
            ),
          ),
        ],
      ),
    );
  }
}
