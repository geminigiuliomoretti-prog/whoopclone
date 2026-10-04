import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/whoop_theme.dart';
import '../../viewmodels/whoop_viewmodel.dart';
import 'activity_details_screen.dart';
import 'settings_device_screen.dart';
import 'integrations_screen.dart';
import 'onboarding_screen.dart';

class ProfilePlanScreen extends StatelessWidget {
  final int initialTab;
  const ProfilePlanScreen({super.key, this.initialTab = 0});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      initialIndex: initialTab,
      length: 2,
      child: Scaffold(
        backgroundColor: WhoopTheme.background,
        appBar: AppBar(
          title: const Text(
            'PROFILO ATLETA & MY PLAN',
            style: TextStyle(
              color: WhoopTheme.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
            ),
          ),
          bottom: const TabBar(
            indicatorColor: WhoopTheme.strainBlue,
            labelColor: WhoopTheme.textPrimary,
            unselectedLabelColor: WhoopTheme.textSecondary,
            tabs: [
              Tab(text: 'Profilo Atleta'),
              Tab(text: 'My Plan (Obiettivi)'),
            ],
          ),
        ),
        body: Consumer<WhoopViewModel>(
          builder: (context, viewModel, child) {
            return TabBarView(
              children: [
                // Tab 1: Profilo Atleta & Record
                _buildProfileTab(context, viewModel),

                // Tab 2: My Plan (Gestione Obiettivi)
                _buildPlanTab(context),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildProfileTab(BuildContext context, WhoopViewModel viewModel) {
    final profile = viewModel.userProfile;
    final initials = profile.nome.length >= 2 ? profile.nome.substring(0, 2).toUpperCase() : 'GM';

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // User Card
          Card(
            color: WhoopTheme.cardSurface,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: WhoopTheme.strainBlue.withValues(alpha: 0.2),
                    child: Text(initials, style: const TextStyle(color: WhoopTheme.strainBlue, fontSize: 20, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(profile.nome, style: const TextStyle(color: WhoopTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
                        const Text('Atleta WHOOP 5.0 | Membro dal 2024', style: TextStyle(color: WhoopTheme.textSecondary, fontSize: 12)),
                        const SizedBox(height: 4),
                        Text('HRmax: ${profile.hrMax} bpm | FCR: ${profile.hrRestBaseline} bpm | VFC: ${profile.hrvBaselineMean.toInt()} ms',
                            style: const TextStyle(color: WhoopTheme.recoveryGreen, fontSize: 11, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit, color: WhoopTheme.strainBlue, size: 20),
                    onPressed: () => _showEditBiometricsDialog(context, viewModel),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          const Text(
            'DATI FISIOLOGICI BIOMETRICI (SQLITE)',
            style: TextStyle(color: WhoopTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2),
          ),
          const SizedBox(height: 10),

          _buildBioTile('Età Fisiologica', '${profile.eta} anni', Icons.person),
          _buildBioTile('HR Max', '${profile.hrMax} bpm', Icons.favorite, WhoopTheme.strainHigh),
          _buildBioTile('FC a Riposo Baseline', '${profile.hrRestBaseline} bpm', Icons.favorite, WhoopTheme.recoveryGreen),
          _buildBioTile('VFC Baseline (RMSSD)', '${profile.hrvBaselineMean.toStringAsFixed(1)} ms', Icons.show_chart, WhoopTheme.strainBlue),
          _buildBioTile('Fabbisogno Sonno Teorico', '${profile.sleepBaselineMin} min (${(profile.sleepBaselineMin / 60).toStringAsFixed(1)}h)', Icons.nightlight_round, WhoopTheme.sleepSlate),

          const SizedBox(height: 12),

          // Tasto Modifica Parametri Biometrici
          SizedBox(
            width: double.infinity,
            height: 44,
            child: OutlinedButton.icon(
              onPressed: () => _showEditBiometricsDialog(context, viewModel),
              icon: const Icon(Icons.tune, color: WhoopTheme.strainBlue, size: 18),
              label: const Text('MODIFICA PARAMETRI BIOMETRICI BASELINE', style: TextStyle(color: WhoopTheme.strainBlue, fontSize: 11, fontWeight: FontWeight.bold)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: WhoopTheme.strainBlue),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),

          const SizedBox(height: 20),

          const Text(
            'IMPOSTAZIONI & SERVIZI WHOOP 5.0',
            style: TextStyle(color: WhoopTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2),
          ),
          const SizedBox(height: 10),

          _buildActionNavTile(
            context: context,
            title: 'Gestione Sensore & Dispositivo (ID 5A00479315)',
            subtitle: 'Batteria 77%, Firmware 50.39.1.0, Notifiche & Reset',
            icon: Icons.settings,
            color: WhoopTheme.strainBlue,
            onTap: () => SettingsDeviceScreen.show(context),
          ),
          _buildActionNavTile(
            context: context,
            title: 'Integrazioni Ecosistemi Esterni',
            subtitle: 'Apple Health, Health Connect, Strava, TrainingPeaks, Withings',
            icon: Icons.sync,
            color: WhoopTheme.recoveryGreen,
            onTap: () => IntegrationsScreen.show(context),
          ),
          _buildActionNavTile(
            context: context,
            title: 'Onboarding & Calibrazione 4 Giorni',
            subtitle: 'Guida associazione BLE e calibrazione baseline iniziale',
            icon: Icons.tune,
            color: WhoopTheme.strainBlue,
            onTap: () => OnboardingScreen.show(context),
          ),
          _buildActionNavTile(
            context: context,
            title: 'Dettaglio Ultimo Allenamento (Activity Details)',
            subtitle: 'Tracciato GPS Dark Mode, FC Live & 5 Zone Cardiarche',
            icon: Icons.directions_bike,
            color: WhoopTheme.strainHigh,
            onTap: () => ActivityDetailsScreen.show(context),
          ),

          const SizedBox(height: 20),

          const Text(
            'STATISTICHE IMPORTANTI (ALL-TIME)',
            style: TextStyle(color: WhoopTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2),
          ),
          const SizedBox(height: 10),

          _buildBioTile('FCR minima registrata', '43 bpm', Icons.favorite, WhoopTheme.recoveryGreen),
          _buildBioTile('FCR massima registrata', '82 bpm', Icons.favorite, WhoopTheme.strainHigh),
          _buildBioTile('VFC minima registrata', '21 ms', Icons.show_chart, WhoopTheme.recoveryRed),
          _buildBioTile('VFC massima registrata', '120 ms', Icons.show_chart, WhoopTheme.recoveryGreen),
          _buildBioTile('HR Max raggiunta', '200 bpm', Icons.bolt, WhoopTheme.strainHigh),
          _buildBioTile('Sonno più lungo', '10:00 h', Icons.nightlight_round, WhoopTheme.sleepSlate),
          _buildBioTile('Recovery minima registrata', '1%', Icons.battery_alert, WhoopTheme.recoveryRed),

          const SizedBox(height: 20),

          const Text(
            'RIEPILOGO ATTIVITÀ TOTALI',
            style: TextStyle(color: WhoopTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2),
          ),
          const SizedBox(height: 10),

          _buildBioTile('Attività totali registrate', '311×', Icons.fitness_center, WhoopTheme.strainBlue),
          _buildBioTile('Tennis', '166× • Sforzo medio 12.2', Icons.sports_tennis, WhoopTheme.strainBlue),
          _buildBioTile('Attività generica', '41× • Sforzo medio 6.2', Icons.directions_run, WhoopTheme.textSecondary),
          _buildBioTile('Strength Trainer', '35× • Sforzo medio 7.6', Icons.fitness_center, WhoopTheme.strainHigh),

          const SizedBox(height: 20),

          // Programma Referral
          Card(
            color: WhoopTheme.cardSurface,
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: WhoopTheme.recoveryGreen.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.share, color: WhoopTheme.recoveryGreen, size: 20),
              ),
              title: const Text('Programma Referral', style: TextStyle(color: WhoopTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 13)),
              subtitle: const Text('Codice: WHOOP-GM13 • Invita amici e ottieni 1 mese gratis', style: TextStyle(color: WhoopTheme.textMuted, fontSize: 11)),
              trailing: const Icon(Icons.chevron_right, color: WhoopTheme.textMuted, size: 18),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionNavTile({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      color: WhoopTheme.cardSurface,
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: ListTile(
          onTap: onTap,
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          title: Text(title, style: const TextStyle(color: WhoopTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 13)),
          subtitle: Text(subtitle, style: const TextStyle(color: WhoopTheme.textMuted, fontSize: 11)),
          trailing: const Icon(Icons.chevron_right, color: WhoopTheme.textMuted, size: 18),
        ),
      ),
    );
  }


  Widget _buildPlanTab(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: WhoopTheme.cardSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: WhoopTheme.cardBorder),
            ),
            child: const Row(
              children: [
                Icon(Icons.flag, color: WhoopTheme.strainBlue, size: 24),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'My Plan configura gli obiettivi di sforzo e sonno quotidiani basati sulle tue mete sportive.',
                    style: TextStyle(color: WhoopTheme.textPrimary, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          const Text(
            'OBIETTIVO DI PERFORMANCE CORRENTE',
            style: TextStyle(color: WhoopTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2),
          ),
          const SizedBox(height: 10),

          _buildPlanOption(
            title: 'Prestazione Max (Peak Performance)',
            description: 'Obiettivo Sonno 100% | Sforzo Target 16.0 - 18.5',
            isSelected: true,
          ),
          _buildPlanOption(
            title: 'Mantenimento & Recupero',
            description: 'Obiettivo Sonno 85% | Sforzo Target 12.0 - 15.0',
            isSelected: false,
          ),
          _buildPlanOption(
            title: 'Stagione di Riposo (Off-Season)',
            description: 'Obiettivo Sonno 70% | Sforzo Target 8.0 - 12.0',
            isSelected: false,
          ),
        ],
      ),
    );
  }

  Widget _buildBioTile(String label, String value, IconData icon, [Color? color]) {
    return Card(
      color: WhoopTheme.cardSurface,
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: ListTile(
          leading: Icon(icon, color: color ?? WhoopTheme.strainBlue, size: 20),
          title: Text(label, style: const TextStyle(color: WhoopTheme.textSecondary, fontSize: 12)),
          trailing: Text(value, style: TextStyle(color: color ?? WhoopTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 13)),
        ),
      ),
    );
  }

  Widget _buildPlanOption({
    required String title,
    required String description,
    required bool isSelected,
  }) {
    return Card(
      color: isSelected ? WhoopTheme.cardBorder : WhoopTheme.cardSurface,
      margin: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: ListTile(
          leading: Icon(
            isSelected ? Icons.check_circle : Icons.circle_outlined,
            color: isSelected ? WhoopTheme.strainBlue : WhoopTheme.textMuted,
          ),
          title: Text(title, style: TextStyle(color: isSelected ? WhoopTheme.strainBlue : WhoopTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 13)),
          subtitle: Text(description, style: const TextStyle(color: WhoopTheme.textMuted, fontSize: 11)),
        ),
      ),
    );
  }

  Future<void> _showEditBiometricsDialog(BuildContext context, WhoopViewModel viewModel) async {
    final profile = viewModel.userProfile;
    final nameCtrl = TextEditingController(text: profile.nome);
    final ageCtrl = TextEditingController(text: profile.eta.toString());
    final maxHrCtrl = TextEditingController(text: profile.hrMax.toString());
    final rhrCtrl = TextEditingController(text: profile.hrRestBaseline.toString());
    final hrvCtrl = TextEditingController(text: profile.hrvBaselineMean.toStringAsFixed(1));
    final sleepCtrl = TextEditingController(text: profile.sleepBaselineMin.toString());

    try {
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: WhoopTheme.cardSurface,
          title: const Text('Modifica Parametri Biometrici', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: const InputDecoration(labelText: 'Nome Atleta', labelStyle: TextStyle(color: WhoopTheme.textMuted)),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: ageCtrl,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: const InputDecoration(labelText: 'Età', labelStyle: TextStyle(color: WhoopTheme.textMuted)),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: maxHrCtrl,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: const InputDecoration(labelText: 'HR Max (bpm)', labelStyle: TextStyle(color: WhoopTheme.textMuted)),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: rhrCtrl,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: const InputDecoration(labelText: 'FC a Riposo Baseline (bpm)', labelStyle: TextStyle(color: WhoopTheme.textMuted)),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: hrvCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: const InputDecoration(labelText: 'VFC Baseline (RMSSD ms)', labelStyle: TextStyle(color: WhoopTheme.textMuted)),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: sleepCtrl,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: const InputDecoration(labelText: 'Fabbisogno Sonno Baseline (minuti)', labelStyle: TextStyle(color: WhoopTheme.textMuted)),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('ANNULLA', style: TextStyle(color: WhoopTheme.textMuted)),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = nameCtrl.text.trim();
                final age = int.tryParse(ageCtrl.text.trim()) ?? profile.eta;
                final maxHr = int.tryParse(maxHrCtrl.text.trim()) ?? profile.hrMax;
                final rhr = int.tryParse(rhrCtrl.text.trim()) ?? profile.hrRestBaseline;
                final hrv = double.tryParse(hrvCtrl.text.trim()) ?? profile.hrvBaselineMean;
                final sleep = int.tryParse(sleepCtrl.text.trim()) ?? profile.sleepBaselineMin;

                if (name.isNotEmpty) {
                  await viewModel.updateUserProfile(
                    name: name,
                    age: age,
                    maxHr: maxHr,
                    baselineRhr: rhr,
                    baselineHrv: hrv,
                    sleepBaselineMin: sleep,
                  );
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Profilo utente e baseline aggiornati con successo in SQLite!')),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: WhoopTheme.strainBlue),
              child: const Text('SALVA', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    } finally {
      nameCtrl.dispose();
      ageCtrl.dispose();
      maxHrCtrl.dispose();
      rhrCtrl.dispose();
      hrvCtrl.dispose();
      sleepCtrl.dispose();
    }
  }
}
