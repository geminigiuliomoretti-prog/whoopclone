import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/whoop_theme.dart';
import '../../core/theme/nature_theme.dart';
import '../../viewmodels/whoop_viewmodel.dart';
import 'settings_device_screen.dart';
import 'whoop_import_screen.dart';

class ProfilePlanScreen extends StatelessWidget {
  final int initialTab;
  const ProfilePlanScreen({super.key, this.initialTab = 0});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NatureColors.background,
      appBar: AppBar(
        backgroundColor: NatureColors.background,
        elevation: 0,
        title: const Text(
          'PROFILO ATLETA & STATISTICHE REALI',
          style: TextStyle(
            color: NatureColors.textDarkPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
      ),
      body: Consumer<WhoopViewModel>(
        builder: (context, viewModel, child) {
          return _buildProfileTab(context, viewModel);
        },
      ),
    );
  }

  Widget _buildProfileTab(BuildContext context, WhoopViewModel viewModel) {
    final profile = viewModel.userProfile;
    final initials = profile.nome.length >= 2 ? profile.nome.substring(0, 2).toUpperCase() : 'AT';

    final cicli = viewModel.cicliList;
    final sonni = viewModel.allSonnoList;
    final allenamenti = viewModel.allenamentiList;

    // Calcolo dinamico statistiche ALL-TIME da cicli reali
    final fcrValues = cicli.map((c) => c.fcrBpm).whereType<int>().where((v) => v > 0).toList();
    final String minFcr = fcrValues.isNotEmpty ? '${fcrValues.reduce((a, b) => a < b ? a : b)} bpm' : '--';
    final String maxFcr = fcrValues.isNotEmpty ? '${fcrValues.reduce((a, b) => a > b ? a : b)} bpm' : '--';

    final hrvValues = cicli.map((c) => c.vfcMs).whereType<double>().where((v) => v > 0).toList();
    final String minHrv = hrvValues.isNotEmpty ? '${hrvValues.reduce((a, b) => a < b ? a : b).toInt()} ms' : '--';
    final String maxHrv = hrvValues.isNotEmpty ? '${hrvValues.reduce((a, b) => a > b ? a : b).toInt()} ms' : '--';

    final fcMaxValues = cicli.map((c) => c.fcMaxBpm).whereType<int>().where((v) => v > 0).toList();
    final String maxHrReached = fcMaxValues.isNotEmpty ? '${fcMaxValues.reduce((a, b) => a > b ? a : b)} bpm' : '--';

    final sleepDurValues = sonni.map((s) => s.durataTotMin).where((v) => v > 0).toList();
    String longestSleep = '--';
    if (sleepDurValues.isNotEmpty) {
      final maxMin = sleepDurValues.reduce((a, b) => a > b ? a : b);
      final h = (maxMin / 60).floor();
      final m = (maxMin % 60).round();
      longestSleep = '${h}h ${m}m';
    }

    final recValues = cicli.map((c) => c.punteggioRecuperoPct).whereType<double>().where((v) => v > 0).toList();
    final String minRecovery = recValues.isNotEmpty ? '${recValues.reduce((a, b) => a < b ? a : b).toInt()}%' : '--';

    // Raggruppamento dinamico attività registrate
    final Map<String, List<double>> activitiesMap = {};
    for (final a in allenamenti) {
      final name = a.nomeAttivita.isNotEmpty ? a.nomeAttivita : 'Attività';
      final strain = a.strainAttivita ?? a.sforzoRichiesto ?? 0.0;
      activitiesMap.putIfAbsent(name, () => []).add(strain);
    }

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // User Card
          Container(
            decoration: NatureTheme.organicCardDecoration(isDark: true),
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: NatureColors.teal.withValues(alpha: 0.15),
                  child: Text(
                    initials,
                    style: const TextStyle(
                      color: NatureColors.tealLight,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Builder(
                    builder: (context) {
                      final rhrDisplay = viewModel.getPersonalBaseline('rhr')?.mean.round() ?? profile.hrRestBaseline;
                      final hrvDisplay = viewModel.getPersonalBaseline('hrv')?.mean ?? profile.hrvBaselineMean;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            profile.nome,
                            style: const TextStyle(
                              color: NatureColors.textDarkPrimary,
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Text(
                            'Atleta • Wellness Companion',
                            style: TextStyle(color: NatureColors.textDarkSecondary, fontSize: 11),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'HRmax: ${profile.hrMax} bpm | FCR: $rhrDisplay bpm | VFC: ${hrvDisplay.round()} ms',
                            style: const TextStyle(
                              color: NatureColors.recoveryAccent,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_rounded, color: NatureColors.tealLight, size: 20),
                  onPressed: () => _showEditBiometricsDialog(context, viewModel),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          const Text(
            'DATI FISIOLOGICI BIOMETRICI (SQLITE)',
            style: TextStyle(
              color: NatureColors.textDarkMuted,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 10),

          Builder(
            builder: (context) {
              final rhrDisplay = viewModel.getPersonalBaseline('rhr')?.mean.round() ?? profile.hrRestBaseline;
              final hrvDisplay = viewModel.getPersonalBaseline('hrv')?.mean ?? profile.hrvBaselineMean;
              final sleepNeedDisplay = viewModel.getPersonalBaseline('sleep_need')?.mean.round() ??
                  viewModel.getPersonalBaseline('sleep_duration')?.mean.round() ??
                  profile.sleepBaselineMin;

              return Column(
                children: [
                  _buildBioTile('Età Fisiologica', '${profile.eta} anni', Icons.person),
                  _buildBioTile('HR Max', '${profile.hrMax} bpm', Icons.favorite, WhoopTheme.strainHigh),
                  _buildBioTile('FC a Riposo Baseline', '$rhrDisplay bpm', Icons.favorite, WhoopTheme.recoveryGreen),
                  _buildBioTile('VFC Baseline (RMSSD)', '${hrvDisplay.round()} ms', Icons.show_chart, WhoopTheme.strainBlue),
                  _buildBioTile('Fabbisogno Sonno Teorico', '$sleepNeedDisplay min (${(sleepNeedDisplay / 60).toStringAsFixed(1)}h)', Icons.nightlight_round, WhoopTheme.sleepSlate),
                ],
              );
            },
          ),

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

          const SizedBox(height: 24),

          // Importazione e Dispositivo
          _buildActionNavTile(
            context: context,
            title: 'Gestione Sensore & Dispositivo',
            subtitle: viewModel.isBleConnected
                ? 'Connesso • Batteria ${viewModel.batteryPct ?? "--"}%'
                : 'Disconnesso • Gestisci connessione BLE',
            icon: Icons.watch_outlined,
            color: WhoopTheme.strainBlue,
            onTap: () => SettingsDeviceScreen.show(context),
          ),
          _buildActionNavTile(
            context: context,
            title: 'Importa dati WHOOP',
            subtitle: 'Importa lo storico export ZIP per calibrare le baseline',
            icon: Icons.file_upload_outlined,
            color: NatureColors.teal,
            onTap: () => WhoopImportScreen.show(context),
          ),

          const SizedBox(height: 20),

          const Text(
            'STATISTICHE IMPORTANTI (ALL-TIME)',
            style: TextStyle(color: WhoopTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2),
          ),
          const SizedBox(height: 10),

          _buildBioTile('FCR minima registrata', minFcr, Icons.favorite, WhoopTheme.recoveryGreen),
          _buildBioTile('FCR massima registrata', maxFcr, Icons.favorite, WhoopTheme.strainHigh),
          _buildBioTile('VFC minima registrata', minHrv, Icons.show_chart, WhoopTheme.recoveryRed),
          _buildBioTile('VFC massima registrata', maxHrv, Icons.show_chart, WhoopTheme.recoveryGreen),
          _buildBioTile('HR Max raggiunta', maxHrReached, Icons.bolt, WhoopTheme.strainHigh),
          _buildBioTile('Sonno più lungo', longestSleep, Icons.nightlight_round, WhoopTheme.sleepSlate),
          _buildBioTile('Recovery minima registrata', minRecovery, Icons.battery_alert, WhoopTheme.recoveryRed),

          const SizedBox(height: 20),

          const Text(
            'RIEPILOGO ATTIVITÀ TOTALI',
            style: TextStyle(color: WhoopTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2),
          ),
          const SizedBox(height: 10),

          _buildBioTile('Attività totali registrate', '${allenamenti.length}×', Icons.fitness_center, WhoopTheme.strainBlue),
          if (activitiesMap.isEmpty)
            _buildBioTile('Nessuna sessione specifica', '--', Icons.directions_run, WhoopTheme.textSecondary)
          else
            ...activitiesMap.entries.map((entry) {
              final count = entry.value.length;
              final avgStrain = entry.value.reduce((a, b) => a + b) / count;
              return _buildBioTile(
                entry.key,
                '$count× • Sforzo medio ${avgStrain.toStringAsFixed(1)}',
                Icons.sports_score,
                WhoopTheme.strainBlue,
              );
            }),

          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildBioTile(String label, String value, IconData icon, [Color? color]) {
    return Container(
      decoration: NatureTheme.organicCardDecoration(isDark: true),
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: color ?? NatureColors.tealLight, size: 20),
        title: Text(label, style: const TextStyle(color: NatureColors.textDarkSecondary, fontSize: 12)),
        trailing: Text(value, style: TextStyle(color: color ?? NatureColors.textDarkPrimary, fontWeight: FontWeight.bold, fontSize: 13)),
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
    return Container(
      decoration: NatureTheme.organicCardDecoration(isDark: true),
      margin: const EdgeInsets.only(bottom: 8),
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
        title: Text(title, style: const TextStyle(color: NatureColors.textDarkPrimary, fontWeight: FontWeight.bold, fontSize: 13)),
        subtitle: Text(subtitle, style: const TextStyle(color: NatureColors.textDarkMuted, fontSize: 11)),
        trailing: const Icon(Icons.chevron_right, color: NatureColors.textDarkMuted, size: 18),
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
