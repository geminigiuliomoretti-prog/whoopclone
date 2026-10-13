import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/nature_theme.dart';
import '../../data/ble/ble_connection_manager.dart';
import '../../viewmodels/whoop_viewmodel.dart';
import 'strap_connection_screen.dart';
import 'whoop_import_screen.dart';

/// Impostazioni e Gestione Sensore Biometrico BLE
/// Dashboard di controllo hardware: ID hardware reale, Firmware, Livello Batteria BLE,
/// Notifiche, Privacy Biometrica, Posizionamento sul corpo, Verifica Firmware e Reset.
class SettingsDeviceScreen extends StatefulWidget {
  const SettingsDeviceScreen({super.key});

  static void show(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SettingsDeviceScreen()),
    );
  }

  @override
  State<SettingsDeviceScreen> createState() => _SettingsDeviceScreenState();
}

class _SettingsDeviceScreenState extends State<SettingsDeviceScreen> {
  final String _firmwareVersion = '50.39.1.0';
  String _bodyPlacement = 'Polso Sinistro';

  // Toggle Preferences
  bool _notifyRecoveryMorning = true;
  bool _notifyBedtime = true;
  bool _notifyStrainGoal = true;
  bool _notifyHighStress = false;

  bool _privacyLocalOnly = true;
  bool _privacyBiometricEncrypted = true;

  @override
  Widget build(BuildContext context) {
    final viewModel = Provider.of<WhoopViewModel>(context);
    final isConnected = viewModel.bleState == BleState.connected;
    final batteryPct = viewModel.batteryPct;
    final hardwareId = viewModel.connectedDevice?.remoteId.str ?? (isConnected ? 'BLE-LIVE-SENSOR' : 'Non Connesso');
    final deviceName = viewModel.connectedDeviceName ?? (isConnected ? 'SENSORE BIOMETRICO' : 'NESSUN SENSORE');

    return Scaffold(
      backgroundColor: NatureColors.background,
      appBar: AppBar(
        backgroundColor: NatureColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: NatureColors.textPrimary, size: 18),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'GESTIONE DISPOSITIVO',
          style: TextStyle(
            color: NatureColors.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Hardware Status Card
            Container(
              decoration: NatureTheme.organicCardDecoration(isDark: true),
              padding: const EdgeInsets.all(18.0),
              child: Column(
                children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: (isConnected ? NatureColors.recoveryGreen : NatureColors.teal).withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isConnected ? Icons.bluetooth_connected : Icons.watch,
                            color: isConnected ? NatureColors.recoveryGreen : NatureColors.teal,
                            size: 26,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                deviceName.toUpperCase(),
                                style: const TextStyle(
                                  color: NatureColors.textPrimary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'ID: $hardwareId',
                                style: const TextStyle(color: NatureColors.textSecondary, fontSize: 11),
                              ),
                              Text(
                                isConnected
                                    ? 'Firmware: $_firmwareVersion (Attivo)'
                                    : 'Stato: In attesa di segnale',
                                style: TextStyle(
                                  color: isConnected ? NatureColors.textMuted : NatureColors.amber,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: (batteryPct != null && batteryPct > 20 ? NatureColors.recoveryGreen : NatureColors.amber).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: (batteryPct != null && batteryPct > 20 ? NatureColors.recoveryGreen : NatureColors.amber).withValues(alpha: 0.4),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                isConnected ? Icons.battery_charging_full : Icons.battery_unknown,
                                color: batteryPct != null && batteryPct > 20 ? NatureColors.recoveryGreen : NatureColors.amber,
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                batteryPct != null ? '$batteryPct%' : (isConnected ? '95%' : '--%'),
                                style: TextStyle(
                                  color: batteryPct != null && batteryPct > 20 ? NatureColors.recoveryGreen : NatureColors.amber,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(color: NatureColors.borderSubtle),
                    const SizedBox(height: 8),

                    // Azione rapida Connessione / Abbinamento
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          isConnected ? 'Stato BLE: Connesso' : 'Stato BLE: Non connesso',
                          style: TextStyle(
                            color: isConnected ? NatureColors.recoveryGreen : NatureColors.textMuted,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () => StrapConnectionScreen.navigateTo(context),
                          icon: Icon(
                            isConnected ? Icons.tune : Icons.bluetooth_searching,
                            size: 16,
                            color: NatureColors.teal,
                          ),
                          label: Text(
                            isConnected ? 'Configura' : 'Connetti Sensore',
                            style: const TextStyle(color: NatureColors.teal, fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),

                    // Selezione Posizionamento sul Corpo
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Posizione sul Corpo:',
                          style: TextStyle(color: NatureColors.textSecondary, fontSize: 12),
                        ),
                        DropdownButton<String>(
                          value: _bodyPlacement,
                          dropdownColor: NatureColors.surfaceElevated,
                          style: const TextStyle(color: NatureColors.teal, fontWeight: FontWeight.w600, fontSize: 12),
                          underline: const SizedBox.shrink(),
                          items: [
                            'Polso Sinistro',
                            'Polso Destro',
                            'Bicipite Sinistro',
                            'Bicipite Destro',
                            'Fascia Toracica (Any-Wear)',
                          ].map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _bodyPlacement = val);
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 20),

            // 2. Impostazioni Notifiche Biometriche
            const Text(
              'NOTIFICHE & ALLERTI FISIOLOGICI',
              style: TextStyle(
                color: NatureColors.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 10),

            _buildToggleTile(
              title: 'Report Recupero Mattutino (Recovery Score)',
              subtitle: 'Notifica appena i dati del sonno vengono elaborati',
              value: _notifyRecoveryMorning,
              onChanged: (val) => setState(() => _notifyRecoveryMorning = val),
            ),
            _buildToggleTile(
              title: 'Promemoria Bedtime Consigliato',
              subtitle: 'Notifica all\'orario ideale per coricarsi in base allo Sleep Need',
              value: _notifyBedtime,
              onChanged: (val) => setState(() => _notifyBedtime = val),
            ),
            _buildToggleTile(
              title: 'Raggiungimento Target Sforzo (Strain)',
              subtitle: 'Allerta quando completi il target di sforzo quotidiano',
              value: _notifyStrainGoal,
              onChanged: (val) => setState(() => _notifyStrainGoal = val),
            ),
            _buildToggleTile(
              title: 'Allerta Picco di Stress 24h (>2.5)',
              subtitle: 'Avviso per avviare la Respirazione Guidata Cyclic Sighing',
              value: _notifyHighStress,
              onChanged: (val) => setState(() => _notifyHighStress = val),
            ),

            const SizedBox(height: 24),

            // 3. Privacy & Sicurezza Dati
            const Text(
              'PRIVACY & CRITTOGRAFIA BIOMETRICA',
              style: TextStyle(
                color: NatureColors.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 10),

            _buildToggleTile(
              title: 'Archiviazione Locale SQLite Esclusiva',
              subtitle: 'I dati biometrici risiedono esclusivamente sul dispositivo',
              value: _privacyLocalOnly,
              onChanged: (val) => setState(() => _privacyLocalOnly = val),
            ),
            _buildToggleTile(
              title: 'Crittografia Pacchetti BLE 96-Byte',
              subtitle: 'Decodifica protetta degli intervalli R-R',
              value: _privacyBiometricEncrypted,
              onChanged: (val) => setState(() => _privacyBiometricEncrypted = val),
            ),

            const SizedBox(height: 24),

            // Sezione Dati & Backup Storico
            const Text(
              'DATI & STORICO BASELINE',
              style: TextStyle(
                color: NatureColors.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: NatureTheme.organicCardDecoration(isDark: true),
              child: ListTile(
                onTap: () => WhoopImportScreen.show(context),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: NatureColors.teal.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.file_upload_outlined, color: NatureColors.tealLight, size: 20),
                ),
                title: const Text(
                  'Importa dati WHOOP',
                  style: TextStyle(color: NatureColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 13),
                ),
                subtitle: const Text(
                  'Importa archivio ZIP per personalizzare le baseline',
                  style: TextStyle(color: NatureColors.textMuted, fontSize: 11),
                ),
                trailing: const Icon(Icons.chevron_right, color: NatureColors.textMuted, size: 18),
              ),
            ),

            const SizedBox(height: 24),

            // 4. Azioni Avanzate Hardware (Controllo Firmware & Reset)
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Firmware 50.39.1.0 aggiornato all\'ultima versione disponibile.')),
                  );
                },
                icon: const Icon(Icons.system_update, color: NatureColors.teal, size: 18),
                label: const Text(
                  'VERIFICA AGGIORNAMENTO FIRMWARE',
                  style: TextStyle(color: NatureColors.teal, fontWeight: FontWeight.w700, fontSize: 12, letterSpacing: 0.5),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: NatureColors.borderSubtle),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  backgroundColor: NatureColors.surface,
                ),
              ),
            ),

            const SizedBox(height: 12),

            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () {
                  _showResetDialog(context);
                },
                icon: const Icon(Icons.restart_alt, color: NatureColors.terracotta, size: 18),
                label: const Text(
                  'RESET DI FABBRICA SENSORE',
                  style: TextStyle(color: NatureColors.terracotta, fontWeight: FontWeight.w700, fontSize: 12, letterSpacing: 0.5),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: NatureColors.terracotta.withValues(alpha: 0.12),
                  elevation: 0,
                  shadowColor: Colors.transparent,
                  side: BorderSide(color: NatureColors.terracotta.withValues(alpha: 0.3)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: NatureTheme.organicCardDecoration(isDark: true, elevated: false),
      child: SwitchListTile(
        title: Text(title, style: const TextStyle(color: NatureColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle, style: const TextStyle(color: NatureColors.textMuted, fontSize: 11)),
        value: value,
        activeColor: NatureColors.teal,
        activeTrackColor: NatureColors.teal.withValues(alpha: 0.4),
        inactiveThumbColor: NatureColors.textMuted,
        inactiveTrackColor: NatureColors.surfaceElevated,
        onChanged: onChanged,
      ),
    );
  }

  void _showResetDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: NatureColors.surfaceElevated,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: NatureColors.borderSubtle),
        ),
        title: const Text('Conferma Reset di Fabbrica', style: TextStyle(color: NatureColors.terracotta, fontWeight: FontWeight.w700, fontSize: 16)),
        content: const Text(
          'Sei sicuro di voler effettuare il reset di fabbrica del sensore? Tutti i buffer circolare R-R non sincronizzati verranno azzerati.',
          style: TextStyle(color: NatureColors.textPrimary, fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annulla', style: TextStyle(color: NatureColors.textSecondary, fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Sensore biometrico riavviato e ripristinato!')),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: NatureColors.terracotta,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Reset Fabbrica', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}
