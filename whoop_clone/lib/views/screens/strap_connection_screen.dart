import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
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
  List<BluetoothDevice> _bondedDevices = [];
  bool _isLoadingBonded = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    // All'apertura, carica subito i dispositivi accoppiati/di sistema e avvia la scansione
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final vm = Provider.of<WhoopViewModel>(context, listen: false);
      await _fetchBondedAndSystemDevices(vm);
      await vm.startManualDeviceScan();
    });
  }

  Future<void> _fetchBondedAndSystemDevices(WhoopViewModel viewModel) async {
    if (!mounted) return;
    setState(() => _isLoadingBonded = true);
    try {
      final list = await viewModel.getBondedAndSystemDevices();
      if (mounted) {
        setState(() {
          _bondedDevices = list;
          _isLoadingBonded = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingBonded = false);
      }
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _connectToDeviceWithFeedback(WhoopViewModel viewModel, BluetoothDevice device) {
    final displayName = device.platformName.isNotEmpty ? device.platformName : device.remoteId.str;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Connessione a $displayName in corso...'),
        duration: const Duration(seconds: 2),
      ),
    );
    viewModel.selectAndConnectDevice(device);
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = Provider.of<WhoopViewModel>(context);
    final isConnected = viewModel.bleState == BleState.connected || viewModel.bleState == BleState.streaming;
    final isScanning = viewModel.bleState == BleState.scanning;
    final isConnecting = viewModel.bleState == BleState.connecting ||
        viewModel.bleState == BleState.discovering ||
        viewModel.bleState == BleState.subscribing ||
        viewModel.bleState == BleState.initializing;

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
                padding: const EdgeInsets.symmetric(vertical: 18.0),
                child: Column(
                  children: [
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        if (isScanning || isConnecting)
                          FadeTransition(
                            opacity: Tween(begin: 0.2, end: 0.8).animate(_pulseController),
                            child: Container(
                              width: 130,
                              height: 130,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: (isConnecting ? NatureColors.amber : NatureColors.teal).withValues(alpha: 0.15),
                              ),
                            ),
                          ),
                        Container(
                          width: 90,
                          height: 90,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: NatureColors.surface,
                            border: Border.all(
                              color: isConnected
                                  ? NatureColors.recoveryGreen
                                  : (isConnecting
                                      ? NatureColors.amber
                                      : (isScanning ? NatureColors.teal : NatureColors.borderSubtle)),
                              width: 2.0,
                            ),
                          ),
                          child: Icon(
                            isConnected ? Icons.bluetooth_connected : (isConnecting ? Icons.bluetooth_searching : Icons.watch),
                            size: 38,
                            color: isConnected
                                ? NatureColors.recoveryGreen
                                : (isConnecting
                                    ? NatureColors.amber
                                    : (isScanning ? NatureColors.teal : NatureColors.textMuted)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      isConnected
                          ? 'DISPOSITIVO CONNESSO'
                          : (isConnecting
                              ? 'CONNESSIONE IN CORSO...'
                              : (isScanning ? 'RICERCA SENSORE IN CORSO...' : 'NESSUN DISPOSITIVO ABBINATO')),
                      style: const TextStyle(
                        color: NatureColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      viewModel.statusMessage ??
                          (isConnected
                              ? 'Streaming telemetria 1Hz attivo (Batteria & HR)'
                              : 'Assicurati che il sensore sia carico e nelle vicinanze'),
                      style: const TextStyle(color: NatureColors.textMuted, fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 8),

            // 2. SEZIONE PERMANENTE: DISPOSITIVI DISPONIBILI (TOCCA PER CONNETTERE)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Text(
                    'DISPOSITIVI DISPONIBILI (TOCCA PER CONNETTERE)',
                    style: TextStyle(
                      color: NatureColors.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.1,
                    ),
                  ),
                ),
                if (isScanning || _isLoadingBonded)
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(NatureColors.teal),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // Due pulsanti rapidi in alto: "🔄 Cerca Dispositivi" e "🗑️ Reset Associazione"
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: isScanning
                        ? null
                        : () async {
                            await _fetchBondedAndSystemDevices(viewModel);
                            await viewModel.startManualDeviceScan();
                          },
                    icon: const Text('🔄', style: TextStyle(fontSize: 14)),
                    label: Text(
                      isScanning ? 'RICERCA...' : 'Cerca Dispositivi',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, letterSpacing: 0.5),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: NatureColors.teal,
                      foregroundColor: NatureColors.background,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await viewModel.forgetAndResetBle();
                      await _fetchBondedAndSystemDevices(viewModel);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Associazione rimossa e scansione riavviata.')),
                        );
                      }
                    },
                    icon: const Text('🗑️', style: TextStyle(fontSize: 14)),
                    label: const Text(
                      'Reset Associazione',
                      style: TextStyle(
                        color: NatureColors.terracotta,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        letterSpacing: 0.5,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: NatureColors.terracotta.withValues(alpha: 0.4)),
                      backgroundColor: NatureColors.terracotta.withValues(alpha: 0.08),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
              ],
            ),

            if (isConnected) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  onPressed: () async {
                    await viewModel.disconnectBle();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Dispositivo disconnesso per questa sessione.')),
                      );
                    }
                  },
                  icon: const Icon(Icons.power_settings_new, color: NatureColors.textMuted, size: 16),
                  label: const Text(
                    'Disconnetti Solo per questa Sessione',
                    style: TextStyle(color: NatureColors.textMuted, fontSize: 12),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 16),

            // LISTA DISPOSITIVI: ASSOCIATI ANDROID + SCANSIONE LIVE
            StreamBuilder<List<ScanResult>>(
              stream: viewModel.bleScanResultsStream,
              builder: (context, snapshot) {
                // A) Dispositivi Associati al Telefono (Bonded / System) con nome non vuoto
                final bondedList = _bondedDevices.where((d) => d.platformName.trim().isNotEmpty).toList();
                final bondedIds = _bondedDevices.map((d) => d.remoteId.str).toSet();

                // B) Dispositivi dalla Scansione Live (esclusi quelli già in bondedList)
                final rawScanResults = snapshot.data ?? [];
                final Map<String, ScanResult> liveResultsMap = {};
                for (final r in rawScanResults) {
                  final id = r.device.remoteId.str;
                  if (!bondedIds.contains(id)) {
                    liveResultsMap[id] = r;
                  }
                }
                final liveResults = liveResultsMap.values.toList();
                liveResults.sort((a, b) => b.rssi.compareTo(a.rssi));

                final hasAnyDevices = bondedList.isNotEmpty || liveResults.isNotEmpty;

                if (!hasAnyDevices) {
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 22),
                    decoration: NatureTheme.organicCardDecoration(isDark: true),
                    child: Column(
                      children: [
                        Icon(
                          isScanning ? Icons.bluetooth_searching : Icons.devices_other,
                          color: NatureColors.textMuted,
                          size: 32,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          isScanning
                              ? 'Scansione in corso... Avvicina il tuo WHOOP.'
                              : 'Nessun dispositivo Bluetooth rilevato.\nTocca "Cerca Dispositivi" per avviare la ricerca.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: NatureColors.textMuted, fontSize: 12),
                        ),
                      ],
                    ),
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // GRUPPO 1: Dispositivi Associati al Telefono (Android OS)
                    if (bondedList.isNotEmpty) ...[
                      const Padding(
                        padding: EdgeInsets.only(left: 4.0, bottom: 8.0, top: 4.0),
                        child: Text(
                          'DISPOSITIVI ACCOPPIATI SU ANDROID',
                          style: TextStyle(
                            color: NatureColors.amber,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ),
                      ...bondedList.map((device) {
                        final isThisConnected = isConnected &&
                            viewModel.connectedDevice?.remoteId.str == device.remoteId.str;
                        final name = device.platformName;
                        final upper = name.toUpperCase();
                        final isWhoop = upper.contains('WHOOP') ||
                            upper.contains('WP5') ||
                            upper.contains('WP4') ||
                            upper.contains('MAVERICK') ||
                            upper.contains('MG');

                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: NatureColors.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isThisConnected
                                  ? NatureColors.recoveryGreen
                                  : (isWhoop
                                      ? NatureColors.teal.withValues(alpha: 0.6)
                                      : NatureColors.borderSubtle),
                              width: isThisConnected ? 1.8 : 1.0,
                            ),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                            leading: CircleAvatar(
                              backgroundColor: isWhoop
                                  ? NatureColors.teal.withValues(alpha: 0.15)
                                  : NatureColors.borderSubtle.withValues(alpha: 0.4),
                              child: Icon(
                                isWhoop ? Icons.watch : Icons.bluetooth_connected,
                                color: isWhoop ? NatureColors.tealLight : NatureColors.amber,
                                size: 20,
                              ),
                            ),
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    name,
                                    style: const TextStyle(
                                      color: NatureColors.textPrimary,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: (isWhoop ? NatureColors.teal : NatureColors.amber).withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    isWhoop ? 'WHOOP • ACCOPPIATO' : 'ASSOCIATO ANDROID',
                                    style: TextStyle(
                                      color: isWhoop ? NatureColors.tealLight : NatureColors.amber,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 4.0),
                              child: Text(
                                device.remoteId.str,
                                style: const TextStyle(
                                  color: NatureColors.textMuted,
                                  fontSize: 11,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ),
                            trailing: isThisConnected
                                ? Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: NatureColors.recoveryGreen.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.check_circle, size: 14, color: NatureColors.recoveryGreen),
                                        SizedBox(width: 4),
                                        Text(
                                          'CONNESSO',
                                          style: TextStyle(
                                            color: NatureColors.recoveryGreen,
                                            fontWeight: FontWeight.w800,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                : ElevatedButton(
                                    onPressed: isConnecting
                                        ? null
                                        : () => _connectToDeviceWithFeedback(viewModel, device),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: NatureColors.teal,
                                      foregroundColor: NatureColors.background,
                                      elevation: 0,
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                    child: const Text(
                                      'CONNETTI',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                            onTap: isThisConnected
                                ? null
                                : () => _connectToDeviceWithFeedback(viewModel, device),
                          ),
                        );
                      }),
                    ],

                    // GRUPPO 2: Dispositivi Rilevati dallo Scanner Live
                    if (liveResults.isNotEmpty) ...[
                      const Padding(
                        padding: EdgeInsets.only(left: 4.0, bottom: 8.0, top: 12.0),
                        child: Text(
                          'DISPOSITIVI RILEVATI DALLA SCANSIONE LIVE',
                          style: TextStyle(
                            color: NatureColors.textSecondary,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ),
                      ...liveResults.map((r) {
                        final device = r.device;
                        final isThisConnected = isConnected &&
                            viewModel.connectedDevice?.remoteId.str == device.remoteId.str;
                        final rawName = device.platformName.isNotEmpty
                            ? device.platformName
                            : (r.advertisementData.advName.isNotEmpty
                                ? r.advertisementData.advName
                                : 'Dispositivo BLE Sconosciuto');
                        final upper = rawName.toUpperCase();
                        final isWhoop = upper.contains('WHOOP') ||
                            upper.contains('WP5') ||
                            upper.contains('WP4') ||
                            upper.contains('MAVERICK') ||
                            upper.contains('MG');

                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: NatureColors.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isThisConnected
                                  ? NatureColors.recoveryGreen
                                  : (isWhoop
                                      ? NatureColors.teal.withValues(alpha: 0.5)
                                      : NatureColors.borderSubtle),
                              width: isThisConnected ? 1.8 : 1.0,
                            ),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                            leading: CircleAvatar(
                              backgroundColor: isWhoop
                                  ? NatureColors.teal.withValues(alpha: 0.15)
                                  : NatureColors.borderSubtle.withValues(alpha: 0.4),
                              child: Icon(
                                isWhoop ? Icons.watch : Icons.bluetooth,
                                color: isWhoop ? NatureColors.tealLight : NatureColors.textMuted,
                                size: 20,
                              ),
                            ),
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    rawName,
                                    style: const TextStyle(
                                      color: NatureColors.textPrimary,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (isWhoop) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: NatureColors.teal.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text(
                                      'WHOOP',
                                      style: TextStyle(
                                        color: NatureColors.tealLight,
                                        fontSize: 9,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 4.0),
                              child: Row(
                                children: [
                                  Text(
                                    device.remoteId.str,
                                    style: const TextStyle(
                                      color: NatureColors.textMuted,
                                      fontSize: 11,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${r.rssi} dBm',
                                    style: TextStyle(
                                      color: r.rssi > -70
                                          ? NatureColors.recoveryGreen
                                          : (r.rssi > -85 ? NatureColors.amber : NatureColors.textMuted),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            trailing: isThisConnected
                                ? Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: NatureColors.recoveryGreen.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.check_circle, size: 14, color: NatureColors.recoveryGreen),
                                        SizedBox(width: 4),
                                        Text(
                                          'CONNESSO',
                                          style: TextStyle(
                                            color: NatureColors.recoveryGreen,
                                            fontWeight: FontWeight.w800,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                : ElevatedButton(
                                    onPressed: isConnecting
                                        ? null
                                        : () => _connectToDeviceWithFeedback(viewModel, device),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: NatureColors.teal,
                                      foregroundColor: NatureColors.background,
                                      elevation: 0,
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                    child: const Text(
                                      'CONNETTI',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                            onTap: isThisConnected
                                ? null
                                : () => _connectToDeviceWithFeedback(viewModel, device),
                          ),
                        );
                      }),
                    ],
                  ],
                );
              },
            ),

            const SizedBox(height: 24),

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
                    label: 'Dispositivo Attivo',
                    value: viewModel.connectedDevice?.platformName.isNotEmpty == true
                        ? viewModel.connectedDevice!.platformName
                        : (isConnected ? 'WHOOP 5.0' : 'Nessuno'),
                    statusColor: isConnected ? NatureColors.tealLight : NatureColors.textMuted,
                  ),
                  const Divider(color: NatureColors.borderSubtle, height: 20),
                  _buildDetailRow(
                    label: 'Stato Batteria',
                    value: viewModel.batteryPct != null ? '${viewModel.batteryPct}%' : '--%',
                    statusColor: viewModel.batteryPct != null ? NatureColors.recoveryGreen : NatureColors.textMuted,
                  ),
                  const Divider(color: NatureColors.borderSubtle, height: 20),
                  _buildDetailRow(
                    label: 'Modello Hardware',
                    value: viewModel.isWhoop5 ? 'WHOOP 5.0 (Maverick)' : 'BLE Sensor v4.0 / Standard',
                    statusColor: NatureColors.textPrimary,
                  ),
                  const Divider(color: NatureColors.borderSubtle, height: 20),
                  _buildDetailRow(
                    label: 'UUID Servizi GATT',
                    value: viewModel.isWhoop5 ? 'fd4b0001 (Format-1)' : '61080001 (Format-0)',
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
                    final sent = await viewModel.sendTestVibrationPulseNow();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(sent
                              ? 'Impulso di vibrazione inviato alla fascia WHOOP!'
                              : 'Impossibile inviare la vibrazione. Verifica la connessione BLE.'),
                        ),
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
