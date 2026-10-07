import 'package:flutter/material.dart';
import '../../core/constants/whoop_theme.dart';
import '../../core/theme/nature_theme.dart';
import 'coach_screen.dart';
import 'trends_screen.dart';
import 'journal_screen.dart';
import 'profile_plan_screen.dart';
import 'settings_device_screen.dart';
import 'integrations_screen.dart';
import 'onboarding_screen.dart';
import 'customizable_dashboard_screen.dart';
import 'activity_details_screen.dart';
import 'health_screen.dart';
import '../breathe/haptic_breathe_screen.dart';

/// Modulo 19 — Menu "Altro": Hub di Navigazione a tutti i 25 Moduli
class MoreMenuScreen extends StatelessWidget {
  const MoreMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header Profilo Atleta ────────────────────────────────
              _buildProfileHeader(context),

              const SizedBox(height: 24),

              // ── Sezione: Analisi & Dati ─────────────────────────────
              _buildSectionLabel('ANALISI & DATI'),
              const SizedBox(height: 10),

              _buildNavTile(
                context: context,
                icon: Icons.show_chart,
                title: 'Trends & Calendario',
                subtitle: 'VFC, Recupero, Sonno — 7D / 30D / 6M / 1Y',
                color: WhoopTheme.strainBlue,
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const TrendsScreen())),
              ),
              _buildNavTile(
                context: context,
                icon: Icons.book_outlined,
                title: 'Journal & Impact Analytics',
                subtitle: 'Diario comportamenti e analisi cross-data +/- %',
                color: WhoopTheme.strainBlue,
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const JournalScreen())),
              ),
              _buildNavTile(
                context: context,
                icon: Icons.monitor_heart_outlined,
                title: 'Health Monitor',
                subtitle: '5 parametri vitali, baseline 30 gg, referto PDF',
                color: WhoopTheme.strainBlue,
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const HealthScreen())),
              ),
              _buildNavTile(
                context: context,
                icon: Icons.directions_run,
                title: 'Ultima Attività (Activity Details)',
                subtitle: 'Tracciato GPS, 5 Zone FC, calorie, strain sessione',
                color: WhoopTheme.strainBlue,
                onTap: () => ActivityDetailsScreen.show(context),
              ),
              _buildNavTile(
                context: context,
                icon: Icons.spa_outlined,
                title: 'Respirazione Aptica & Biofeedback',
                subtitle: 'Relax (4-6), Coerenza Cardiaca, Box Breathing con impulsi BLE',
                color: WhoopTheme.recoveryGreen,
                onTap: () => HapticBreatheScreen.show(context),
              ),

              const SizedBox(height: 20),

              // ── Sezione: Coach AI & Pianificazione ──────────────────
              _buildSectionLabel('COACH AI & PIANIFICAZIONE'),
              const SizedBox(height: 10),

              _buildNavTile(
                context: context,
                icon: Icons.psychology_outlined,
                title: 'WHOOP Coach AI V5.4',
                subtitle: 'Chat contestuale, Daily Outlook, La Mia Memoria',
                color: WhoopTheme.strainBlue,
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const CoachScreen())),
              ),
              _buildNavTile(
                context: context,
                icon: Icons.person_outline,
                title: 'Profilo Atleta',
                subtitle: 'Dati anagrafici, FCmax, Baseline biometriche',
                color: WhoopTheme.strainBlue,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ProfilePlanScreen(initialTab: 0),
                  ),
                ),
              ),
              _buildNavTile(
                context: context,
                icon: Icons.dashboard_customize_outlined,
                title: 'Dashboard Personalizzabile',
                subtitle: 'Scegli e ordina le metriche biometriche in Home',
                color: WhoopTheme.strainBlue,
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(
                        builder: (_) => const CustomizableDashboardScreen())),
              ),
              _buildNavTile(
                context: context,
                icon: Icons.share_outlined,
                title: 'Programma Referral',
                subtitle: 'Invita amici e ottieni 1 mese gratuito di WHOOP',
                color: WhoopTheme.recoveryGreen,
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text(
                            'Codice Referral: WHOOP-GM13 — Condividi!')),
                  );
                },
              ),

              const SizedBox(height: 20),

              // ── Sezione: Dispositivo & Impostazioni ─────────────────
              _buildSectionLabel('DISPOSITIVO & IMPOSTAZIONI'),
              const SizedBox(height: 10),

              _buildNavTile(
                context: context,
                icon: Icons.watch_outlined,
                title: 'Gestione Sensore WHOOP 5.0',
                subtitle: 'ID 5A00479315 • Firmware 50.39.1.0 • Batteria 77%',
                color: WhoopTheme.strainBlue,
                onTap: () => SettingsDeviceScreen.show(context),
              ),
              _buildNavTile(
                context: context,
                icon: Icons.sync_outlined,
                title: 'Integrazioni Ecosistemi Esterni',
                subtitle:
                    'Apple Health, Health Connect, Strava, Withings, TrainingPeaks',
                color: WhoopTheme.strainBlue,
                onTap: () => IntegrationsScreen.show(context),
              ),
              _buildNavTile(
                context: context,
                icon: Icons.tune_outlined,
                title: 'Onboarding & Calibrazione 4 Giorni',
                subtitle: 'Guida primo utilizzo, associazione BLE, baseline',
                color: WhoopTheme.strainBlue,
                onTap: () => OnboardingScreen.show(context),
              ),

              const SizedBox(height: 20),

              // ── Sezione: Profilo ─────────────────────────────────────
              _buildSectionLabel('PROFILO ATLETA'),
              const SizedBox(height: 10),

              _buildNavTile(
                context: context,
                icon: Icons.person_outline,
                title: 'Profilo & Record Personali',
                subtitle: 'Livello 13 • 175 gg streak • Statistiche All-Time',
                color: WhoopTheme.strainBlue,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ProfilePlanScreen(initialTab: 0),
                  ),
                ),
              ),

              const SizedBox(height: 32),

              Center(
                child: Text(
                  'WHOOP 5.0 Clone • v1.0.0 • Tutti i dati sono archiviati\nlocalmente nel database SQLite crittografato.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: WhoopTheme.textMuted,
                    fontSize: 10,
                    height: 1.5,
                  ),
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileHeader(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => const ProfilePlanScreen(initialTab: 0)),
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: WhoopTheme.officialCardDecoration(),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Theme.of(context).brightness == Brightness.light
                    ? NatureColors.sageBackground
                    : NatureColors.forestDeep,
                border: Border.all(
                  color: Theme.of(context).brightness == Brightness.light
                      ? NatureColors.sage.withOpacity(0.4)
                      : NatureColors.sageLight,
                  width: 1.5,
                ),
              ),
              child: Center(
                child: Text(
                  'GM',
                  style: TextStyle(
                    color: Theme.of(context).brightness == Brightness.light
                        ? NatureColors.sageDark
                        : Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Giulio Moretti',
                    style: TextStyle(
                      color: WhoopTheme.textPrimary,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Text(
                    '@Giulio_moretti',
                    style: TextStyle(
                        color: WhoopTheme.textSecondary, fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      _buildBadge('Lv. 13', NatureColors.tealDark, NatureColors.tealBackground),
                      _buildBadge('🔥 175 giorni', NatureColors.terracotta, NatureColors.terracottaBackground),
                      _buildBadge('173 recuperi', NatureColors.sageDark, NatureColors.sageBackground),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right,
                color: WhoopTheme.textSecondary, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildBadge(String text, Color textColor, Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: textColor.withOpacity(0.25), width: 0.8),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: textColor,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        color: WhoopTheme.textSecondary,
        fontSize: 11,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.4,
      ),
    );
  }

  Widget _buildNavTile({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: WhoopTheme.officialCardDecoration(),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.13),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: WhoopTheme.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: WhoopTheme.textMuted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right,
                    color: WhoopTheme.textMuted, size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
