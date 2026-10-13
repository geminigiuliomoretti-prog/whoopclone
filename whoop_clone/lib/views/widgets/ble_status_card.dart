import 'package:flutter/material.dart';
import '../../core/theme/nature_theme.dart';
import '../../data/ble/ble_connection_manager.dart';
import '../../viewmodels/whoop_viewmodel.dart';

class BleStatusCard extends StatelessWidget {
  final WhoopViewModel viewModel;

  const BleStatusCard({
    super.key,
    required this.viewModel,
  });

  @override
  Widget build(BuildContext context) {
    final state = viewModel.bleState;
    final isConnected = state == BleState.connected;
    final isConnecting = state == BleState.scanning ||
        state == BleState.connecting ||
        state == BleState.bonding ||
        state == BleState.reconnecting;

    Color statusColor;
    String statusText;

    switch (state) {
      case BleState.connected:
        statusColor = NatureColors.recoveryAccent;
        statusText = 'CONNESSO AL DISPOSITIVO';
        break;
      case BleState.scanning:
        statusColor = NatureColors.teal;
        statusText = 'SCANSIONE IN CORSO...';
        break;
      case BleState.connecting:
        statusColor = NatureColors.teal;
        statusText = 'CONNESSIONE IN CORSO...';
        break;
      case BleState.bonding:
        statusColor = NatureColors.amberWarm;
        statusText = 'PAIRING (BONDING)...';
        break;
      case BleState.reconnecting:
        statusColor = NatureColors.amberWarm;
        statusText = 'RICONNESSIONE AUTOMATICA...';
        break;
      case BleState.error:
        statusColor = NatureColors.terracotta;
        statusText = 'ERRORE CONNESSIONE';
        break;
      default:
        statusColor = NatureColors.textDarkMuted;
        statusText = 'DISCONNESSO';
        break;
    }

    return Container(
      decoration: NatureTheme.organicCardDecoration(isDark: true),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: statusColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    statusText,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: isConnecting
                    ? null
                    : () {
                        if (isConnected) {
                          viewModel.disconnectBle();
                        } else {
                          viewModel.startBleScan();
                        }
                      },
                icon: Icon(
                  isConnected ? Icons.bluetooth_disabled_rounded : Icons.bluetooth_searching_rounded,
                  size: 16,
                  color: isConnected ? NatureColors.textDarkPrimary : Colors.white,
                ),
                label: Text(
                  isConnected ? 'Disconnetti' : 'Connetti Dispositivo',
                  style: TextStyle(
                    color: isConnected ? NatureColors.textDarkPrimary : Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isConnected ? NatureColors.surfaceElevated : NatureColors.teal,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: isConnected ? NatureColors.border : Colors.transparent,
                    ),
                  ),
                  elevation: 0,
                  textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),

          if (viewModel.bleStatusMessage != null) ...[
            const SizedBox(height: 8),
            Text(
              viewModel.bleStatusMessage!,
              style: const TextStyle(color: NatureColors.textDarkMuted, fontSize: 11),
            ),
          ],

          const SizedBox(height: 16),
          const Divider(color: NatureColors.borderSubtle),
          const SizedBox(height: 12),

          // Live Heart Rate & R-R Buffer Metrics
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              // Live BPM
              Column(
                children: [
                  const Text(
                    'BPM LIVE',
                    style: TextStyle(
                      color: NatureColors.textDarkMuted,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.favorite_rounded, color: NatureColors.terracotta, size: 22),
                      const SizedBox(width: 6),
                      Text(
                        viewModel.liveBpm > 0 ? '${viewModel.liveBpm}' : '--',
                        style: const TextStyle(
                          color: NatureColors.textDarkPrimary,
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              // Live HRV rMSSD
              Column(
                children: [
                  const Text(
                    'VFC / HRV (rMSSD)',
                    style: TextStyle(
                      color: NatureColors.textDarkMuted,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    viewModel.liveHrvRmssd > 0
                        ? '${viewModel.liveHrvRmssd.toStringAsFixed(1)} ms'
                        : '-- ms',
                    style: const TextStyle(
                      color: NatureColors.recoveryAccent,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),

              // R-R Circular Buffer Count
              Column(
                children: [
                  const Text(
                    'BUFFER R-R',
                    style: TextStyle(
                      color: NatureColors.textDarkMuted,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${viewModel.rrBuffer.length}/500',
                    style: const TextStyle(
                      color: NatureColors.tealLight,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Graceful Fallback Indicator
          if (viewModel.isFallbackMode) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: NatureColors.amberWarm.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: NatureColors.amberWarm.withValues(alpha: 0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline_rounded, color: NatureColors.amberWarm, size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Graceful Fallback Attivo: Streaming su Heart Rate Broadcast 0x2A37',
                      style: TextStyle(
                        color: NatureColors.amberWarm,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // 96-Byte Packet Live Indicator
          if (viewModel.last96BytePacket != null && !viewModel.isFallbackMode) ...[
            const SizedBox(height: 12),
            Text(
              'Telemetria Attiva: Pacchetto #${viewModel.last96BytePacket!.sequenceNumber} (96 byte)',
              style: const TextStyle(color: NatureColors.tealLight, fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }
}
