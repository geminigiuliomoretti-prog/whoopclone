import 'package:flutter/material.dart';
import 'nature/nature_tri_ring_dial.dart';

/// Componente 3 Circonferenze (Recupero • Sonno • Sforzo)
/// Integrato con la nuova visual identity organica e naturale NatureTriRingDial.
class TriRingDial extends StatelessWidget {
  final double strainScore; // 0.0 - 21.0
  final double recoveryPct; // 0 - 100%
  final double sleepPct;    // 0 - 100%
  final int liveBpm;
  final int calories;
  final VoidCallback? onTapStrain;
  final VoidCallback? onTapRecovery;
  final VoidCallback? onTapSleep;

  const TriRingDial({
    super.key,
    required this.strainScore,
    required this.recoveryPct,
    required this.sleepPct,
    required this.liveBpm,
    required this.calories,
    this.onTapStrain,
    this.onTapRecovery,
    this.onTapSleep,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return NatureTriRingDial(
      strainScore: strainScore,
      recoveryPct: recoveryPct,
      sleepPct: sleepPct,
      liveBpm: liveBpm,
      calories: calories,
      isDark: isDark,
      onTapRecovery: onTapRecovery,
      onTapSleep: onTapSleep,
      onTapStrain: onTapStrain,
    );
  }
}
