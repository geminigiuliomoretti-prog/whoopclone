import 'package:flutter/material.dart';
import '../../core/constants/whoop_theme.dart';
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
        statusColor = WhoopTheme.recoveryGreen;
        statusText = 'CONNETTO A WHOOP';
        break;
      case BleState.scanning:
        statusColor = WhoopTheme.strainBlue;
        statusText = 'SCANSIONE IN CORSO...';
        break;
      case BleState.connecting:
        statusColor = WhoopTheme.strainBlue;
        statusText = 'CONNESSIONE IN CORSO...';
        break;
      case BleState.bonding:
        statusColor = WhoopTheme.recoveryYellow;
        statusText = 'PAIRING (BONDING)...';
        break;
      case BleState.reconnecting:
        statusColor = WhoopTheme.recoveryYellow;
        statusText = 'RICONNESSIONE AUTOMATICA...';
        break;
      case BleState.error:
        statusColor = WhoopTheme.recoveryRed;
        statusText = 'ERRORE CONNETTO';
        break;
      default:
        statusColor = WhoopTheme.textSecondary;
        statusText = 'DISCONNESSO';
        break;
    }

    return Container(
      decoration: WhoopTheme.officialCardDecoration(),
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
                  isConnected ? Icons.bluetooth_disabled : Icons.bluetooth_searching,
                  size: 16,
                ),
                label: Text(isConnected ? 'Disconnetti' : 'Connetti Whoop'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isConnected ? WhoopTheme.surfaceRaised : WhoopTheme.strainBlue,
                  foregroundColor: isConnected ? WhoopTheme.textPrimary : Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),

          if (viewModel.bleStatusMessage != null) ...[
            const SizedBox(height: 8),
            Text(
              viewModel.bleStatusMessage!,
              style: const TextStyle(color: WhoopTheme.textSecondary, fontSize: 11),
            ),
          ],

          const SizedBox(height: 16),
          const Divider(color: WhoopTheme.cardBorder),
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
                      color: WhoopTheme.textSecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.favorite, color: WhoopTheme.recoveryRed, size: 24),
                      const SizedBox(width: 6),
                      Text(
                        viewModel.liveBpm > 0 ? '${viewModel.liveBpm}' : '--',
                        style: const TextStyle(
                          color: WhoopTheme.textPrimary,
                          fontSize: 28,
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
                      color: WhoopTheme.textSecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    viewModel.liveHrvRmssd > 0
                        ? '${viewModel.liveHrvRmssd.toStringAsFixed(1)} ms'
                        : '-- ms',
                    style: const TextStyle(
                      color: WhoopTheme.recoveryGreen,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
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
                      color: WhoopTheme.textSecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${viewModel.rrBuffer.length}/500',
                    style: const TextStyle(
                      color: WhoopTheme.strainBlue,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
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
                color: WhoopTheme.recoveryYellow.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: WhoopTheme.recoveryYellow.withValues(alpha: 0.4)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: WhoopTheme.recoveryYellow, size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Graceful Fallback Attivo: Streaming su Heart Rate Broadcast 0x2A37',
                      style: TextStyle(
                        color: WhoopTheme.recoveryYellow,
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
              'Proprietary Whoop Stream: Pacchetto #${viewModel.last96BytePacket!.sequenceNumber} (96 byte)',
              style: const TextStyle(color: WhoopTheme.strainBlue, fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }
}
