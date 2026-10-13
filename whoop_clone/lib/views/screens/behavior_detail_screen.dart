import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/whoop_theme.dart';
import '../../core/theme/nature_theme.dart';
import '../../viewmodels/whoop_viewmodel.dart';

/// Schermata "DETTAGLI DEL COMPORTAMENTO" (Dati Reali da WhoopViewModel & SQLite)
class BehaviorDetailScreen extends StatelessWidget {
  final String habitName;
  final double impactPercentage;
  final bool isPositive;

  const BehaviorDetailScreen({
    super.key,
    this.habitName = 'Abitudine',
    this.impactPercentage = 0.0,
    this.isPositive = false,
  });

  static void show(
    BuildContext context, {
    String habitName = 'Abitudine',
    double impactPct = 0.0,
    bool isPositive = false,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BehaviorDetailScreen(
          habitName: habitName,
          impactPercentage: impactPct,
          isPositive: isPositive,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<WhoopViewModel>(
      builder: (context, viewModel, child) {
        final impact = viewModel.getHabitImpact(habitName);
        final recImpact = impact.recoveryImpactPct;
        final sleepImpact = impact.sleepImpactPct;
        final isRecPos = recImpact >= 0;
        final statusColor = isRecPos ? WhoopTheme.recoveryGreen : WhoopTheme.recoveryYellow;
        final statusText = isRecPos ? 'Positivo' : 'Negativo';

        return Scaffold(
          backgroundColor: WhoopTheme.background,
          appBar: AppBar(
            backgroundColor: WhoopTheme.background,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.chevron_left, color: Colors.white, size: 28),
              onPressed: () => Navigator.pop(context),
            ),
            title: const Text(
              'DETTAGLI DEL COMPORTAMENTO',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.1,
              ),
            ),
            centerTitle: true,
          ),
          body: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Titolo Abitudine
                Text(
                  habitName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 16),

                // Card IMPATTO SUL RECUPERO
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: WhoopTheme.officialCardDecoration(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'IMPATTO SUL RECUPERO',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.0,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: statusColor.withValues(alpha: 0.5)),
                            ),
                            child: Text(
                              statusText,
                              style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: (recImpact.abs() / 15.0).clamp(0.05, 1.0),
                                backgroundColor: WhoopTheme.cardBorder,
                                valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                                minHeight: 8,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Text(
                            '${recImpact > 0 ? "+" : ""}${recImpact.toStringAsFixed(1)}%',
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // Impatto sul Sonno
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Impatto sulla Performance Sonno',
                            style: TextStyle(color: WhoopTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                          Text(
                            '${sleepImpact > 0 ? "+" : ""}${sleepImpact.toStringAsFixed(1)}%',
                            style: TextStyle(
                              color: sleepImpact >= 0 ? WhoopTheme.recoveryGreen : WhoopTheme.recoveryYellow,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Statistiche Risposte Reali
                const Text(
                  'STATISTICHE RISPOSTE (SQLITE)',
                  style: TextStyle(
                    color: WhoopTheme.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 10),

                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: WhoopTheme.officialCardDecoration(),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildStatBox('Risposte Sì', '${impact.countYes}', WhoopTheme.strainBlue),
                          _buildStatBox('Risposte No', '${impact.countNo}', WhoopTheme.textSecondary),
                          _buildStatBox('Totale Risposte', '${impact.countYes + impact.countNo}', WhoopTheme.recoveryGreen),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Divider(color: WhoopTheme.cardBorder),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(
                            impact.hasStatisticalValidity ? Icons.check_circle_outline : Icons.info_outline,
                            size: 16,
                            color: impact.hasStatisticalValidity ? WhoopTheme.recoveryGreen : WhoopTheme.textMuted,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              impact.statusMessage,
                              style: TextStyle(
                                color: impact.hasStatisticalValidity ? NatureColors.textDarkPrimary : WhoopTheme.textMuted,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                height: 1.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 30),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatBox(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color: WhoopTheme.textMuted,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
