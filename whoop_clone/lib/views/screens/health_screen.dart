import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/whoop_theme.dart';
import '../../core/theme/nature_theme.dart';
import '../../data/biometrics/health_vitals_engine.dart';
import '../../viewmodels/whoop_viewmodel.dart';
import '../widgets/live_heart_rate_card.dart';
import 'stress_monitor_screen.dart';
import 'health_vitals_detail_screen.dart';

/// Schermata TAB SALUTE WHOOP 5.0 (Rispecchia al 100% "Salute - Tab Salute Frequenza Cardiaca e 5 Parametri Vitali.jpeg")
class HealthScreen extends StatefulWidget {
  const HealthScreen({super.key});

  @override
  State<HealthScreen> createState() => _HealthScreenState();
}

class _HealthScreenState extends State<HealthScreen> {
  @override
  Widget build(BuildContext context) {
    final viewModel = Provider.of<WhoopViewModel>(context);
    final liveBpm = viewModel.liveBpm;
    final vitals = viewModel.vitalEvaluations;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        title: Text(
          'SALUTE',
          style: WhoopTheme.cardTitleStyle(
            fontSize: 14,
            color: WhoopTheme.textPrimary,
          ).copyWith(fontWeight: FontWeight.w800),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. FREQUENZA CARDIACA (Live BPM Box con griglia, onda e 5 trattini zona)
            LiveHeartRateCard(liveBpm: liveBpm),

            const SizedBox(height: 16),

            // 2. MONITORAGGIO DELLA SALUTE (5 Vitals Column con divisori + pill scuro con spunta)
            _buildHealthVitalsCard(context, vitals),

            const SizedBox(height: 16),

            // 3. MONITORAGGIO DELLO STRESS (Picco di stress + mini wave graph)
            _buildStressSummaryCard(context, viewModel),

            const SizedBox(height: 80), // Padding per floating bar
          ],
        ),
      ),
    );
  }

  // Card 2: Monitoraggio della Salute
  Widget _buildHealthVitalsCard(BuildContext context, List<VitalEvaluation> vitals) {
    final inRangeCount = vitals.where((v) => v.status == VitalStatus.inRange).length;
    final calibrationCount = vitals.where((v) => v.status == VitalStatus.calibration).length;
    final noDataCount = vitals.where((v) => v.status == VitalStatus.noData).length;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    String pillText;
    Color pillColor;
    IconData pillIcon;

    if (noDataCount == vitals.length) {
      pillText = 'Dati non disponibili';
      pillColor = WhoopTheme.textMuted;
      pillIcon = Icons.remove_circle_outline;
    } else if (calibrationCount > 0) {
      final samples = vitals.first.sampleCount;
      pillText = 'Calibrazione in corso ($samples/7 giorni)';
      pillColor = WhoopTheme.strainBlue;
      pillIcon = Icons.tune;
    } else if (inRangeCount == (vitals.length - noDataCount) && inRangeCount > 0) {
      pillText = '$inRangeCount/${vitals.length - noDataCount} parametri nella norma';
      pillColor = WhoopTheme.recoveryGreen;
      pillIcon = Icons.check;
    } else {
      final validCount = vitals.length - noDataCount;
      pillText = validCount > 0 ? '$inRangeCount/$validCount parametri nella norma' : 'Dati non disponibili';
      pillColor = validCount > 0 ? WhoopTheme.recoveryYellow : WhoopTheme.textMuted;
      pillIcon = validCount > 0 ? Icons.warning_amber_rounded : Icons.remove_circle_outline;
    }

    VitalStatus getStatus(String key, int fallbackIdx) {
      final found = vitals.where((v) => v.key == key).firstOrNull;
      if (found != null) return found.status;
      if (vitals.length > fallbackIdx) return vitals[fallbackIdx].status;
      return VitalStatus.noData;
    }

    return GestureDetector(
      onTap: () => HealthVitalsDetailScreen.show(context),
      child: Container(
        padding: const EdgeInsets.all(18.0),
        decoration: WhoopTheme.officialCardDecoration(isDark: isDark),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Text(
                  'MONITORAGGIO DELLA SALUTE',
                  style: TextStyle(
                    color: WhoopTheme.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ),
                Icon(Icons.chevron_right, color: WhoopTheme.textSecondary, size: 20),
              ],
            ),
            const SizedBox(height: 20),

            // 5 Colonne con divisori verticali sottili
            IntrinsicHeight(
              child: Row(
                children: [
                  Expanded(child: _buildVitalIconColumn('FR', Icons.air, getStatus('resp_rate', 0), isDark)),
                  _buildVerticalDivider(isDark),
                  Expanded(child: _buildVitalIconColumn('SPO₂', Icons.water_drop_outlined, getStatus('spo2', 1), isDark)),
                  _buildVerticalDivider(isDark),
                  Expanded(child: _buildVitalIconColumn('FCR', Icons.favorite_border, getStatus('fcr', 2), isDark)),
                  _buildVerticalDivider(isDark),
                  Expanded(child: _buildVitalIconColumn('VFC', Icons.show_chart, getStatus('vfc', 3), isDark)),
                  _buildVerticalDivider(isDark),
                  Expanded(child: _buildVitalIconColumn('TEMP', Icons.thermostat, getStatus('temp', 4), isDark)),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Pill Contenitore: Adattivo per tema, spunta verde quadrata e testo leggibile
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF141D22) : NatureColors.creamLight,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isDark ? const Color(0xFF222D35) : NatureColors.sandBorderSubtle,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: pillColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Icon(pillIcon, color: Colors.white, size: 14),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      pillText,
                      style: TextStyle(
                        color: isDark ? Colors.white : NatureColors.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVerticalDivider(bool isDark) {
    return Container(
      width: 1,
      margin: const EdgeInsets.symmetric(vertical: 4),
      color: isDark ? const Color(0xFF202A33) : NatureColors.sandBorderSubtle,
    );
  }

  Widget _buildVitalIconColumn(String label, IconData icon, VitalStatus status, bool isDark) {
    Color bgBadge;
    Color fgBadge;
    IconData statusIcon;

    switch (status) {
      case VitalStatus.inRange:
        bgBadge = !isDark ? NatureColors.sageBackground : WhoopTheme.recoveryGreen;
        fgBadge = !isDark ? NatureColors.sageDark : Colors.black;
        statusIcon = Icons.check;
        break;
      case VitalStatus.outOfRange:
        bgBadge = !isDark ? NatureColors.terracottaBackground : WhoopTheme.recoveryRed;
        fgBadge = !isDark ? NatureColors.terracotta : Colors.white;
        statusIcon = Icons.priority_high;
        break;
      case VitalStatus.calibration:
        bgBadge = !isDark ? NatureColors.tealBackground : WhoopTheme.strainBlue;
        fgBadge = !isDark ? NatureColors.tealDark : Colors.black;
        statusIcon = Icons.tune;
        break;
      case VitalStatus.noData:
        bgBadge = !isDark ? NatureColors.creamLight : NatureColors.darkSurfaceHighlight;
        fgBadge = !isDark ? NatureColors.textLightMuted : WhoopTheme.textMuted;
        statusIcon = Icons.remove;
        break;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: WhoopTheme.textSecondary, size: 20),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(
            color: WhoopTheme.textPrimary,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: bgBadge,
            borderRadius: BorderRadius.circular(6),
            border: !isDark ? Border.all(color: fgBadge.withOpacity(0.25), width: 0.8) : null,
          ),
          child: Icon(statusIcon, color: fgBadge, size: 13),
        ),
      ],
    );
  }

  // Card 3: Monitoraggio dello Stress
  Widget _buildStressSummaryCard(BuildContext context, WhoopViewModel viewModel) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final stressScore = viewModel.liveStressIndex > 0
        ? viewModel.liveStressIndex
        : (viewModel.ultimoCiclo?.vfcMs != null ? (viewModel.ultimoCiclo!.vfcMs! < 50 ? 1.8 : 0.8) : 0.8);

    return GestureDetector(
      onTap: () => StressMonitorScreen.show(context, stressScore: stressScore),
      child: Container(
        padding: const EdgeInsets.all(18.0),
        decoration: WhoopTheme.officialCardDecoration(isDark: isDark),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Text(
                  'MONITORAGGIO DELLO STRESS',
                  style: TextStyle(
                    color: WhoopTheme.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ),
                Icon(Icons.chevron_right, color: WhoopTheme.textSecondary, size: 20),
              ],
            ),
            const SizedBox(height: 14),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'PUNTEGGIO ATTUALE',
                      style: TextStyle(
                        color: WhoopTheme.textSecondary,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      viewModel.currentStressScore > 0
                          ? viewModel.currentStressScore.toStringAsFixed(1).replaceAll('.', ',')
                          : '--',
                      style: const TextStyle(
                        color: WhoopTheme.textPrimary,
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
                Builder(
                  builder: (context) {
                    final s = viewModel.currentStressScore;
                    String categoryText = 'In attesa';
                    Color categoryColor = WhoopTheme.textMuted;
                    Color categoryBg = WhoopTheme.cardBorder;

                    if (s > 0) {
                      if (s < 1.0) {
                        categoryText = 'Basso';
                        categoryColor = NatureColors.teal;
                        categoryBg = NatureColors.teal.withValues(alpha: 0.18);
                      } else if (s < 2.0) {
                        categoryText = 'Moderato';
                        categoryColor = NatureColors.amberWarm;
                        categoryBg = NatureColors.amberWarm.withValues(alpha: 0.18);
                      } else {
                        categoryText = 'Elevato';
                        categoryColor = NatureColors.coralLight;
                        categoryBg = NatureColors.coralLight.withValues(alpha: 0.18);
                      }
                    }

                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: categoryBg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: categoryColor.withValues(alpha: 0.4)),
                      ),
                      child: Text(
                        categoryText,
                        style: TextStyle(
                          color: categoryColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
