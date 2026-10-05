import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'ble_connection_manager.dart';

/// Singolo pacchetto BLE registrato da riprodurre
class ReplayPacket {
  final String charUuid;
  final int timestampUtcMs;
  final int byteLength;
  final String hexPayload;
  final Uint8List rawBytes;

  ReplayPacket({
    required this.charUuid,
    required this.timestampUtcMs,
    required this.byteLength,
    required this.hexPayload,
    required this.rawBytes,
  });

  factory ReplayPacket.fromJson(Map<String, dynamic> json) {
    final hex = (json['hexPayload'] as String? ?? '').replaceAll(' ', '').trim();
    final len = hex.length ~/ 2;
    final bytes = Uint8List(len);
    for (int i = 0; i < len; i++) {
      bytes[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return ReplayPacket(
      charUuid: json['charUuid'] as String? ?? '',
      timestampUtcMs: json['timestampUtcMs'] as int? ?? 0,
      byteLength: json['byteLength'] as int? ?? bytes.length,
      hexPayload: hex,
      rawBytes: bytes,
    );
  }

  DateTime get timestamp => DateTime.fromMillisecondsSinceEpoch(timestampUtcMs, isUtc: true);
}

/// Sorgente BLE di Replay che emula il bracciale WHOOP leggendo un file di cattura NDJSON.
/// Supporta velocità configurabili: 1.0 (tempo reale), 5.0, 20.0, oppure 0.0 / double.infinity (istantaneo per test).
/// Espone Stream<Uint8List> per i byte grezzi e uno Stream<BleState> identico alla connessione reale.
class ReplayBleSource {
  final List<ReplayPacket> _packets = [];
  double speedMultiplier;

  BleState _state = BleState.disconnected;
  bool _isReplaying = false;
  bool _isPaused = false;
  bool _cancelRequested = false;
  int _currentIndex = 0;

  final StreamController<Uint8List> _rawByteController =
      StreamController<Uint8List>.broadcast(sync: true);
  final StreamController<ReplayPacket> _packetController =
      StreamController<ReplayPacket>.broadcast(sync: true);
  final StreamController<BleState> _stateController =
      StreamController<BleState>.broadcast(sync: true);
  final StreamController<double> _progressController =
      StreamController<double>.broadcast(sync: true);

  Completer<void>? _pauseCompleter;

  ReplayBleSource({this.speedMultiplier = 1.0});

  // Getters
  BleState get state => _state;
  bool get isReplaying => _isReplaying;
  bool get isPaused => _isPaused;
  int get currentIndex => _currentIndex;
  int get totalPackets => _packets.length;
  List<ReplayPacket> get packets => List.unmodifiable(_packets);

  /// Stream dei byte grezzi di ciascun pacchetto emesso
  Stream<Uint8List> get rawByteStream => _rawByteController.stream;

  /// Stream dei metadati completi del pacchetto
  Stream<ReplayPacket> get packetStream => _packetController.stream;

  /// Stream degli stati BLE emulati
  Stream<BleState> get stateStream => _stateController.stream;

  /// Stream di avanzamento (0.0 .. 1.0)
  Stream<double> get progressStream => _progressController.stream;

  /// Carica i pacchetti da un file NDJSON su disco
  Future<void> loadFile(File file) async {
    if (!await file.exists()) {
      throw ArgumentError('File NDJSON non trovato: ${file.path}');
    }
    final lines = await file.readAsLines();
    loadLines(lines);
  }

  /// Carica i pacchetti da un percorso file
  Future<void> loadFilePath(String path) async {
    await loadFile(File(path));
  }

  /// Carica i pacchetti da una lista di righe NDJSON
  void loadLines(List<String> ndjsonLines) {
    _packets.clear();
    _currentIndex = 0;
    for (final line in ndjsonLines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      try {
        final map = jsonDecode(trimmed) as Map<String, dynamic>;
        _packets.add(ReplayPacket.fromJson(map));
      } catch (_) {
        // Ignora righe malformate
      }
    }
  }

  /// Carica direttamente una lista di oggetti ReplayPacket
  void loadPackets(List<ReplayPacket> packets) {
    _packets.clear();
    _packets.addAll(packets);
    _currentIndex = 0;
  }

  /// Imposta il moltiplicatore di velocità (es. 1.0, 5.0, 20.0, o 0.0 per istantaneo)
  void setSpeed(double speed) {
    speedMultiplier = speed;
  }

  /// Avvia la riproduzione dall'indice corrente
  Future<void> start({double? speed}) async {
    if (_isReplaying) return;
    if (_packets.isEmpty) return;

    if (speed != null) speedMultiplier = speed;

    _isReplaying = true;
    _isPaused = false;
    _cancelRequested = false;

    // Emula ciclo di connessione BLE
    _updateState(BleState.connecting);
    await _delayMs(speedMultiplier <= 0 ? 0 : 50);

    if (_cancelRequested) {
      _stopInternal();
      return;
    }

    _updateState(BleState.connected);
    await _delayMs(speedMultiplier <= 0 ? 0 : 30);

    if (_cancelRequested) {
      _stopInternal();
      return;
    }

    _updateState(BleState.streaming);

    // Esecuzione riproduzione sequenziale pacchetti
    for (int i = _currentIndex; i < _packets.length; i++) {
      if (_cancelRequested) break;

      while (_isPaused && !_cancelRequested) {
        _pauseCompleter = Completer<void>();
        await _pauseCompleter!.future;
      }

      if (_cancelRequested) break;

      _currentIndex = i;
      final currentPacket = _packets[i];

      // Calcola ritardo temporale rispetto al pacchetto precedente
      if (i > 0 && speedMultiplier > 0 && !speedMultiplier.isInfinite) {
        final prevPacket = _packets[i - 1];
        final deltaMs = currentPacket.timestampUtcMs - prevPacket.timestampUtcMs;
        if (deltaMs > 0) {
          final adjustedMs = (deltaMs / speedMultiplier).round();
          // Limita ritardi anomali estremi a max 10 secondi per non bloccare
          final waitMs = adjustedMs.clamp(0, 10000);
          if (waitMs > 0) {
            await Future.delayed(Duration(milliseconds: waitMs));
          }
        }
      } else if (speedMultiplier <= 0 || speedMultiplier.isInfinite) {
        // Modalità istantanea per test
        await Future.microtask(() {});
      }

      if (_cancelRequested) break;

      // Emetti pacchetto grezzo e tipizzato
      if (!_rawByteController.isClosed) {
        _rawByteController.add(currentPacket.rawBytes);
      }
      if (!_packetController.isClosed) {
        _packetController.add(currentPacket);
      }
      if (!_progressController.isClosed) {
        final progress = (i + 1) / _packets.length;
        _progressController.add(progress);
      }
    }

    _stopInternal();
  }

  /// Mette in pausa la riproduzione
  void pause() {
    if (!_isReplaying || _isPaused) return;
    _isPaused = true;
  }

  /// Riprende la riproduzione dalla pausa
  void resume() {
    if (!_isReplaying || !_isPaused) return;
    _isPaused = false;
    if (_pauseCompleter != null && !_pauseCompleter!.isCompleted) {
      _pauseCompleter!.complete();
    }
  }

  /// Ferma la riproduzione e resetta lo stato a disconnesso
  Future<void> stop() async {
    _cancelRequested = true;
    if (_pauseCompleter != null && !_pauseCompleter!.isCompleted) {
      _pauseCompleter!.complete();
    }
    _stopInternal();
  }

  /// Salta a uno specifico indice di pacchetto
  void seek(int index) {
    if (index >= 0 && index < _packets.length) {
      _currentIndex = index;
    }
  }

  void _stopInternal() {
    _isReplaying = false;
    _isPaused = false;
    _cancelRequested = false;
    _currentIndex = 0;
    _updateState(BleState.disconnected);
  }

  void _updateState(BleState newState) {
    _state = newState;
    if (!_stateController.isClosed) {
      _stateController.add(_state);
    }
  }

  Future<void> _delayMs(int ms) async {
    if (ms <= 0) {
      await Future.microtask(() {});
    } else {
      await Future.delayed(Duration(milliseconds: ms));
    }
  }

  /// Rilascia tutte le risorse e chiude gli stream
  void dispose() {
    stop();
    if (!_rawByteController.isClosed) _rawByteController.close();
    if (!_packetController.isClosed) _packetController.close();
    if (!_stateController.isClosed) _stateController.close();
    if (!_progressController.isClosed) _progressController.close();
  }
}
