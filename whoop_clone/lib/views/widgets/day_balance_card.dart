import 'package:flutter/material.dart';
import '../../core/constants/whoop_theme.dart';

/// Widget "Il bilancio della tua giornata" (Sezione 1 Roadmap)
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
    final recoveryColor = WhoopTheme.getRecoveryColor(recoveryPct);
    final isOptimal = currentStrain >= targetStrainMin && currentStrain <= targetStrainMax;
    final isUnder = currentStrain < targetStrainMin;

    String statusText;
    Color statusColor;
    if (isOptimal) {
      statusText = 'OTTIMALE (IN TARGET)';
      statusColor = WhoopTheme.recoveryGreen;
    } else if (isUnder) {
      statusText = 'STIMOLO INCOMPLETO';
      statusColor = WhoopTheme.recoveryYellow;
    } else {
      statusText = 'SUPERATO IL TARGET';
      statusColor = WhoopTheme.strainHigh;
    }

    return Container(
      decoration: WhoopTheme.officialCardDecoration(tint: WhoopTheme.strainBlue),
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
                    Icon(Icons.balance, color: WhoopTheme.strainBlue, size: 18),
                    SizedBox(width: 8),
                    Text(
                      'IL BILANCIO DELLA TUA GIORNATA',
                      style: TextStyle(
                        color: WhoopTheme.textSecondary,
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
                        style: TextStyle(color: WhoopTheme.textMuted, fontSize: 11),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        currentStrain.toStringAsFixed(1),
                        style: const TextStyle(
                          color: WhoopTheme.strainBlue,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(width: 1, height: 32, color: WhoopTheme.cardBorder),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Target Consigliato',
                          style: TextStyle(color: WhoopTheme.textMuted, fontSize: 11),
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
                  height: 8,
                  decoration: BoxDecoration(
                    color: WhoopTheme.cardBorder,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: (currentStrain / 21.0).clamp(0.0, 1.0),
                  child: Container(
                    height: 8,
                    decoration: BoxDecoration(
                      color: WhoopTheme.strainBlue,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Con un Recupero del ${recoveryPct.toInt()}%, il tuo organismo può sostenere uno sforzo fino a $targetStrainMax senza compromettere la rigenerazione di domani.',
              style: const TextStyle(color: WhoopTheme.textSecondary, fontSize: 11, height: 1.3),
            ),
          ],
        ),
      ),
    );
  }
}

