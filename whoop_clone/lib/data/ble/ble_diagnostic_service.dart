import 'dart:async';
import 'dart:collection';
import 'dart:typed_data';
import 'ble_connection_manager.dart';

/// Transizione di stato della connessione BLE con timestamp
class BleStateTransition {
  final DateTime timestamp;
  final BleState state;
  final String? message;

  BleStateTransition({
    required this.timestamp,
    required this.state,
    this.message,
  });
}

/// Evento di disconnessione con codice di stato
class BleDisconnectionEvent {
  final DateTime timestamp;
  final int statusCode;
  final String reason;

  BleDisconnectionEvent({
    required this.timestamp,
    required this.statusCode,
    required this.reason,
  });

  static String mapCodeToDescription(int code) {
    switch (code) {
      case 0:
        return 'Disconnessione normale (0x00)';
      case 8:
        return 'Connection Timeout (0x08)';
      case 19:
        return 'Closed by Peer / Strap disconnected (0x13)';
      case 22:
        return 'Terminated by Local Host (0x16)';
      case 34:
        return 'LMP Response Timeout (0x22)';
      case 62:
        return 'Connection Failed to be Established (0x3E)';
      case 133:
        return 'GATT Error / Busy (0x85)';
      default:
        return 'Status Code: $code';
    }
  }
}

/// Ultimo comando inviato allo strap
class BleCommandLog {
  final DateTime timestamp;
  final int opcode;
  final String hexPayload;
  final String description;

  BleCommandLog({
    required this.timestamp,
    required this.opcode,
    required this.hexPayload,
    required this.description,
  });
}

/// Ultimo ACK / Risposta ricevuta dalla strap
class BleAckLog {
  final DateTime timestamp;
  final String hexPayload;
  final bool isSuccess;

  BleAckLog({
    required this.timestamp,
    required this.hexPayload,
    required this.isSuccess,
  });
}

/// Evento buco di telemetria rilevato
class TelemetryGapEvent {
  final DateTime startTime;
  final DateTime endTime;
  final Duration duration;

  TelemetryGapEvent({
    required this.startTime,
    required this.endTime,
    required this.duration,
  });
}

/// Snapshot diagnostico per aggiornamento reattivo UI
class BleDiagnosticSnapshot {
  final List<BleStateTransition> stateTimeline;
  final List<BleDisconnectionEvent> disconnectionHistory;
  final int framed0xAaPerMinute;
  final int flat96BytePerMinute;
  final int hr2A37PerMinute;
  final int totalPackets;
  final int crcErrors;
  final int discardedBytes;
  final BleCommandLog? lastWriteSent;
  final BleAckLog? lastAckReceived;
  final int dbRowsInsertedPerMinute;
  final bool isTelemetryGap;
  final Duration? currentGapDuration;
  final DateTime? lastPacketTime;
  final List<TelemetryGapEvent> gapHistory;

  BleDiagnosticSnapshot({
    required this.stateTimeline,
    required this.disconnectionHistory,
    required this.framed0xAaPerMinute,
    required this.flat96BytePerMinute,
    required this.hr2A37PerMinute,
    required this.totalPackets,
    required this.crcErrors,
    required this.discardedBytes,
    this.lastWriteSent,
    this.lastAckReceived,
    required this.dbRowsInsertedPerMinute,
    required this.isTelemetryGap,
    this.currentGapDuration,
    this.lastPacketTime,
    required this.gapHistory,
  });
}

/// Servizio centrale diagnostica e telemetria BLE WHOOP
class BleDiagnosticService {
  static BleDiagnosticService? _instance;
  static BleDiagnosticService get instance => _instance ??= BleDiagnosticService();
  static bool enableGapMonitorTimer = true;

  static const int maxTimelineEntries = 50;
  static const int maxDisconnectionEntries = 20;

  final List<BleStateTransition> _stateTimeline = [];
  final List<BleDisconnectionEvent> _disconnectionHistory = [];
  final List<TelemetryGapEvent> _gapHistory = [];

  // Timestamp scorrevoli ultimi 60s per calcolo frequenza al minuto
  final Queue<DateTime> _framedTimestamps = Queue<DateTime>();
  final Queue<DateTime> _flat96Timestamps = Queue<DateTime>();
  final Queue<DateTime> _hrTimestamps = Queue<DateTime>();
  final Queue<DateTime> _dbInsertTimestamps = Queue<DateTime>();

  int _totalPackets = 0;
  int _crcErrors = 0;
  int _discardedBytes = 0;

  BleCommandLog? _lastWriteSent;
  BleAckLog? _lastAckReceived;

  DateTime? _lastPacketTime;
  bool _isStreaming = false;
  Timer? _gapMonitorTimer;

  final StreamController<BleDiagnosticSnapshot> _snapshotController =
      StreamController<BleDiagnosticSnapshot>.broadcast();

  BleDiagnosticService() {
    _startGapMonitor();
  }

  static void setMockInstance(BleDiagnosticService mock) {
    _instance?.dispose();
    _instance = mock;
  }

  Stream<BleDiagnosticSnapshot> get snapshotStream => _snapshotController.stream;

  List<BleStateTransition> get stateTimeline => List.unmodifiable(_stateTimeline);
  List<BleDisconnectionEvent> get disconnectionHistory => List.unmodifiable(_disconnectionHistory);
  List<TelemetryGapEvent> get gapHistory => List.unmodifiable(_gapHistory);
  int get totalPackets => _totalPackets;
  int get crcErrors => _crcErrors;
  int get discardedBytes => _discardedBytes;
  BleCommandLog? get lastWriteSent => _lastWriteSent;
  BleAckLog? get lastAckReceived => _lastAckReceived;
  DateTime? get lastPacketTime => _lastPacketTime;

  /// Registra una transizione di stato
  void recordStateTransition(BleState state, [String? message]) {
    final now = DateTime.now();
    _stateTimeline.insert(
      0,
      BleStateTransition(timestamp: now, state: state, message: message),
    );
    if (_stateTimeline.length > maxTimelineEntries) {
      _stateTimeline.removeLast();
    }

    _isStreaming = (state == BleState.streaming);
    _emitSnapshot();
  }

  /// Registra un evento di disconnessione con codice GATT/OS
  void recordDisconnection(int statusCode, [String? customReason]) {
    final now = DateTime.now();
    final reason = customReason ?? BleDisconnectionEvent.mapCodeToDescription(statusCode);
    _disconnectionHistory.insert(
      0,
      BleDisconnectionEvent(timestamp: now, statusCode: statusCode, reason: reason),
    );
    if (_disconnectionHistory.length > maxDisconnectionEntries) {
      _disconnectionHistory.removeLast();
    }
    _isStreaming = false;
    _emitSnapshot();
  }

  /// Registra l'arrivo di una notifica BLE packet
  void recordPacketReceived({
    required String charUuid,
    required Uint8List bytes,
  }) {
    final now = DateTime.now();
    _totalPackets++;

    // Verifica gap rispetto all'ultimo pacchetto
    if (_lastPacketTime != null && _isStreaming) {
      final diff = now.difference(_lastPacketTime!);
      if (diff > const Duration(seconds: 10)) {
        _gapHistory.insert(
          0,
          TelemetryGapEvent(
            startTime: _lastPacketTime!,
            endTime: now,
            duration: diff,
          ),
        );
        if (_gapHistory.length > 20) _gapHistory.removeLast();
      }
    }
    _lastPacketTime = now;

    // Categorizza per tipologia
    final uuidLower = charUuid.toLowerCase();
    final is0xAa = bytes.isNotEmpty && bytes[0] == 0xAA;
    final is96 = bytes.length >= 96 || uuidLower.contains('0005');
    final isHr = uuidLower.contains('2a37');

    if (is96) {
      _flat96Timestamps.addLast(now);
    } else if (is0xAa) {
      _framedTimestamps.addLast(now);
    } else if (isHr) {
      _hrTimestamps.addLast(now);
    }

    _emitSnapshot();
  }

  /// Registra errori CRC
  void recordCrcError({int discardedBytesCount = 0}) {
    _crcErrors++;
    _discardedBytes += discardedBytesCount;
    _emitSnapshot();
  }

  /// Registra byte scartati
  void recordDiscardedBytes(int count) {
    _discardedBytes += count;
    _emitSnapshot();
  }

  /// Registra invio comando alla strap
  void recordWriteSent({
    required int opcode,
    required Uint8List bytes,
    required String description,
  }) {
    final now = DateTime.now();
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');
    _lastWriteSent = BleCommandLog(
      timestamp: now,
      opcode: opcode,
      hexPayload: hex,
      description: description,
    );
    _emitSnapshot();
  }

  /// Registra ACK ricevuto dalla strap
  void recordAckReceived(List<int> bytes) {
    final now = DateTime.now();
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');
    // Determina se ACK è positivo (convenzionalmente payload non vuoto e primo byte non d'errore)
    final isSuccess = bytes.isNotEmpty && bytes[0] != 0xFF;
    _lastAckReceived = BleAckLog(
      timestamp: now,
      hexPayload: hex,
      isSuccess: isSuccess,
    );
    _emitSnapshot();
  }

  /// Registra inserimento riga in telemetria_grezza
  void recordDatabaseInsert([int count = 1]) {
    final now = DateTime.now();
    for (int i = 0; i < count; i++) {
      _dbInsertTimestamps.addLast(now);
    }
    _emitSnapshot();
  }

  /// Calcola frequenza pacchetti per minuto ripulendo timestamp obsoleti
  int _pruneAndCount(Queue<DateTime> queue, DateTime threshold) {
    while (queue.isNotEmpty && queue.first.isBefore(threshold)) {
      queue.removeFirst();
    }
    return queue.length;
  }

  /// Rileva se è attualmente attivo un alert per buco di telemetria (> 10s durante streaming)
  bool get isTelemetryGapActive {
    if (!_isStreaming || _lastPacketTime == null) return false;
    return DateTime.now().difference(_lastPacketTime!) > const Duration(seconds: 10);
  }

  Duration? get currentGapDuration {
    if (_lastPacketTime == null) return null;
    final diff = DateTime.now().difference(_lastPacketTime!);
    return diff > const Duration(seconds: 10) ? diff : null;
  }

  BleDiagnosticSnapshot get currentSnapshot {
    final now = DateTime.now();
    final threshold = now.subtract(const Duration(seconds: 60));

    final framedMin = _pruneAndCount(_framedTimestamps, threshold);
    final flat96Min = _pruneAndCount(_flat96Timestamps, threshold);
    final hrMin = _pruneAndCount(_hrTimestamps, threshold);
    final dbRowsMin = _pruneAndCount(_dbInsertTimestamps, threshold);

    final isGap = isTelemetryGapActive;
    final gapDur = currentGapDuration;

    return BleDiagnosticSnapshot(
      stateTimeline: List.unmodifiable(_stateTimeline),
      disconnectionHistory: List.unmodifiable(_disconnectionHistory),
      framed0xAaPerMinute: framedMin,
      flat96BytePerMinute: flat96Min,
      hr2A37PerMinute: hrMin,
      totalPackets: _totalPackets,
      crcErrors: _crcErrors,
      discardedBytes: _discardedBytes,
      lastWriteSent: _lastWriteSent,
      lastAckReceived: _lastAckReceived,
      dbRowsInsertedPerMinute: dbRowsMin,
      isTelemetryGap: isGap,
      currentGapDuration: gapDur,
      lastPacketTime: _lastPacketTime,
      gapHistory: List.unmodifiable(_gapHistory),
    );
  }

  void _emitSnapshot() {
    if (!_snapshotController.isClosed) {
      _snapshotController.add(currentSnapshot);
    }
  }

  void _startGapMonitor() {
    if (!enableGapMonitorTimer) return;
    _gapMonitorTimer?.cancel();
    _gapMonitorTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_isStreaming && _lastPacketTime != null) {
        final diff = DateTime.now().difference(_lastPacketTime!);
        if (diff > const Duration(seconds: 10)) {
          _emitSnapshot();
        }
      }
    });
  }

  /// Resetta tutti i contatori
  void reset() {
    _stateTimeline.clear();
    _disconnectionHistory.clear();
    _gapHistory.clear();
    _framedTimestamps.clear();
    _flat96Timestamps.clear();
    _hrTimestamps.clear();
    _dbInsertTimestamps.clear();
    _totalPackets = 0;
    _crcErrors = 0;
    _discardedBytes = 0;
    _lastWriteSent = null;
    _lastAckReceived = null;
    _lastPacketTime = null;
    _isStreaming = false;
    _emitSnapshot();
  }

  void dispose() {
    _gapMonitorTimer?.cancel();
    _gapMonitorTimer = null;
    if (!_snapshotController.isClosed) {
      _snapshotController.close();
    }
  }
}
