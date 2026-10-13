import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/nature_theme.dart';
import '../../viewmodels/whoop_viewmodel.dart';
import 'coach_screen.dart';
import 'trends_screen.dart';
import 'journal_screen.dart';
import 'profile_plan_screen.dart';
import 'settings_device_screen.dart';
import 'customizable_dashboard_screen.dart';
import 'health_screen.dart';
import '../breathe/haptic_breathe_screen.dart';
import 'whoop_import_screen.dart';

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
                icon: Icons.show_chart_rounded,
                title: 'Trends & Calendario',
                subtitle: 'VFC, Recupero, Sonno — 7D / 30D / 6M / 1Y',
                color: NatureColors.teal,
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const TrendsScreen())),
              ),
              _buildNavTile(
                context: context,
                icon: Icons.book_outlined,
                title: 'Journal & Impact Analytics',
                subtitle: 'Diario comportamenti e analisi cross-data +/- %',
                color: NatureColors.teal,
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const JournalScreen())),
              ),
              _buildNavTile(
                context: context,
                icon: Icons.monitor_heart_outlined,
                title: 'Health Monitor',
                subtitle: '5 parametri vitali, baseline 30 gg, referto PDF',
                color: NatureColors.teal,
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const HealthScreen())),
              ),
              _buildNavTile(
                context: context,
                icon: Icons.spa_outlined,
                title: 'Respirazione Aptica & Biofeedback',
                subtitle: 'Relax (4-6), Coerenza Cardiaca, Box Breathing con impulsi BLE',
                color: NatureColors.recoveryAccent,
                onTap: () => HapticBreatheScreen.show(context),
              ),
              _buildNavTile(
                context: context,
                icon: Icons.file_upload_outlined,
                title: 'Importa Dati WHOOP',
                subtitle: 'Importa archivio ZIP storico e personalizza le baseline',
                color: NatureColors.teal,
                onTap: () => WhoopImportScreen.show(context),
              ),

              const SizedBox(height: 20),

              // ── Sezione: Coach AI & Pianificazione ──────────────────
              _buildSectionLabel('COACH AI & PIANIFICAZIONE'),
              const SizedBox(height: 10),

              _buildNavTile(
                context: context,
                icon: Icons.psychology_outlined,
                title: 'Coach AI',
                subtitle: 'Chat contestuale, Daily Outlook, La Mia Memoria',
                color: NatureColors.teal,
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const CoachScreen())),
              ),
              _buildNavTile(
                context: context,
                icon: Icons.person_outline_rounded,
                title: 'Profilo Atleta',
                subtitle: 'Dati anagrafici, FCmax, Baseline biometriche',
                color: NatureColors.teal,
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
                color: NatureColors.teal,
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(
                        builder: (_) => const CustomizableDashboardScreen())),
              ),

              const SizedBox(height: 20),

              // ── Sezione: Dispositivo & Impostazioni ─────────────────
              _buildSectionLabel('DISPOSITIVO & IMPOSTAZIONI'),
              const SizedBox(height: 10),

              Consumer<WhoopViewModel>(
                builder: (context, viewModel, _) {
                  final String deviceSubtitle = viewModel.isBleConnected
                      ? 'Connesso • Batteria ${viewModel.batteryPct != null ? "${viewModel.batteryPct}%" : "--"}'
                      : 'Disconnesso • Tocca per gestire';
                  return _buildNavTile(
                    context: context,
                    icon: Icons.watch_outlined,
                    title: 'Gestione Sensore & Dispositivo',
                    subtitle: deviceSubtitle,
                    color: NatureColors.teal,
                    onTap: () => SettingsDeviceScreen.show(context),
                  );
                },
              ),

              const SizedBox(height: 32),

              Center(
                child: Text(
                  'Wellness Companion • v1.0.0 • Tutti i dati sono archiviati\nlocalmente nel database SQLite crittografato.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: NatureColors.textDarkMuted,
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
    return Consumer<WhoopViewModel>(
      builder: (context, viewModel, child) {
        final name = viewModel.userName.isNotEmpty ? viewModel.userName : 'Atleta';
        final initials = name.length >= 2 ? name.substring(0, 2).toUpperCase() : 'AT';
        final streak = viewModel.streakDays;
        final recoveriesCount = viewModel.cicliList.where((c) => c.punteggioRecuperoPct != null).length;
        final nightsCount = viewModel.allSonnoList.length;

        return GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => const ProfilePlanScreen(initialTab: 0)),
          ),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: NatureTheme.organicCardDecoration(isDark: true),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: NatureColors.forestDeep,
                    border: Border.all(
                      color: NatureColors.sageLight,
                      width: 1.5,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      initials,
                      style: const TextStyle(
                        color: Colors.white,
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
                      Text(
                        name,
                        style: const TextStyle(
                          color: NatureColors.textDarkPrimary,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '@${name.toLowerCase().replaceAll(' ', '_')}',
                        style: const TextStyle(
                            color: NatureColors.textDarkSecondary, fontSize: 12),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          _buildBadge('🔥 $streak giorni', NatureColors.terracotta, NatureColors.terracottaBackground),
                          _buildBadge('$recoveriesCount recuperi', NatureColors.sageDark, NatureColors.sageBackground),
                          _buildBadge('$nightsCount notti registrate', NatureColors.tealDark, NatureColors.tealBackground),
                        ],
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right,
                    color: NatureColors.textDarkMuted, size: 20),
              ],
            ),
          ),
        );
      },
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
        color: NatureColors.textDarkMuted,
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
            decoration: NatureTheme.organicCardDecoration(isDark: true),
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
                          color: NatureColors.textDarkPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: NatureColors.textDarkMuted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right,
                    color: NatureColors.textDarkMuted, size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
