import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/whoop_theme.dart';
import '../../viewmodels/whoop_viewmodel.dart';
import '../screens/customizable_dashboard_screen.dart';
import '../screens/trends_screen.dart';

/// Grid Metriche Personalizzabili nella Home
/// Visualizza reattivamente le tessere abilitate in WhoopViewModel leggendo esclusivamente da SQLite.
/// Ogni tessera è CLICCABILE ed apre direttamente le Tendenze Storiche col parametro selezionato.
class CustomizableDashboardGrid extends StatelessWidget {
  final double? hrvMs;
  final int? fcrBpm;
  final int? steps;
  final double? vo2Max;
  final int? calories;

  const CustomizableDashboardGrid({
    super.key,
    this.hrvMs,
    this.fcrBpm,
    this.steps,
    this.vo2Max,
    this.calories,
  });

  @override
  Widget build(BuildContext context) {
    final viewModel = Provider.of<WhoopViewModel>(context);
    final enabledKeys = viewModel.enabledTileKeys;
    final ciclo = viewModel.ultimoCiclo;
    final sonno = viewModel.sonnoList.isNotEmpty ? viewModel.sonnoList.first : null;
    final profile = viewModel.userProfile;

    final effectiveHrv = hrvMs ?? ciclo?.vfcMs;
    final effectiveRhr = fcrBpm ?? ciclo?.fcrBpm;
    final effectiveCal = calories ?? ciclo?.energiaBruciataCal;
    final effectiveRecovery = ciclo?.punteggioRecuperoPct;
    final effectiveResp = ciclo?.frequenzaRespiratoriaRpm;
    final effectiveTemp = ciclo?.tempCutaneaC;
    final effectiveSpo2 = ciclo?.spo2Pct;
    final effectiveSleepNeed = ciclo?.sonnoRichiestoMin ?? viewModel.currentSleepNeedMinutes;
    final effectiveDeepSleep = sonno?.sonnoProfondoMin;
    final effectiveRemSleep = sonno?.sonnoRemMin;
    final effectiveSleepEff = sonno?.efficienzaPct;

    final Map<String, Map<String, dynamic>> allTiles = {
      'vfc': {
        'title': 'Variabilità FC (VFC)',
        'value': effectiveHrv != null ? '${effectiveHrv.toStringAsFixed(0)} ms' : '-- ms',
        'subtitle': effectiveHrv != null ? (effectiveHrv >= profile.hrvBaselineMean ? 'Superiore alla baseline' : 'Inferiore alla baseline') : 'In attesa di dati',
        'icon': Icons.show_chart,
        'accentColor': effectiveHrv != null ? (effectiveHrv >= profile.hrvBaselineMean ? WhoopTheme.recoveryGreen : WhoopTheme.recoveryYellow) : WhoopTheme.textSecondary,
      },
      'fcr': {
        'title': 'FC a Riposo (FCR)',
        'value': effectiveRhr != null ? '$effectiveRhr bpm' : '-- bpm',
        'subtitle': effectiveRhr != null ? 'Baseline: ${profile.hrRestBaseline} bpm' : 'In attesa di dati',
        'icon': Icons.favorite_border,
        'accentColor': effectiveRhr != null ? (effectiveRhr <= profile.hrRestBaseline ? WhoopTheme.recoveryGreen : WhoopTheme.recoveryYellow) : WhoopTheme.textSecondary,
      },
      'steps': {
        'title': 'Passi Giornalieri',
        'value': steps != null ? '$steps' : '--',
        'subtitle': steps != null ? 'Pedometer' : 'Dispositivo privo di contapassi',
        'icon': Icons.directions_walk,
        'accentColor': WhoopTheme.strainBlue,
      },
      'zone_fc_low': {
        'title': 'Zone FC 1–3',
        'value': ciclo != null ? 'Tempo Aerobico' : '--',
        'subtitle': 'Zone 1-3 cardio',
        'icon': Icons.donut_large,
        'accentColor': WhoopTheme.strainBlue,
      },
      'zone_fc_high': {
        'title': 'Zone FC 4–5',
        'value': ciclo != null ? 'Tempo Anaerobico' : '--',
        'subtitle': 'Zone 4-5 cardio',
        'icon': Icons.local_fire_department,
        'accentColor': WhoopTheme.strainHigh,
      },
      'vo2max': {
        'title': 'VO₂ Max Stimato',
        'value': vo2Max != null ? '$vo2Max' : '--',
        'subtitle': 'ml/kg/min',
        'icon': Icons.speed,
        'accentColor': WhoopTheme.strainBlue,
      },
      'calories': {
        'title': 'Dispendio Energetico',
        'value': effectiveCal != null ? '$effectiveCal kcal' : '-- kcal',
        'subtitle': 'Totale BMR + Attività',
        'icon': Icons.bolt,
        'accentColor': WhoopTheme.strainBlue,
      },
      'sleep_need': {
        'title': 'Fabbisogno di Sonno',
        'value': effectiveSleepNeed > 0 ? '${(effectiveSleepNeed / 60).floor()}h ${(effectiveSleepNeed % 60).round()}m' : '--',
        'subtitle': 'Target basale',
        'icon': Icons.nightlight_round,
        'accentColor': WhoopTheme.sleepSlate,
      },
      'recovery': {
        'title': 'Recupero',
        'value': effectiveRecovery != null ? '${effectiveRecovery.round()}%' : '--',
        'subtitle': effectiveRecovery != null ? (effectiveRecovery >= 67 ? 'Zona Verde' : effectiveRecovery >= 34 ? 'Zona Gialla' : 'Zona Rossa') : 'In attesa di dati',
        'icon': Icons.battery_charging_full,
        'accentColor': effectiveRecovery != null ? (effectiveRecovery >= 67 ? WhoopTheme.recoveryGreen : effectiveRecovery >= 34 ? WhoopTheme.recoveryYellow : WhoopTheme.recoveryRed) : WhoopTheme.textSecondary,
      },
      'sleep_debt': {
        'title': 'Sonno Arretrato',
        'value': ciclo?.sonnoArretratoMin != null ? '${ciclo!.sonnoArretratoMin!.round()} min' : '--',
        'subtitle': 'Debito residuo',
        'icon': Icons.hourglass_empty,
        'accentColor': WhoopTheme.recoveryYellow,
      },
      'resp_rate': {
        'title': 'Frequenza Respiratoria',
        'value': effectiveResp != null ? '${effectiveResp.toStringAsFixed(1)} rpm' : '-- rpm',
        'subtitle': 'Nella norma notturna',
        'icon': Icons.air,
        'accentColor': WhoopTheme.strainBlue,
      },
      'skin_temp': {
        'title': 'Temperatura Cutanea',
        'value': effectiveTemp != null ? '${effectiveTemp >= 0 ? '+' : ''}${effectiveTemp.toStringAsFixed(1)} °C' : '-- °C',
        'subtitle': 'Delta basale',
        'icon': Icons.thermostat,
        'accentColor': WhoopTheme.recoveryYellow,
      },
      'spo2': {
        'title': 'Ossigeno nel Sangue (SpO₂)',
        'value': effectiveSpo2 != null ? '${effectiveSpo2.round()}%' : '-- %',
        'subtitle': 'Saturazione notturna',
        'icon': Icons.water_drop_outlined,
        'accentColor': WhoopTheme.strainBlue,
      },
      'deep_sleep': {
        'title': 'Sonno Profondo (SWS)',
        'value': (effectiveDeepSleep != null && effectiveDeepSleep > 0) ? '${(effectiveDeepSleep / 60).floor()}h ${(effectiveDeepSleep % 60)}m' : '--',
        'subtitle': 'Recupero muscolare',
        'icon': Icons.bedtime,
        'accentColor': WhoopTheme.strainBlue,
      },
      'rem_sleep': {
        'title': 'Sonno REM',
        'value': (effectiveRemSleep != null && effectiveRemSleep > 0) ? '${(effectiveRemSleep / 60).floor()}h ${(effectiveRemSleep % 60)}m' : '--',
        'subtitle': 'Rigenerazione cognitiva',
        'icon': Icons.psychology,
        'accentColor': WhoopTheme.strainBlue,
      },
      'sleep_efficiency': {
        'title': 'Efficienza del Sonno',
        'value': effectiveSleepEff != null ? '${effectiveSleepEff.round()}%' : '--',
        'subtitle': 'Tempo a letto dormito',
        'icon': Icons.check_circle_outline,
        'accentColor': WhoopTheme.recoveryGreen,
      },
    };

    final visibleTiles = enabledKeys
        .where((key) => allTiles.containsKey(key))
        .map((key) => MapEntry(key, allTiles[key]!))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'METRICHE CHIAVE',
              style: TextStyle(
                color: WhoopTheme.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.1,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.tune, color: WhoopTheme.textSecondary, size: 18),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CustomizableDashboardScreen()),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.45,
          ),
          itemCount: visibleTiles.length,
          itemBuilder: (context, index) {
            final entry = visibleTiles[index];
            final tileKey = entry.key;
            final tile = entry.value;

            return GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => TrendsScreen(initialMetric: tile['title'] as String? ?? tileKey),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF141920),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: WhoopTheme.cardBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            tile['title'] as String,
                            style: const TextStyle(
                              color: WhoopTheme.textSecondary,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Icon(
                          tile['icon'] as IconData,
                          size: 14,
                          color: tile['accentColor'] as Color,
                        ),
                      ],
                    ),
                    Text(
                      tile['value'] as String,
                      style: const TextStyle(
                        color: WhoopTheme.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      tile['subtitle'] as String,
                      style: TextStyle(
                        color: (tile['accentColor'] as Color).withValues(alpha: 0.8),
                        fontSize: 9.5,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
