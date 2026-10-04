import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/whoop_theme.dart';
import '../../data/ble/ble_connection_manager.dart';
import '../../viewmodels/whoop_viewmodel.dart';

/// Schermata Dedicata per la Connessione ed Abbinamento della Banda WHOOP BLE (Ispirata alla Repo NOOP)
class StrapConnectionScreen extends StatefulWidget {
  const StrapConnectionScreen({super.key});

  static Future<void> navigateTo(BuildContext context) {
    return Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const StrapConnectionScreen()),
    );
  }

  @override
  State<StrapConnectionScreen> createState() => _StrapConnectionScreenState();
}

class _StrapConnectionScreenState extends State<StrapConnectionScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = Provider.of<WhoopViewModel>(context);
    final isConnected = viewModel.bleState == BleState.connected;
    final isScanning = viewModel.bleState == BleState.scanning;

    return Scaffold(
      backgroundColor: WhoopTheme.background,
      appBar: AppBar(
        backgroundColor: WhoopTheme.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'CONNETTI DISPOSITIVO WHOOP',
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Radar Visualizer & Connection Header Status
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24.0),
                child: Column(
                  children: [
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        if (isScanning)
                          FadeTransition(
                            opacity: Tween(begin: 0.2, end: 0.8).animate(_pulseController),
                            child: Container(
                              width: 140,
                              height: 140,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: WhoopTheme.strainBlue.withValues(alpha: 0.2),
                              ),
                            ),
                          ),
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: WhoopTheme.cardSurface,
                            border: Border.all(
                              color: isConnected
                                  ? WhoopTheme.recoveryGreen
                                  : (isScanning ? WhoopTheme.strainBlue : WhoopTheme.cardBorder),
                              width: 2.5,
                            ),
                          ),
                          child: Icon(
                            isConnected ? Icons.bluetooth_connected : Icons.watch,
                            size: 44,
                            color: isConnected
                                ? WhoopTheme.recoveryGreen
                                : (isScanning ? WhoopTheme.strainBlue : WhoopTheme.textMuted),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      isConnected
                          ? 'WHOOP 5.0 CONNESSO'
                          : (isScanning ? 'RICERCA SENSORE IN CORSO...' : 'NESSUN DISPOSITIVO ABBINATO'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      isConnected
                          ? 'Streaming telemetria 1Hz attivo (GATT Batteria & HR)'
                          : 'Assicurati che il cinturino sia carico e vicino al telefono',
                      style: const TextStyle(color: WhoopTheme.textMuted, fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 10),

            // 2. Action Scan / Connect Button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: isScanning
                    ? null
                    : () async {
                        if (isConnected) {
                          await viewModel.disconnectBle();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Dispositivo WHOOP disconnesso.')),
                            );
                          }
                        } else {
                          await viewModel.startBleScan();
                        }
                      },
                icon: Icon(
                  isConnected ? Icons.bluetooth_disabled : Icons.bluetooth_searching,
                  color: isConnected ? Colors.white : Colors.black,
                ),
                label: Text(
                  isConnected ? 'DISCONNETTI STRAP' : 'AVVIA SCANSIONE BLE',
                  style: TextStyle(
                    color: isConnected ? Colors.white : Colors.black,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                    letterSpacing: 1.0,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isConnected ? WhoopTheme.recoveryRed : Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                  elevation: isConnected ? 0 : 4,
                ),
              ),
            ),

            const SizedBox(height: 28),

            // 3. Status Card Hardware Details (NOOP Protocol Specs)
            const Text(
              'INFORMAZIONI HARDWARE & TELEMETRIA',
              style: TextStyle(
                color: WhoopTheme.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 12),

            Container(
              padding: const EdgeInsets.all(18),
              decoration: WhoopTheme.officialCardDecoration(),
              child: Column(
                children: [
                  _buildDetailRow(
                    label: 'Stato Batteria',
                    value: viewModel.batteryPct != null ? '${viewModel.batteryPct}%' : '--%',
                    statusColor: viewModel.batteryPct != null ? WhoopTheme.recoveryGreen : WhoopTheme.textMuted,
                  ),
                  const Divider(color: WhoopTheme.cardBorder, height: 20),
                  _buildDetailRow(
                    label: 'Modello Hardware',
                    value: 'WHOOP 5.0 (WP5)',
                    statusColor: Colors.white,
                  ),
                  const Divider(color: WhoopTheme.cardBorder, height: 20),
                  _buildDetailRow(
                    label: 'UUID Servizi GATT',
                    value: 'fd4b0001 / 61080001 (NOOP Engine)',
                    statusColor: Colors.white,
                  ),
                  const Divider(color: WhoopTheme.cardBorder, height: 20),
                  _buildDetailRow(
                    label: 'Frequenza Cardiaca Live',
                    value: viewModel.liveBpm > 0 ? '${viewModel.liveBpm} BPM' : '-- BPM',
                    statusColor: viewModel.liveBpm > 0 ? WhoopTheme.strainBlue : WhoopTheme.textMuted,
                  ),
                  const Divider(color: WhoopTheme.cardBorder, height: 20),
                  _buildDetailRow(
                    label: 'Sveglia Haptic',
                    value: 'Sveglia Silenziosa Configuarata',
                    statusColor: WhoopTheme.recoveryGreen,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // 4. Test Sveglia Haptic & Vibrazione (Da HapticClockEncoder NOOP)
            if (isConnected) ...[
              const Text(
                'CONTROLLI HARDWARE HAPTIC',
                style: TextStyle(
                  color: WhoopTheme.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final nextAlarm = DateTime.now().add(const Duration(minutes: 30));
                    await viewModel.scheduleHapticAlarm(nextAlarm);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Sveglia haptic programmata per le ${nextAlarm.hour}:${nextAlarm.minute.toString().padLeft(2, '0')}')),
                      );
                    }
                  },
                  icon: const Icon(Icons.alarm_on, color: WhoopTheme.strainBlue, size: 18),
                  label: const Text(
                    'INVIA TEST SVEGLIA VIBRAZIONE HARDWARE',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: WhoopTheme.strainBlue),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(23)),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow({
    required String label,
    required String value,
    required Color statusColor,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: WhoopTheme.textMuted, fontSize: 12)),
        Text(
          value,
          style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
