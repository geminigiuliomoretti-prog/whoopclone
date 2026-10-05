import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../../core/constants/whoop_theme.dart';
import '../../data/ble/ble_connection_manager.dart';
import '../../viewmodels/whoop_viewmodel.dart';
import '../screens/diagnostic_screen.dart';

/// Schermata Dedicata Gestione e Connessione Dispositivo WHOOP (`/device`)
class DeviceScreen extends StatefulWidget {
  const DeviceScreen({super.key});

  static Future<void> navigateTo(BuildContext context) {
    return Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const DeviceScreen()),
    );
  }

  @override
  State<DeviceScreen> createState() => _DeviceScreenState();
}

class _DeviceScreenState extends State<DeviceScreen> with SingleTickerProviderStateMixin {
  late AnimationController _radarController;
  BluetoothDevice? _connectingDevice;

  @override
  void initState() {
    super.initState();
    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _radarController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = Provider.of<WhoopViewModel>(context);
    final isConnected = viewModel.bleState == BleState.connected;
    final isConnecting = viewModel.bleState == BleState.connecting || _connectingDevice != null;
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
          'DISPOSITIVO WHOOP',
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.troubleshoot, color: WhoopTheme.strainBlue),
            tooltip: 'Diagnostica BLE & Raw Capture',
            onPressed: () => DiagnosticScreen.navigateTo(context),
          ),
        ],
      ),
      body: isConnected
          ? _buildConnectedDashboard(context, viewModel)
          : _buildDisconnectedScanView(context, viewModel, isScanning, isConnecting),
    );
  }

  // ==========================================
  // STATO C: DISPOSITIVO CONNESSO (DEVICE DASHBOARD)
  // ==========================================
  Widget _buildConnectedDashboard(BuildContext context, WhoopViewModel viewModel) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner Stato Connesso
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: WhoopTheme.recoveryGreen.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: WhoopTheme.recoveryGreen.withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(
                    color: WhoopTheme.recoveryGreen,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.bluetooth_connected, color: Colors.black, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'WHOOP 5.0 CONNESSO',
                        style: TextStyle(
                          color: WhoopTheme.recoveryGreen,
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        viewModel.connectedDevice?.platformName.isNotEmpty == true
                            ? viewModel.connectedDevice!.platformName
                            : 'Sensore WHOOP - Connection Active',
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Metriche Live (Batteria GATT + HR 1Hz)
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: WhoopTheme.officialCardDecoration(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.battery_charging_full, color: WhoopTheme.recoveryGreen, size: 20),
                          SizedBox(width: 6),
                          Text('BATTERIA', style: TextStyle(color: WhoopTheme.textMuted, fontSize: 10, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        viewModel.batteryPct != null ? '${viewModel.batteryPct}%' : '--%',
                        style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        viewModel.batteryPct != null ? 'GATT Service 0x180F' : 'In attesa segnale',
                        style: const TextStyle(color: WhoopTheme.textMuted, fontSize: 10),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: WhoopTheme.officialCardDecoration(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.favorite, color: WhoopTheme.strainBlue, size: 20),
                          SizedBox(width: 6),
                          Text('CARDIO LIVE', style: TextStyle(color: WhoopTheme.textMuted, fontSize: 10, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        viewModel.liveBpm > 0 ? '${viewModel.liveBpm} BPM' : '-- BPM',
                        style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Streaming 1Hz Attivo',
                        style: TextStyle(color: WhoopTheme.textMuted, fontSize: 10),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Diagnostic Hardware Info
          const Text(
            'DETTAGLI HARDWARE & DIAGNOSTICA',
            style: TextStyle(
              color: WhoopTheme.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: WhoopTheme.officialCardDecoration(),
            child: Column(
              children: [
                _buildInfoTile('Numero di Serie', 'WP5-98412-BLE'),
                const Divider(color: WhoopTheme.cardBorder, height: 20),
                _buildInfoTile('Versione Firmware', 'v5.2.0-prod (Up to Date)'),
                const Divider(color: WhoopTheme.cardBorder, height: 20),
                _buildInfoTile('Canale Telemetria', 'Proprietario 96-Byte (0x6108 / 0xfd4b)'),
                const Divider(color: WhoopTheme.cardBorder, height: 20),
                _buildInfoTile('Sveglia Haptic', 'Sveglia Silenziosa Configurata'),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Pulsante Test Vibrazione Haptic 20-Byte (Vibra Ora T+2s)
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: () async {
                final success = await viewModel.sendTestVibrationPulseNow();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        success
                            ? '⚡ Pulsazione Prova Inviata! Il cinturino vibrerà tra 2 secondi (Handle 0x0010)...'
                            : '⚠️ Impossibile inviare il comando di vibrazione BLE.',
                      ),
                      backgroundColor: success ? WhoopTheme.recoveryGreen : Colors.orange,
                    ),
                  );
                }
              },
              icon: const Icon(Icons.flash_on, color: Colors.black),
              label: const Text(
                '⚡ Invia Pulsazione Prova (Vibra Ora)',
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                  letterSpacing: 0.8,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: WhoopTheme.recoveryGreen,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Pulsante Test Vibrazione Haptic Multi-Impulso
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: () async {
                final result = await viewModel.bleManager.sendHapticVibrationCommand(pattern: 2);
                if (context.mounted) {
                  final String msg;
                  final Color bg;
                  if (result.isStrapSuccess) {
                    msg = '⚡ Sequenza Vibrazione inviata allo strap WHOOP.';
                    bg = WhoopTheme.strainBlue;
                  } else if (result == HapticResultStatus.phoneHapticOnly) {
                    msg = '📱 Vibrazione eseguita solo su smartphone (Strap non connesso).';
                    bg = Colors.amber.shade800;
                  } else if (result == HapticResultStatus.strapFailed) {
                    msg = '⚠️ Invio comando haptic alla strap fallito.';
                    bg = Colors.redAccent;
                  } else {
                    msg = '⚠️ Nessun dispositivo connesso.';
                    bg = Colors.orange;
                  }
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(msg),
                      backgroundColor: bg,
                    ),
                  );
                }
              },
              icon: const Icon(Icons.vibration, color: Colors.black),
              label: const Text(
                'TEST VIBRAZIONE HAPTIC (3 Impulsi)',
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                  letterSpacing: 0.8,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: WhoopTheme.strainBlue,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),

          const SizedBox(height: 24),

          // BLE Debug Console (Scrittura GATT & Hex Payload)
          const Text(
            'BLE DEBUG CONSOLE (LOG TRASMISSIONI TX)',
            style: TextStyle(
              color: WhoopTheme.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 10),

          StreamBuilder<List<String>>(
            stream: viewModel.debugLogsStream,
            initialData: viewModel.debugLogs,
            builder: (context, snapshot) {
              final logs = snapshot.data ?? viewModel.debugLogs;
              return Container(
                width: double.infinity,
                height: 180,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: WhoopTheme.cardBorder),
                ),
                child: logs.isEmpty
                    ? const Center(
                        child: Text(
                          'In attesa di trasmissioni BLE su CMD_TO_STRAP (0x0010)...',
                          style: TextStyle(color: WhoopTheme.textMuted, fontSize: 11, fontFamily: 'monospace'),
                        ),
                      )
                    : ListView.separated(
                        physics: const BouncingScrollPhysics(),
                        itemCount: logs.length,
                        separatorBuilder: (context, index) => const Divider(color: Colors.white12, height: 8),
                        itemBuilder: (context, index) {
                          final logLine = logs[logs.length - 1 - index];
                          final isError = logLine.contains('ERROR');
                          final isSuccess = logLine.contains('SUCCESS');
                          return Text(
                            logLine,
                            style: TextStyle(
                              color: isError
                                  ? WhoopTheme.recoveryRed
                                  : (isSuccess ? WhoopTheme.recoveryGreen : Colors.white70),
                              fontSize: 10,
                              fontFamily: 'monospace',
                            ),
                          );
                        },
                      ),
              );
            },
          ),

          // Pulsante Diagnostica Avanzata & Raw Capture
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              onPressed: () => DiagnosticScreen.navigateTo(context),
              icon: const Icon(Icons.troubleshoot, color: WhoopTheme.strainBlue),
              label: const Text(
                'DIAGNOSTICA BLE & RAW CAPTURE',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                  letterSpacing: 1.0,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: WhoopTheme.strainBlue, width: 1.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),

          const SizedBox(height: 14),

          // Pulsante Rosso Disconnetti
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: () async {
                await viewModel.disconnectBle();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Dispositivo WHOOP disconnesso.')),
                  );
                }
              },
              icon: const Icon(Icons.bluetooth_disabled, color: Colors.white),
              label: const Text(
                'DISCONNETTI DISPOSITIVO',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1.0),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: WhoopTheme.recoveryRed,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // STATO A & B: DISCONNESSO / SCANSIONE DISPOSITIVI BLE
  // ==========================================
  Widget _buildDisconnectedScanView(
    BuildContext context,
    WhoopViewModel viewModel,
    bool isScanning,
    bool isConnecting,
  ) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              // Radar Visualizer Header
              Stack(
                alignment: Alignment.center,
                children: [
                  if (isScanning)
                    FadeTransition(
                      opacity: Tween(begin: 0.2, end: 0.8).animate(_radarController),
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: WhoopTheme.strainBlue.withValues(alpha: 0.15),
                        ),
                      ),
                    ),
                  Container(
                    width: 84,
                    height: 84,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: WhoopTheme.cardSurface,
                      border: Border.all(
                        color: isScanning ? WhoopTheme.strainBlue : WhoopTheme.cardBorder,
                        width: 2,
                      ),
                    ),
                    child: Icon(
                      isScanning ? Icons.bluetooth_searching : Icons.watch,
                      size: 36,
                      color: isScanning ? WhoopTheme.strainBlue : WhoopTheme.textMuted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              Text(
                isScanning ? 'SCANSIONE DISPOSITIVI BLE...' : 'CERCA DISPOSITIVO WHOOP',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Avvia la scansione e seleziona il tuo cinturino dalla lista nelle vicinanze',
                style: TextStyle(color: WhoopTheme.textMuted, fontSize: 11),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),

              // Pulsante Alto Contrasto Cerca Dispositivi BLE
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: isScanning ? null : () => viewModel.startScanOnly(),
                  icon: Icon(
                    isScanning ? Icons.sync : Icons.search,
                    color: Colors.black,
                  ),
                  label: Text(
                    isScanning ? 'SCANSIONE IN CORSO...' : 'CERCA DISPOSITIVI BLE',
                    style: const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                      letterSpacing: 0.8,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Banner di verifica stato Bluetooth & Permessi
        FutureBuilder<BluetoothAdapterState>(
          future: FlutterBluePlus.adapterState.first,
          builder: (context, snapshot) {
            if (snapshot.hasData && snapshot.data != BluetoothAdapterState.on) {
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: WhoopTheme.recoveryRed.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: WhoopTheme.recoveryRed),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.bluetooth_disabled, color: WhoopTheme.recoveryRed, size: 20),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Bluetooth disattivato o permessi mancanti.',
                        style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                    TextButton(
                      onPressed: () async {
                        await viewModel.startScanOnly();
                      },
                      child: const Text('ATTIVA', style: TextStyle(color: WhoopTheme.strainBlue, fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              );
            }
            return const SizedBox.shrink();
          },
        ),

        const Divider(color: WhoopTheme.cardBorder, height: 1),

        // Stream Lista Dispositivi Trovati (ListView.builder)
        Expanded(
          child: StreamBuilder<List<ScanResult>>(
            stream: viewModel.scanResultsStream,
            builder: (context, snapshot) {
              final results = snapshot.data ?? [];

              // Ordina la lista mettendo i dispositivi WHOOP / Cardio in cima
              final sorted = List<ScanResult>.from(results)..sort((a, b) {
                final nameA = (a.device.platformName + a.advertisementData.advName).toUpperCase();
                final nameB = (b.device.platformName + b.advertisementData.advName).toUpperCase();
                bool isWhoopA = nameA.contains('WHOOP') || nameA.contains('CARDIO');
                bool isWhoopB = nameB.contains('WHOOP') || nameB.contains('CARDIO');
                if (isWhoopA && !isWhoopB) return -1;
                if (!isWhoopA && isWhoopB) return 1;
                return b.rssi.compareTo(a.rssi);
              });

              if (sorted.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        isScanning ? Icons.radar : Icons.bluetooth_searching,
                        size: 44,
                        color: WhoopTheme.textMuted.withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        isScanning
                            ? 'Scansione BLE in corso... Assicurati che il Bluetooth e la Posizione siano attivi.'
                            : 'Nessun dispositivo rilevato nelle vicinanze.\nClicca su "CERCA DISPOSITIVI BLE".',
                        style: const TextStyle(color: WhoopTheme.textMuted, fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: sorted.length,
                separatorBuilder: (context, index) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final result = sorted[index];
                  final namePlatform = result.device.platformName;
                  final nameAdv = result.advertisementData.advName;
                  final deviceName = namePlatform.isNotEmpty
                      ? namePlatform
                      : (nameAdv.isNotEmpty ? nameAdv : 'Dispositivo BLE Sconosciuto');
                  final macId = result.device.remoteId.str;
                  final rssi = result.rssi;
                  final isWhoop = deviceName.toUpperCase().contains('WHOOP');

                  return Container(
                    decoration: WhoopTheme.officialCardDecoration(),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isWhoop ? WhoopTheme.recoveryGreen.withValues(alpha: 0.2) : WhoopTheme.strainBlue.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isWhoop ? Icons.watch : Icons.bluetooth,
                          color: isWhoop ? WhoopTheme.recoveryGreen : WhoopTheme.strainBlue,
                          size: 22,
                        ),
                      ),
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              deviceName,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isWhoop)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: WhoopTheme.recoveryGreen.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text('WHOOP', style: TextStyle(color: WhoopTheme.recoveryGreen, fontSize: 9, fontWeight: FontWeight.bold)),
                            ),
                        ],
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                          children: [
                            Text(macId, style: const TextStyle(color: WhoopTheme.textMuted, fontSize: 11)),
                            const SizedBox(width: 10),
                            Icon(Icons.signal_cellular_alt, color: _getRssiColor(rssi), size: 14),
                            const SizedBox(width: 2),
                            Text('$rssi dBm', style: TextStyle(color: _getRssiColor(rssi), fontSize: 11)),
                          ],
                        ),
                      ),
                      trailing: ElevatedButton(
                        onPressed: isConnecting
                            ? null
                            : () async {
                                setState(() => _connectingDevice = result.device);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    duration: const Duration(seconds: 3),
                                    content: Text('Connessione in corso a $deviceName...'),
                                  ),
                                );

                                await viewModel.connectToDevice(result.device);
                                if (mounted) {
                                  setState(() => _connectingDevice = null);
                                  if (viewModel.bleState == BleState.connected) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        backgroundColor: WhoopTheme.recoveryGreen,
                                        content: Text('Connesso con successo a $deviceName!'),
                                      ),
                                    );
                                  } else if (viewModel.statusMessage != null) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        backgroundColor: WhoopTheme.recoveryRed,
                                        content: Text(viewModel.statusMessage!),
                                      ),
                                    );
                                  }
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: WhoopTheme.strainBlue,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        ),
                        child: Text(
                          _connectingDevice == result.device ? 'Connessione...' : 'Connetti',
                          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Color _getRssiColor(int rssi) {
    if (rssi > -65) return WhoopTheme.recoveryGreen;
    if (rssi > -80) return WhoopTheme.recoveryYellow;
    return WhoopTheme.recoveryRed;
  }

  Widget _buildInfoTile(String label, String val) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: WhoopTheme.textMuted, fontSize: 12)),
        Text(val, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
