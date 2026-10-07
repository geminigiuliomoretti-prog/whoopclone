import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/whoop_theme.dart';
import '../../core/theme/nature_theme.dart';
import '../../data/biometrics/health_vitals_engine.dart';
import '../../viewmodels/whoop_viewmodel.dart';
import '../widgets/live_heart_rate_card.dart';

/// Schermata di Dettaglio "MONITORAGGIO DELLA SALUTE"
/// Riproduce al 100% lo screenshot "Salute - Dettaglio 5 Parametri Vitali e Baseline.jpeg"
class HealthVitalsDetailScreen extends StatelessWidget {
  const HealthVitalsDetailScreen({super.key});

  static void show(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const HealthVitalsDetailScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = Provider.of<WhoopViewModel>(context);
    final liveBpm = viewModel.liveBpm;
    final vitals = viewModel.vitalEvaluations;

    VitalEvaluation? getVital(String key) {
      for (final v in vitals) {
        if (v.key == key) return v;
      }
      return null;
    }

    final resp = getVital('resp_rate') ?? (vitals.isNotEmpty ? vitals[0] : null);
    final spo2 = getVital('spo2') ?? (vitals.length > 1 ? vitals[1] : null);
    final fcr = getVital('fcr') ?? (vitals.length > 2 ? vitals[2] : null);
    final vfc = getVital('vfc') ?? (vitals.length > 3 ? vitals[3] : null);
    final temp = getVital('temp') ?? (vitals.length > 4 ? vitals[4] : null);

    final isLight = Theme.of(context).brightness == Brightness.light;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          color: WhoopTheme.textPrimary,
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'MONITORAGGIO DELLA SALUTE',
          style: WhoopTheme.cardTitleStyle(
            fontSize: 13,
            color: WhoopTheme.textPrimary,
          ).copyWith(fontWeight: FontWeight.w800),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. FREQUENZA CARDIACA Live Card (Con griglia, onda e 5 trattini zona)
            LiveHeartRateCard(liveBpm: liveBpm),

            const SizedBox(height: 16),

            // 2. Griglia 2x3 con i 5 Parametri Vitali Singoli
            Row(
              children: [
                Expanded(
                  child: _buildGridVitalCard(
                    title: 'FREQUENZA\nRESPIRATORIA',
                    value: resp?.currentVal != null
                        ? resp!.currentVal!.toStringAsFixed(1)
                        : '--',
                    unit: resp?.currentVal != null ? 'giri/min' : '',
                    badgeText: resp?.badgeText != null && resp!.badgeText.isNotEmpty
                        ? resp.badgeText
                        : (resp?.currentVal != null ? 'vicino alla baseline' : 'Dati non disponibili'),
                    icon: Icons.air,
                    status: resp?.status ?? VitalStatus.noData,
                    isLight: isLight,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildGridVitalCard(
                    title: 'OSSIGENO NEL\nSANGUE (SPO₂)',
                    value: spo2?.currentVal != null
                        ? spo2!.currentVal!.toInt().toString()
                        : '--',
                    unit: spo2?.currentVal != null ? '%' : '',
                    badgeText: spo2?.badgeText != null && spo2!.badgeText.isNotEmpty
                        ? spo2.badgeText
                        : (spo2?.currentVal != null ? 'circa 95% - 100%' : 'Dati non disponibili'),
                    icon: Icons.water_drop_outlined,
                    status: spo2?.status ?? VitalStatus.noData,
                    isLight: isLight,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: _buildGridVitalCard(
                    title: 'FCR',
                    value: fcr?.currentVal != null
                        ? fcr!.currentVal!.toInt().toString()
                        : '--',
                    unit: fcr?.currentVal != null ? 'bpm' : '',
                    badgeText: fcr?.badgeText != null && fcr!.badgeText.isNotEmpty
                        ? fcr.badgeText
                        : (fcr?.currentVal != null ? 'entro baseline' : 'Dati non disponibili'),
                    icon: Icons.favorite_border,
                    status: fcr?.status ?? VitalStatus.noData,
                    isLight: isLight,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildGridVitalCard(
                    title: 'VFC',
                    value: vfc?.currentVal != null
                        ? vfc!.currentVal!.toInt().toString()
                        : '--',
                    unit: vfc?.currentVal != null ? 'ms' : '',
                    badgeText: vfc?.badgeText != null && vfc!.badgeText.isNotEmpty
                        ? vfc.badgeText
                        : (vfc?.currentVal != null ? 'entro baseline' : 'Dati non disponibili'),
                    icon: Icons.show_chart,
                    status: vfc?.status ?? VitalStatus.noData,
                    isLight: isLight,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: _buildGridVitalCard(
                    title: 'TEMP. CUTANEA\n(DAL VALORE DI BASE)',
                    value: temp?.currentVal != null
                        ? '${temp!.currentVal! >= 0 ? "+" : ""}${temp.currentVal!.toStringAsFixed(1)}'
                        : '--',
                    unit: temp?.currentVal != null ? '°C' : '',
                    badgeText: temp?.badgeText != null && temp!.badgeText.isNotEmpty
                        ? temp.badgeText
                        : (temp?.currentVal != null ? 'entro baseline' : 'Dati non disponibili'),
                    icon: Icons.thermostat,
                    status: temp?.status ?? VitalStatus.noData,
                    isLight: isLight,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(child: SizedBox()), // Spazio vuoto per bilanciamento 2x3
              ],
            ),

            const SizedBox(height: 28),

            // Pulsante In Basso: CONDIVIDI IL REPORT SUL TUO STATO DI SALUTE
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Report Stato di Salute condiviso in PDF!'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: isLight ? Colors.white : const Color(0xFF1C242C),
                  elevation: isLight ? 1 : 0,
                  side: BorderSide(
                    color: isLight ? NatureColors.sandBorder : const Color(0xFF283440),
                    width: 0.85,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'CONDIVIDI IL REPORT SUL TUO STATO DI SALUTE',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: WhoopTheme.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildGridVitalCard({
    required String title,
    required String value,
    required String unit,
    required String badgeText,
    required IconData icon,
    VitalStatus? status,
    bool isLight = false,
  }) {
    Color badgeColor;
    IconData badgeIcon;
    Color pillBgColor;

    switch (status) {
      case VitalStatus.inRange:
        badgeColor = isLight ? NatureColors.sageDark : WhoopTheme.recoveryGreen;
        badgeIcon = Icons.check;
        pillBgColor = isLight ? NatureColors.sageBackground : const Color(0xFF132B25);
        break;
      case VitalStatus.outOfRange:
        badgeColor = isLight ? NatureColors.terracotta : WhoopTheme.recoveryRed;
        badgeIcon = Icons.priority_high;
        pillBgColor = isLight ? NatureColors.terracottaBackground : const Color(0xFF2E191C);
        break;
      case VitalStatus.calibration:
        badgeColor = isLight ? NatureColors.tealDark : WhoopTheme.strainBlue;
        badgeIcon = Icons.tune;
        pillBgColor = isLight ? NatureColors.tealBackground : const Color(0xFF132433);
        break;
      case VitalStatus.noData:
      default:
        badgeColor = isLight ? NatureColors.textLightMuted : WhoopTheme.textMuted;
        badgeIcon = Icons.remove;
        pillBgColor = isLight ? NatureColors.creamLight : const Color(0xFF1C242C);
        break;
    }

    return Container(
      height: 142,
      padding: const EdgeInsets.all(14),
      decoration: WhoopTheme.officialCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Header: Icona + Titolo
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: WhoopTheme.textSecondary, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: WhoopTheme.textSecondary,
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.6,
                    height: 1.2,
                  ),
                ),
              ),
            ],
          ),

          // Numero grande + Unità
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: const TextStyle(
                  color: WhoopTheme.textPrimary,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(width: 4),
              Text(
                unit,
                style: const TextStyle(
                  color: WhoopTheme.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),

          // Pill con icona e testo dell'intervallo
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: pillBgColor,
              borderRadius: BorderRadius.circular(6),
              border: isLight ? Border.all(color: badgeColor.withOpacity(0.25), width: 0.8) : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(badgeIcon, color: badgeColor, size: 12),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    badgeText,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: badgeColor,
                      fontSize: 9.5,
                      fontWeight: FontWeight.bold,
                    ),
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
