import 'package:flutter/material.dart';
import '../../core/theme/nature_theme.dart';

/// Widget "Il bilancio della tua giornata"
/// Confronta il Day Strain accumulato con il Target Strain consigliato dal Recovery Score
class DayBalanceCard extends StatelessWidget {
  final double currentStrain;
  final double targetStrainMin;
  final double targetStrainMax;
  final double recoveryPct;

  const DayBalanceCard({
    super.key,
    required this.currentStrain,
    required this.targetStrainMin,
    required this.targetStrainMax,
    required this.recoveryPct,
  });

  @override
  Widget build(BuildContext context) {
    final recoveryColor = NatureTheme.getRecoveryColor(recoveryPct);
    final isOptimal = currentStrain >= targetStrainMin && currentStrain <= targetStrainMax;
    final isUnder = currentStrain < targetStrainMin;

    String statusText;
    Color statusColor;
    if (isOptimal) {
      statusText = 'OTTIMALE (IN TARGET)';
      statusColor = NatureColors.recoveryAccent;
    } else if (isUnder) {
      statusText = 'STIMOLO INCOMPLETO';
      statusColor = NatureColors.amberWarm;
    } else {
      statusText = 'SUPERATO IL TARGET';
      statusColor = NatureColors.terracotta;
    }

    return Container(
      decoration: NatureTheme.organicCardDecoration(
        isDark: true,
        accentTint: NatureColors.strainAccent.withValues(alpha: 0.08),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.balance_rounded, color: NatureColors.tealLight, size: 18),
                    SizedBox(width: 8),
                    Text(
                      'IL BILANCIO DELLA TUA GIORNATA',
                      style: TextStyle(
                        color: NatureColors.textDarkMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: statusColor.withOpacity(0.5)),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Sforzo Attuale',
                        style: TextStyle(color: NatureColors.textDarkMuted, fontSize: 11),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        currentStrain.toStringAsFixed(1),
                        style: const TextStyle(
                          color: NatureColors.coralLight,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(width: 1, height: 32, color: NatureColors.border),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Target Consigliato',
                          style: TextStyle(color: NatureColors.textDarkMuted, fontSize: 11),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${targetStrainMin.toStringAsFixed(1)} - ${targetStrainMax.toStringAsFixed(1)}',
                          style: TextStyle(
                            color: recoveryColor,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Progress Bar Visualizer
            Stack(
              children: [
                Container(
                  height: 6,
                  decoration: BoxDecoration(
                    color: NatureColors.border,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: (currentStrain / 21.0).clamp(0.0, 1.0),
                  child: Container(
                    height: 6,
                    decoration: BoxDecoration(
                      color: NatureColors.terracotta,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Con un Recupero del ${recoveryPct.toInt()}%, il tuo organismo può sostenere uno sforzo fino a $targetStrainMax senza compromettere la rigenerazione di domani.',
              style: const TextStyle(color: NatureColors.textDarkSecondary, fontSize: 11, height: 1.3),
            ),
          ],
        ),
      ),
    );
  }
}

