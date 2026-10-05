import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../core/constants/whoop_theme.dart';
import '../../core/logging/structured_logger.dart';
import '../../data/ble/ble_connection_manager.dart';
import '../../data/ble/ble_diagnostic_service.dart';
import '../../data/services/raw_capture_service.dart';

/// Schermata Diagnostica Avanzata: Osservabilità, Cattura Raw e Replay (Fase 1 Roadmap)
class DiagnosticScreen extends StatefulWidget {
  const DiagnosticScreen({super.key});

  static Future<void> navigateTo(BuildContext context) {
    return Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const DiagnosticScreen()),
    );
  }

  @override
  State<DiagnosticScreen> createState() => _DiagnosticScreenState();
}

class _DiagnosticScreenState extends State<DiagnosticScreen> {
  Timer? _refreshTimer;
  StreamSubscription<BleDiagnosticSnapshot>? _snapshotSub;
  StreamSubscription<LogEntry>? _logSub;

  late BleDiagnosticSnapshot _snapshot;
  bool _isCapturing = false;
  String? _currentCapturePath;
  int _totalCaptured = 0;
  int _bufferedCount = 0;
  List<File> _captureFiles = [];

  String _selectedLogTag = 'ALL';
  LogLevel? _selectedLogLevel;
  List<LogEntry> _displayedLogs = [];

  @override
  void initState() {
    super.initState();
    _snapshot = BleDiagnosticService.instance.currentSnapshot;
    _updateCaptureState();

    _snapshotSub = BleDiagnosticService.instance.snapshotStream.listen((snapshot) {
      if (mounted) {
        setState(() {
          _snapshot = snapshot;
        });
      }
    });

    _logSub = StructuredLogger.instance.logStream.listen((_) {
      if (mounted) {
        _refreshLogs();
      }
    });

    _refreshLogs();
    _loadCaptureFiles();

    // Timer per aggiornare contatori al secondo e calcoli gap
    _refreshTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _snapshot = BleDiagnosticService.instance.currentSnapshot;
          _updateCaptureState();
        });
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _snapshotSub?.cancel();
    _logSub?.cancel();
    super.dispose();
  }

  void _updateCaptureState() {
    final cap = RawCaptureService.instance;
    _isCapturing = cap.isCapturing;
    _currentCapturePath = cap.currentCapturePath;
    _totalCaptured = cap.totalPacketsCaptured;
    _bufferedCount = cap.bufferedCount;
  }

  Future<void> _loadCaptureFiles() async {
    final files = await RawCaptureService.instance.listCaptureFiles();
    if (mounted) {
      setState(() {
        _captureFiles = files;
      });
    }
  }

  void _refreshLogs() {
    var logs = StructuredLogger.instance.recentLogs.reversed.toList();
    if (_selectedLogTag != 'ALL') {
      logs = logs.where((l) => l.tag == _selectedLogTag).toList();
    }
    if (_selectedLogLevel != null) {
      logs = logs.where((l) => l.level == _selectedLogLevel).toList();
    }
    setState(() {
      _displayedLogs = logs;
    });
  }

  @override
  Widget build(BuildContext context) {
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
          'DIAGNOSTICA BLE & RAW CAPTURE',
          style: TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white70),
            tooltip: 'Aggiorna metriche',
            onPressed: () {
              setState(() {
                _snapshot = BleDiagnosticService.instance.currentSnapshot;
                _updateCaptureState();
                _refreshLogs();
                _loadCaptureFiles();
              });
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Alert Buco di Telemetria (> 10s)
            if (_snapshot.isTelemetryGap) _buildTelemetryGapAlert(),

            // 2. Banner Stato Connessione & Flusso
            _buildConnectionStatusBanner(),
            const SizedBox(height: 16),

            // 3. Pannello RawCaptureService
            _buildRawCapturePanel(),
            const SizedBox(height: 16),

            // 4. Frequenza Pacchetti / Minuto
            _buildPacketThroughputSection(),
            const SizedBox(height: 16),

            // 5. Integrità CRC e SQLite
            _buildDataIntegritySection(),
            const SizedBox(height: 16),

            // 6. Ultimo Comando Inviato & Ultimo ACK Ricevuto
            _buildLastCommandAndAckSection(),
            const SizedBox(height: 16),

            // 7. Ultimi 20 Status Code di Disconnessione
            _buildDisconnectionHistorySection(),
            const SizedBox(height: 16),

            // 8. Timeline degli Stati di Connessione
            _buildConnectionTimelineSection(),
            const SizedBox(height: 16),

            // 9. Console Structured Logs in RAM
            _buildStructuredLogsSection(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // 1. ALERT VISIVO BUCO TELEMETRIA (> 10s)
  // ==========================================
  Widget _buildTelemetryGapAlert() {
    final gapSec = _snapshot.currentGapDuration?.inSeconds ?? 10;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.redAccent, width: 1.5),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'BUCO DI TELEMETRIA RILEVATO!',
                  style: TextStyle(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Nessun pacchetto ricevuto da $gapSec secondi durante la fase di streaming. Possibile stallo GATT o disconnessione silente.',
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 2. BANNER STATO CONNESSIONE
  // ==========================================
  Widget _buildConnectionStatusBanner() {
    final lastState = _snapshot.stateTimeline.isNotEmpty
        ? _snapshot.stateTimeline.first.state
        : BleState.disconnected;

    final isStreaming = lastState == BleState.streaming;
    final isConnected = lastState == BleState.connected || isStreaming;

    final color = isStreaming
        ? WhoopTheme.recoveryGreen
        : (isConnected ? WhoopTheme.strainBlue : WhoopTheme.textMuted);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(
            isStreaming
                ? Icons.sensors
                : (isConnected ? Icons.bluetooth_connected : Icons.bluetooth_disabled),
            color: color,
            size: 26,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'STATO BLE: ${lastState.name.toUpperCase()}',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                    letterSpacing: 0.8,
                  ),
                ),
                Text(
                  _snapshot.stateTimeline.isNotEmpty &&
                          _snapshot.stateTimeline.first.message != null
                      ? _snapshot.stateTimeline.first.message!
                      : (isStreaming ? 'Streaming dati 1Hz attivo' : 'In attesa pacchetti...'),
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ],
            ),
          ),
          if (_snapshot.lastPacketTime != null)
            Text(
              DateFormat('HH:mm:ss').format(_snapshot.lastPacketTime!),
              style: const TextStyle(color: Colors.white54, fontSize: 11),
            ),
        ],
      ),
    );
  }

  // ==========================================
  // 3. RAW CAPTURE PANEL (NDJSON)
  // ==========================================
  Widget _buildRawCapturePanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: WhoopTheme.officialCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.save_alt, color: WhoopTheme.recoveryGreen, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'RAW CAPTURE SERVICE (NDJSON)',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
              Switch(
                value: _isCapturing,
                activeThumbColor: WhoopTheme.recoveryGreen,
                onChanged: (val) async {
                  await RawCaptureService.instance.setCaptureEnabled(val);
                  _updateCaptureState();
                  await _loadCaptureFiles();
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _isCapturing
                ? '🟢 Registrazione attiva in buffer (flush ogni 2s / 50 pkt)'
                : '⚪ Cattura in pausa. Attiva per registrare i pacchetti grezzi.',
            style: TextStyle(
              color: _isCapturing ? WhoopTheme.recoveryGreen : Colors.white54,
              fontSize: 11,
            ),
          ),
          if (_currentCapturePath != null) ...[
            const SizedBox(height: 6),
            Text(
              'File attivo: ${_currentCapturePath!.split(Platform.pathSeparator).last}',
              style: const TextStyle(color: Colors.white70, fontSize: 10, fontFamily: 'monospace'),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              _buildMiniMetric('Totale Catturati', '$_totalCaptured pkt'),
              const SizedBox(width: 12),
              _buildMiniMetric('Buffer in RAM', '$_bufferedCount pkt'),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _exportLatestCapture,
                  icon: const Icon(Icons.share, size: 16, color: Colors.black),
                  label: const Text(
                    'CONDIVIDI / ESPORTA',
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.w900,
                      fontSize: 11,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: WhoopTheme.recoveryGreen,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                onPressed: _rotateCaptureManually,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white12,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text(
                  'NUOVO FILE',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          if (_captureFiles.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(color: WhoopTheme.cardBorder, height: 16),
            const Text(
              'File di cattura archiviati:',
              style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            ..._captureFiles.take(3).map((f) {
              final name = f.path.split(Platform.pathSeparator).last;
              final sizeKb = (f.lengthSync() / 1024.0).toStringAsFixed(1);
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    const Icon(Icons.insert_drive_file, color: Colors.white38, size: 14),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        name,
                        style: const TextStyle(color: Colors.white70, fontSize: 10, fontFamily: 'monospace'),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '$sizeKb KB',
                      style: const TextStyle(color: Colors.white54, fontSize: 10),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Future<void> _exportLatestCapture() async {
    try {
      final exported = await RawCaptureService.instance.exportCaptureFile();
      await Clipboard.setData(ClipboardData(text: exported.path));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: WhoopTheme.recoveryGreen,
            content: Text(
              '✅ Cattura esportata! Percorso copiato negli appunti:\n${exported.path}',
              style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.redAccent,
            content: Text('⚠️ Errore esportazione: $e'),
          ),
        );
      }
    }
  }

  Future<void> _rotateCaptureManually() async {
    if (_isCapturing) {
      await RawCaptureService.instance.stopCapture();
      await RawCaptureService.instance.startCapture();
      _updateCaptureState();
      await _loadCaptureFiles();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: WhoopTheme.strainBlue,
            content: Text('Nuovo file di cattura avviato.'),
          ),
        );
      }
    }
  }

  // ==========================================
  // 4. FREQUENZA PACCHETTI / MINUTO
  // ==========================================
  Widget _buildPacketThroughputSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: WhoopTheme.officialCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'THROUGHPUT PACCHETTI (FREQUENZA / MINUTO)',
            style: TextStyle(
              color: WhoopTheme.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  '0xAA Framed',
                  '${_snapshot.framed0xAaPerMinute}',
                  'pkt/min',
                  WhoopTheme.recoveryGreen,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricTile(
                  '96-Byte Flat',
                  '${_snapshot.flat96BytePerMinute}',
                  'pkt/min',
                  WhoopTheme.strainBlue,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricTile(
                  '0x2A37 HR',
                  '${_snapshot.hr2A37PerMinute}',
                  'pkt/min',
                  Colors.amber,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Totale pacchetti ricevuti: ${_snapshot.totalPackets}',
            style: const TextStyle(color: Colors.white54, fontSize: 11),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 5. INTEGRITÀ CRC & SQLITE
  // ==========================================
  Widget _buildDataIntegritySection() {
    final hasCrcErrors = _snapshot.crcErrors > 0;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: WhoopTheme.officialCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'INTEGRITÀ DATI & PERSISTENZA SQLITE',
            style: TextStyle(
              color: WhoopTheme.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  'Errori CRC',
                  '${_snapshot.crcErrors}',
                  'mismatch',
                  hasCrcErrors ? Colors.redAccent : WhoopTheme.recoveryGreen,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricTile(
                  'Byte Scartati',
                  '${_snapshot.discardedBytes}',
                  'byte',
                  _snapshot.discardedBytes > 0 ? Colors.orangeAccent : WhoopTheme.textMuted,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricTile(
                  'SQLite Grezza',
                  '${_snapshot.dbRowsInsertedPerMinute}',
                  'rows/min',
                  WhoopTheme.recoveryGreen,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 6. ULTIMO COMANDO INVIATO & ULTIMO ACK RICEVUTO
  // ==========================================
  Widget _buildLastCommandAndAckSection() {
    final lastWrite = _snapshot.lastWriteSent;
    final lastAck = _snapshot.lastAckReceived;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: WhoopTheme.officialCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ULTIMA SCRITTURA & ACK RICEVUTO',
            style: TextStyle(
              color: WhoopTheme.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 12),
          // Ultimo comando inviato
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: WhoopTheme.cardBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'TX -> CMD_TO_STRAP',
                      style: TextStyle(
                        color: WhoopTheme.strainBlue,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                    if (lastWrite != null)
                      Text(
                        DateFormat('HH:mm:ss.SSS').format(lastWrite.timestamp),
                        style: const TextStyle(color: Colors.white38, fontSize: 10),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  lastWrite != null
                      ? 'Opcode: 0x${lastWrite.opcode.toRadixString(16).padLeft(2, '0').toUpperCase()} (${lastWrite.opcode}) | ${lastWrite.description}\nHEX: ${lastWrite.hexPayload}'
                      : 'Nessuna scrittura inviata di recente.',
                  style: const TextStyle(color: Colors.white70, fontSize: 11, fontFamily: 'monospace'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Ultimo ACK ricevuto
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: WhoopTheme.cardBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'RX <- CMD_FROM_STRAP (ACK / Response)',
                      style: TextStyle(
                        color: WhoopTheme.recoveryGreen,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                    if (lastAck != null)
                      Text(
                        DateFormat('HH:mm:ss.SSS').format(lastAck.timestamp),
                        style: const TextStyle(color: Colors.white38, fontSize: 10),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  lastAck != null
                      ? 'Status: ${lastAck.isSuccess ? "SUCCESS ✅" : "ERROR ❌"}\nHEX: ${lastAck.hexPayload}'
                      : 'Nessun ACK ricevuto di recente.',
                  style: const TextStyle(color: Colors.white70, fontSize: 11, fontFamily: 'monospace'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 7. ULTIMI 20 STATUS CODE DI DISCONNESSIONE
  // ==========================================
  Widget _buildDisconnectionHistorySection() {
    final history = _snapshot.disconnectionHistory;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: WhoopTheme.officialCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'ULTIMI STATUS CODE DISCONNESSIONE',
                style: TextStyle(
                  color: WhoopTheme.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.0,
                ),
              ),
              Text(
                '${history.length} / 20',
                style: const TextStyle(color: Colors.white38, fontSize: 10),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (history.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Nessun evento di disconnessione registrato.',
                style: TextStyle(color: Colors.white38, fontSize: 11),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: history.length,
              separatorBuilder: (_, __) => const Divider(color: WhoopTheme.cardBorder, height: 12),
              itemBuilder: (context, index) {
                final ev = history[index];
                final isGattErr = ev.statusCode == 133;
                final isTimeout = ev.statusCode == 8;

                final color = isGattErr
                    ? Colors.redAccent
                    : (isTimeout ? Colors.orangeAccent : WhoopTheme.textMuted);

                return Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: color.withValues(alpha: 0.5)),
                      ),
                      child: Text(
                        '0x${ev.statusCode.toRadixString(16).padLeft(2, '0').toUpperCase()} (${ev.statusCode})',
                        style: TextStyle(
                          color: color,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        ev.reason,
                        style: const TextStyle(color: Colors.white70, fontSize: 11),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      DateFormat('HH:mm:ss').format(ev.timestamp),
                      style: const TextStyle(color: Colors.white38, fontSize: 10),
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  // ==========================================
  // 8. TIMELINE DEGLI STATI DI CONNESSIONE
  // ==========================================
  Widget _buildConnectionTimelineSection() {
    final timeline = _snapshot.stateTimeline;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: WhoopTheme.officialCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'TIMELINE STATI CONNESSIONE BLE',
            style: TextStyle(
              color: WhoopTheme.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 10),
          if (timeline.isEmpty)
            const Text('Nessuna transizione registrata.', style: TextStyle(color: Colors.white38, fontSize: 11))
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: timeline.length > 8 ? 8 : timeline.length,
              separatorBuilder: (_, __) => const SizedBox(height: 6),
              itemBuilder: (context, index) {
                final t = timeline[index];
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DateFormat('HH:mm:ss.S').format(t.timestamp),
                      style: const TextStyle(color: Colors.white38, fontSize: 10, fontFamily: 'monospace'),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.white10,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        t.state.name.toUpperCase(),
                        style: TextStyle(
                          color: t.state == BleState.streaming
                              ? WhoopTheme.recoveryGreen
                              : (t.state == BleState.connected ? WhoopTheme.strainBlue : Colors.white70),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        t.message ?? '',
                        style: const TextStyle(color: Colors.white54, fontSize: 10),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  // ==========================================
  // 9. CONSOLE STRUCTURED LOGS (RAM 200)
  // ==========================================
  Widget _buildStructuredLogsSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: WhoopTheme.officialCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'LOG STRUTTURATI IN MEMORIA (RAM 200)',
                style: TextStyle(
                  color: WhoopTheme.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.0,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 18, color: Colors.white54),
                tooltip: 'Svuota buffer log',
                onPressed: () {
                  StructuredLogger.instance.clearBuffer();
                  _refreshLogs();
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Filtri Tag
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildTagChip('ALL'),
                ...LogTag.all.map((tag) => _buildTagChip(tag)),
              ],
            ),
          ),
          const SizedBox(height: 6),
          // Filtri Livello
          Row(
            children: [
              _buildLevelChip('TUTTI', null),
              const SizedBox(width: 6),
              _buildLevelChip('DEBUG', LogLevel.debug),
              const SizedBox(width: 6),
              _buildLevelChip('INFO', LogLevel.info),
              const SizedBox(width: 6),
              _buildLevelChip('WARN', LogLevel.warn),
              const SizedBox(width: 6),
              _buildLevelChip('ERROR', LogLevel.error),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            height: 220,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: WhoopTheme.cardBorder),
            ),
            child: _displayedLogs.isEmpty
                ? const Center(
                    child: Text(
                      'Nessun log disponibile per i filtri selezionati.',
                      style: TextStyle(color: Colors.white38, fontSize: 11),
                    ),
                  )
                : ListView.builder(
                    itemCount: _displayedLogs.length,
                    itemBuilder: (context, index) {
                      final log = _displayedLogs[index];
                      Color color = Colors.white70;
                      if (log.level == LogLevel.error) color = Colors.redAccent;
                      if (log.level == LogLevel.warn) color = Colors.orangeAccent;
                      if (log.level == LogLevel.debug) color = Colors.white38;

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text(
                          log.formatted,
                          style: TextStyle(
                            color: color,
                            fontSize: 10,
                            fontFamily: 'monospace',
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTagChip(String tag) {
    final isSelected = _selectedLogTag == tag;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        selected: isSelected,
        label: Text(tag, style: TextStyle(fontSize: 10, color: isSelected ? Colors.black : Colors.white70)),
        backgroundColor: Colors.white12,
        selectedColor: WhoopTheme.recoveryGreen,
        showCheckmark: false,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
        onSelected: (_) {
          setState(() {
            _selectedLogTag = tag;
            _refreshLogs();
          });
        },
      ),
    );
  }

  Widget _buildLevelChip(String label, LogLevel? level) {
    final isSelected = _selectedLogLevel == level;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedLogLevel = level;
          _refreshLogs();
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: isSelected ? WhoopTheme.strainBlue : Colors.white12,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.black : Colors.white70,
            fontSize: 9,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildMetricTile(String title, String value, String unit, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: WhoopTheme.cardBorder),
      ),
      child: Column(
        children: [
          Text(
            title,
            style: const TextStyle(color: Colors.white54, fontSize: 10),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            unit,
            style: const TextStyle(color: Colors.white38, fontSize: 9),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniMetric(String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10)),
            Text(
              value,
              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
