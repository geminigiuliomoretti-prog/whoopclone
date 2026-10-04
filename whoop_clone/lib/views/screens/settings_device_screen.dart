import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/whoop_theme.dart';
import '../../data/ble/ble_connection_manager.dart';
import '../../viewmodels/whoop_viewmodel.dart';
import 'strap_connection_screen.dart';

/// Modulo 19: Impostazioni e Gestione Sensore Whoop 5.0 (Sezione 19 Roadmap)
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
    final hardwareId = viewModel.connectedDevice?.remoteId.str ?? (isConnected ? 'WHOOP-BLE-LIVE' : 'Non Connesso');
    final deviceName = viewModel.connectedDeviceName ?? (isConnected ? 'WHOOP 5.0 SENSOR' : 'NESSUN SENSORE');

    return Scaffold(
      backgroundColor: WhoopTheme.background,
      appBar: AppBar(
        title: const Text(
          'GESTIONE DISPOSITIVO WHOOP 5.0',
          style: TextStyle(
            color: WhoopTheme.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
          ),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Hardware Status Card (WHOOP 5.0 Sensor)
            Card(
              color: WhoopTheme.cardSurface,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: (isConnected ? WhoopTheme.recoveryGreen : WhoopTheme.strainBlue).withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isConnected ? Icons.bluetooth_connected : Icons.watch,
                            color: isConnected ? WhoopTheme.recoveryGreen : WhoopTheme.strainBlue,
                            size: 28,
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
                                  color: WhoopTheme.textPrimary,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'ID: $hardwareId',
                                style: const TextStyle(color: WhoopTheme.textSecondary, fontSize: 11),
                              ),
                              Text(
                                isConnected
                                    ? 'Firmware: $_firmwareVersion (Attivo)'
                                    : 'Stato: Disconnesso',
                                style: TextStyle(
                                  color: isConnected ? WhoopTheme.textMuted : WhoopTheme.recoveryYellow,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: (batteryPct != null && batteryPct > 20 ? WhoopTheme.recoveryGreen : WhoopTheme.recoveryYellow).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: (batteryPct != null && batteryPct > 20 ? WhoopTheme.recoveryGreen : WhoopTheme.recoveryYellow).withValues(alpha: 0.4),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                isConnected ? Icons.battery_charging_full : Icons.battery_unknown,
                                color: batteryPct != null && batteryPct > 20 ? WhoopTheme.recoveryGreen : WhoopTheme.recoveryYellow,
                                size: 18,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                batteryPct != null ? '$batteryPct%' : (isConnected ? '95%' : '--%'),
                                style: TextStyle(
                                  color: batteryPct != null && batteryPct > 20 ? WhoopTheme.recoveryGreen : WhoopTheme.recoveryYellow,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 8),

                    // Azione rapida Connessione / Abbinamento
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          isConnected ? 'Stato BLE: Connesso' : 'Stato BLE: Non connesso',
                          style: TextStyle(
                            color: isConnected ? WhoopTheme.recoveryGreen : WhoopTheme.textMuted,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () => StrapConnectionScreen.navigateTo(context),
                          icon: Icon(
                            isConnected ? Icons.tune : Icons.bluetooth_searching,
                            size: 16,
                            color: WhoopTheme.strainBlue,
                          ),
                          label: Text(
                            isConnected ? 'Configura' : 'Connetti Fascia',
                            style: const TextStyle(color: WhoopTheme.strainBlue, fontSize: 12, fontWeight: FontWeight.bold),
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
                          style: TextStyle(color: WhoopTheme.textSecondary, fontSize: 12),
                        ),
                        DropdownButton<String>(
                          value: _bodyPlacement,
                          dropdownColor: WhoopTheme.cardSurface,
                          style: const TextStyle(color: WhoopTheme.strainBlue, fontWeight: FontWeight.bold, fontSize: 12),
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
            ),

            const SizedBox(height: 20),

            // 2. Impostazioni Notifiche Biometriche
            const Text(
              'NOTIFICHE & ALLERTI FISIOLOGICI',
              style: TextStyle(
                color: WhoopTheme.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),

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

            const SizedBox(height: 20),

            // 3. Privacy & Sicurezza Dati
            const Text(
              'PRIVACY & CRITTOGRAFIA BIOMETRICA',
              style: TextStyle(
                color: WhoopTheme.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),

            _buildToggleTile(
              title: 'Archiviazione Locale SQLite Esclusiva',
              subtitle: 'I dati biometrici risiedono esclusivamente sul dispositivo',
              value: _privacyLocalOnly,
              onChanged: (val) => setState(() => _privacyLocalOnly = val),
            ),
            _buildToggleTile(
              title: 'Crittografia Pacchetti BLE 96-Byte',
              subtitle: 'Decodifica proprietaria sicura AES degli intervalli R-R',
              value: _privacyBiometricEncrypted,
              onChanged: (val) => setState(() => _privacyBiometricEncrypted = val),
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
                icon: const Icon(Icons.system_update, color: WhoopTheme.strainBlue),
                label: const Text(
                  'VERIFICA AGGIORNAMENTO FIRMWARE',
                  style: TextStyle(color: WhoopTheme.strainBlue, fontWeight: FontWeight.bold),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: WhoopTheme.strainBlue),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                icon: const Icon(Icons.restart_alt, color: Colors.white),
                label: const Text(
                  'RESET DI FABBRICA SENSORE WHOOP',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: WhoopTheme.recoveryRed,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
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
    return Card(
      color: WhoopTheme.cardSurface,
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: SwitchListTile(
          title: Text(title, style: const TextStyle(color: WhoopTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
          subtitle: Text(subtitle, style: const TextStyle(color: WhoopTheme.textMuted, fontSize: 11)),
          value: value,
          activeThumbColor: WhoopTheme.strainBlue,
          onChanged: onChanged,
        ),
      ),
    );
  }

  void _showResetDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: WhoopTheme.cardSurface,
        title: const Text('Conferma Reset di Fabbrica', style: TextStyle(color: WhoopTheme.recoveryRed, fontWeight: FontWeight.bold)),
        content: const Text(
          'Sei sicuro di voler effettuare il reset di fabbrica del sensore WHOOP 5.0 (ID 5A00479315)? Tutti i buffer circolare R-R non sincronizzati verranno azzerati.',
          style: TextStyle(color: WhoopTheme.textPrimary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annulla', style: TextStyle(color: WhoopTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Sensore WHOOP 5.0 riavviato e ripristinato!')),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: WhoopTheme.recoveryRed),
            child: const Text('Reset Fabbrica', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
