import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/nature_theme.dart';
import '../../data/ble/ble_connection_manager.dart';
import '../../viewmodels/whoop_viewmodel.dart';

/// Schermata per la Connessione ed Abbinamento del Sensore Biometrico BLE
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
      backgroundColor: NatureColors.background,
      appBar: AppBar(
        backgroundColor: NatureColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: NatureColors.textPrimary, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'CONNETTI DISPOSITIVO',
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
                                color: NatureColors.teal.withValues(alpha: 0.15),
                              ),
                            ),
                          ),
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: NatureColors.surface,
                            border: Border.all(
                              color: isConnected
                                  ? NatureColors.recoveryGreen
                                  : (isScanning ? NatureColors.teal : NatureColors.borderSubtle),
                              width: 2.0,
                            ),
                          ),
                          child: Icon(
                            isConnected ? Icons.bluetooth_connected : Icons.watch,
                            size: 40,
                            color: isConnected
                                ? NatureColors.recoveryGreen
                                : (isScanning ? NatureColors.teal : NatureColors.textMuted),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Text(
                      isConnected
                          ? 'DISPOSITIVO CONNESSO'
                          : (isScanning ? 'RICERCA SENSORE IN CORSO...' : 'NESSUN DISPOSITIVO ABBINATO'),
                      style: const TextStyle(
                        color: NatureColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      isConnected
                          ? 'Streaming telemetria 1Hz attivo (Batteria & HR)'
                          : 'Assicurati che il sensore sia carico e nelle vicinanze',
                      style: const TextStyle(color: NatureColors.textMuted, fontSize: 12),
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
              height: 50,
              child: ElevatedButton.icon(
                onPressed: isScanning
                    ? null
                    : () async {
                        if (isConnected) {
                          await viewModel.disconnectBle();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Dispositivo disconnesso.')),
                            );
                          }
                        } else {
                          await viewModel.startBleScan();
                        }
                      },
                icon: Icon(
                  isConnected ? Icons.bluetooth_disabled : Icons.bluetooth_searching,
                  color: isConnected ? NatureColors.terracotta : NatureColors.background,
                  size: 18,
                ),
                label: Text(
                  isConnected ? 'DISCONNETTI SENSORE' : 'AVVIA SCANSIONE BLE',
                  style: TextStyle(
                    color: isConnected ? NatureColors.terracotta : NatureColors.background,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    letterSpacing: 0.8,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isConnected ? NatureColors.terracotta.withValues(alpha: 0.12) : NatureColors.teal,
                  elevation: 0,
                  side: isConnected ? BorderSide(color: NatureColors.terracotta.withValues(alpha: 0.3)) : BorderSide.none,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),

            const SizedBox(height: 28),

            // 3. Status Card Hardware Details
            const Text(
              'INFORMAZIONI HARDWARE & TELEMETRIA',
              style: TextStyle(
                color: NatureColors.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 12),

            Container(
              padding: const EdgeInsets.all(18),
              decoration: NatureTheme.organicCardDecoration(isDark: true),
              child: Column(
                children: [
                  _buildDetailRow(
                    label: 'Stato Batteria',
                    value: viewModel.batteryPct != null ? '${viewModel.batteryPct}%' : '--%',
                    statusColor: viewModel.batteryPct != null ? NatureColors.recoveryGreen : NatureColors.textMuted,
                  ),
                  const Divider(color: NatureColors.borderSubtle, height: 20),
                  _buildDetailRow(
                    label: 'Modello Hardware',
                    value: 'BLE Sensor v5.0',
                    statusColor: NatureColors.textPrimary,
                  ),
                  const Divider(color: NatureColors.borderSubtle, height: 20),
                  _buildDetailRow(
                    label: 'UUID Servizi GATT',
                    value: 'fd4b0001 / 61080001',
                    statusColor: NatureColors.textPrimary,
                  ),
                  const Divider(color: NatureColors.borderSubtle, height: 20),
                  _buildDetailRow(
                    label: 'Frequenza Cardiaca Live',
                    value: viewModel.liveBpm > 0 ? '${viewModel.liveBpm} BPM' : '-- BPM',
                    statusColor: viewModel.liveBpm > 0 ? NatureColors.teal : NatureColors.textMuted,
                  ),
                  const Divider(color: NatureColors.borderSubtle, height: 20),
                  _buildDetailRow(
                    label: 'Sveglia Haptic',
                    value: 'Sveglia Silenziosa Abilitata',
                    statusColor: NatureColors.recoveryGreen,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // 4. Test Sveglia Haptic & Vibrazione
            if (isConnected) ...[
              const Text(
                'CONTROLLI HARDWARE HAPTIC',
                style: TextStyle(
                  color: NatureColors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 48,
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
                  icon: const Icon(Icons.alarm_on, color: NatureColors.teal, size: 18),
                  label: const Text(
                    'TEST VIBRAZIONE HARDWARE',
                    style: TextStyle(color: NatureColors.teal, fontWeight: FontWeight.w700, fontSize: 12, letterSpacing: 0.5),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: NatureColors.borderSubtle),
                    backgroundColor: NatureColors.surface,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
        Text(label, style: const TextStyle(color: NatureColors.textMuted, fontSize: 12)),
        Text(
          value,
          style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
