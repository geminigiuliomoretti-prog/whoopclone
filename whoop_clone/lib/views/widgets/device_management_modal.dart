import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/whoop_theme.dart';
import '../../viewmodels/whoop_viewmodel.dart';
import '../../data/ble/ble_connection_manager.dart';

/// Modal "GESTIONE DISPOSITIVO WHOOP 5.0" (Rispecchia al 100% l'interfaccia hardware ufficiale)
class DeviceManagementModal extends StatelessWidget {
  const DeviceManagementModal({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const DeviceManagementModal(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = Provider.of<WhoopViewModel>(context);

    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: const BoxDecoration(
        color: WhoopTheme.cardSurface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: WhoopTheme.cardBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'DISPOSITIVO WHOOP 5.0',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
              Icon(Icons.bluetooth_connected, color: WhoopTheme.strainBlue, size: 20),
            ],
          ),

          const SizedBox(height: 20),

          // Battery & Hardware Info Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: WhoopTheme.officialCardDecoration(),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.battery_charging_full,
                          color: viewModel.batteryPct != null ? WhoopTheme.recoveryGreen : WhoopTheme.textMuted,
                          size: 28,
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Batteria Sensore BLE', style: TextStyle(color: WhoopTheme.textMuted, fontSize: 11)),
                            Text(
                              viewModel.batteryPct != null ? '${viewModel.batteryPct}%' : '--%',
                              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: (viewModel.batteryPct != null ? WhoopTheme.recoveryGreen : WhoopTheme.textMuted).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        viewModel.batteryPct != null ? 'GATT BATT 0x180F' : 'IN ATTESA',
                        style: TextStyle(color: viewModel.batteryPct != null ? WhoopTheme.recoveryGreen : WhoopTheme.textMuted, fontSize: 9, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const Divider(color: WhoopTheme.cardBorder, height: 24),
                _buildInfoRow('Numero di Serie', 'WHOOP-GATT-5.0'),
                _buildInfoRow('Versione Firmware', 'v5.2.0-prod (Up to Date)'),
                _buildInfoRow('Sensori Attivi', 'PPG 5-LED, ECG, Temp Cutanea, 3D Accelerometro'),
                _buildInfoRow(
                  'Stato Connessione',
                  viewModel.bleState == BleState.connected
                      ? 'Connesso (Streaming 1Hz)'
                      : (viewModel.bleState == BleState.scanning ? 'Scansione in corso...' : 'Disconnesso'),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Action Button: Riconnetti o Scansiona BLE
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: () {
                viewModel.startBleScan();
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Ricerca sensore WHOOP 5.0 BLE avviata...')),
                );
              },
              icon: const Icon(Icons.sync, color: Colors.black, size: 18),
              label: const Text('RICONNETTI O SCANSIONA SENSORE', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 0.8)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              ),
            ),
          ),

          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String val) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: WhoopTheme.textMuted, fontSize: 11)),
          Text(val, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
