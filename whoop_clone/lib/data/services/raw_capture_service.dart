import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/logging/structured_logger.dart';

/// Servizio per la cattura e registrazione continua dei pacchetti BLE grezzi in formato NDJSON.
/// Gestisce buffer in memoria e flush asincrono (ogni 2s o 50 pacchetti)
/// con rotazione automatica dei file.
class RawCaptureService {
  static const String prefCaptureEnabledKey = 'whoop_raw_capture_enabled';
  static const int defaultMaxBufferSize = 50;
  static const Duration defaultFlushInterval = Duration(seconds: 2);
  static const int maxFileSizeBytes = 10 * 1024 * 1024; // 10MB rotazione

  static RawCaptureService? _instance;
  static RawCaptureService get instance => _instance ??= RawCaptureService();

  final Directory? _customCapturesDir;
  final SharedPreferences? _customPrefs;
  final int maxBufferSize;
  final Duration flushInterval;

  bool _isCapturing = false;
  int _totalPacketsCaptured = 0;
  final List<Map<String, dynamic>> _buffer = [];
  Timer? _flushTimer;
  File? _currentFile;
  IOSink? _currentSink;
  int _currentFileBytes = 0;
  bool _isFlushing = false;

  RawCaptureService({
    Directory? capturesDirectory,
    SharedPreferences? prefs,
    this.maxBufferSize = defaultMaxBufferSize,
    this.flushInterval = defaultFlushInterval,
  })  : _customCapturesDir = capturesDirectory,
        _customPrefs = prefs;

  /// Permette di impostare una istanza fittizia/custom per test
  static void setMockInstance(RawCaptureService mock) {
    _instance?.dispose();
    _instance = mock;
  }

  /// Stato attuale della cattura
  bool get isCapturing => _isCapturing;

  /// Conteggio pacchetti attualmente in buffer di memoria (non ancora scritti)
  int get bufferedCount => _buffer.length;

  /// Totale pacchetti registrati nella sessione corrente
  int get totalPacketsCaptured => _totalPacketsCaptured;

  /// Percorso assoluto del file di cattura correntemente attivo
  String? get currentCapturePath => _currentFile?.path;

  Future<SharedPreferences?> _getPrefs() async {
    if (_customPrefs != null) return _customPrefs;
    try {
      return await SharedPreferences.getInstance();
    } catch (_) {
      return null;
    }
  }

  /// Inizializza il servizio caricando lo stato dalle SharedPreferences
  Future<void> init() async {
    try {
      final prefs = await _getPrefs();
      final enabled = prefs?.getBool(prefCaptureEnabledKey) ?? false;
      if (enabled && !_isCapturing) {
        await startCapture();
      }
    } catch (e, stack) {
      StructuredLogger.instance.warning(
        LogTag.ble,
        'RawCaptureService.init: Impossibile leggere SharedPreferences: $e',
        error: e,
        stackTrace: stack,
      );
    }
  }

  /// Restituisce la directory di salvataggio delle catture
  Future<Directory> getCapturesDirectory() async {
    if (_customCapturesDir != null) {
      if (!_customCapturesDir!.existsSync()) {
        _customCapturesDir!.createSync(recursive: true);
      }
      return _customCapturesDir!;
    }

    try {
      final docs = await getApplicationDocumentsDirectory();
      final dir = Directory(p.join(docs.path, 'captures'));
      if (!dir.existsSync()) {
        dir.createSync(recursive: true);
      }
      return dir;
    } catch (_) {
      final dir = Directory('captures');
      if (!dir.existsSync()) {
        dir.createSync(recursive: true);
      }
      return dir;
    }
  }

  /// Avvia la registrazione su un nuovo file NDJSON
  Future<String> startCapture() async {
    if (_isCapturing && _currentFile != null) {
      return _currentFile!.path;
    }

    final dir = await getCapturesDirectory();
    final now = DateTime.now().toUtc();
    final fileName = _buildCaptureFileName(now);
    _currentFile = File(p.join(dir.path, fileName));
    _currentSink = _currentFile!.openWrite(mode: FileMode.append);
    _currentFileBytes = 0;
    _isCapturing = true;

    _flushTimer?.cancel();
    _flushTimer = Timer.periodic(flushInterval, (_) => flush());

    try {
      final prefs = await _getPrefs();
      await prefs?.setBool(prefCaptureEnabledKey, true);
    } catch (e, stack) {
      StructuredLogger.instance.warning(
        LogTag.ble,
        'RawCaptureService.startCapture: Impossibile salvare preferenza: $e',
        error: e,
        stackTrace: stack,
      );
    }

    StructuredLogger.instance.info(
      LogTag.ble,
      'RawCaptureService: Cattura RAW avviata su ${_currentFile!.path}',
    );

    return _currentFile!.path;
  }

  /// Ferma la registrazione ed effettua il flush di tutti i byte residui
  Future<void> stopCapture() async {
    if (!_isCapturing) return;

    _isCapturing = false;
    _flushTimer?.cancel();
    _flushTimer = null;

    await flush();

    if (_currentSink != null) {
      await _currentSink!.flush();
      await _currentSink!.close();
      _currentSink = null;
    }

    try {
      final prefs = await _getPrefs();
      await prefs?.setBool(prefCaptureEnabledKey, false);
    } catch (e, stack) {
      StructuredLogger.instance.warning(
        LogTag.ble,
        'RawCaptureService.stopCapture: Impossibile salvare preferenza: $e',
        error: e,
        stackTrace: stack,
      );
    }

    StructuredLogger.instance.info(
      LogTag.ble,
      'RawCaptureService: Cattura RAW arrestata. Totale pacchetti: $_totalPacketsCaptured',
    );
  }

  /// Abilita o disabilita la cattura sincronizzando con SharedPreferences
  Future<void> setCaptureEnabled(bool enabled) async {
    if (enabled) {
      await startCapture();
    } else {
      await stopCapture();
    }
    try {
      final prefs = await _getPrefs();
      await prefs?.setBool(prefCaptureEnabledKey, enabled);
    } catch (e, stack) {
      StructuredLogger.instance.warning(
        LogTag.ble,
        'RawCaptureService.setCaptureEnabled: Impossibile salvare preferenza: $e',
        error: e,
        stackTrace: stack,
      );
    }
  }

  /// Registra una singola notifica BLE grezza nel buffer
  void recordNotification(String charUuid, Uint8List rawBytes) {
    if (!_isCapturing) return;

    final nowUtc = DateTime.now().toUtc();
    final hexString = rawBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

    final record = {
      'charUuid': charUuid,
      'timestampUtcMs': nowUtc.millisecondsSinceEpoch,
      'byteLength': rawBytes.length,
      'hexPayload': hexString,
    };

    _buffer.add(record);
    _totalPacketsCaptured++;

    // Flush immediato se viene raggiunta la soglia di memoria
    if (_buffer.length >= maxBufferSize) {
      flush();
    }
  }

  /// Svuota il buffer in memoria scrivendo le righe NDJSON su disco
  Future<void> flush() async {
    if (_buffer.isEmpty || _isFlushing) return;
    _isFlushing = true;

    final itemsToWrite = List<Map<String, dynamic>>.from(_buffer);
    _buffer.clear();

    try {
      if (_currentFile == null || _currentSink == null) {
        final dir = await getCapturesDirectory();
        final now = DateTime.now().toUtc();
        _currentFile = File(p.join(dir.path, _buildCaptureFileName(now)));
        _currentSink = _currentFile!.openWrite(mode: FileMode.append);
        _currentFileBytes = 0;
      }

      final StringBuffer sb = StringBuffer();
      for (final item in itemsToWrite) {
        sb.writeln(jsonEncode(item));
      }
      final payload = sb.toString();
      final bytesAdded = utf8.encode(payload).length;

      // Verifica rotazione per dimensione massima
      if (_currentFileBytes + bytesAdded > maxFileSizeBytes) {
        await _rotateCaptureFile();
      }

      _currentSink!.write(payload);
      await _currentSink!.flush();
      _currentFileBytes += bytesAdded;
    } catch (e) {
      // In caso di errore ripristina gli elementi all'inizio del buffer
      _buffer.insertAll(0, itemsToWrite);
      StructuredLogger.instance.error(
        LogTag.ble,
        'RawCaptureService: Errore durante flush NDJSON: $e',
      );
    } finally {
      _isFlushing = false;
    }
  }

  /// Esegue la rotazione del file creando un nuovo file timestamped
  Future<void> _rotateCaptureFile() async {
    if (_currentSink != null) {
      await _currentSink!.flush();
      await _currentSink!.close();
      _currentSink = null;
    }
    final dir = await getCapturesDirectory();
    final now = DateTime.now().toUtc();
    _currentFile = File(p.join(dir.path, _buildCaptureFileName(now)));
    _currentSink = _currentFile!.openWrite(mode: FileMode.append);
    _currentFileBytes = 0;

    StructuredLogger.instance.info(
      LogTag.ble,
      'RawCaptureService: Rotazione file cattura -> ${_currentFile!.path}',
    );
  }

  /// Elenca tutti i file di cattura NDJSON presenti, ordinati dal più recente al più vecchio
  Future<List<File>> listCaptureFiles() async {
    final dir = await getCapturesDirectory();
    if (!dir.existsSync()) return [];

    final files = dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.ndjson'))
        .toList();

    files.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
    return files;
  }

  /// Restituisce il percorso dell'ultimo file di cattura registrato
  Future<String?> getLatestCapturePath() async {
    final files = await listCaptureFiles();
    if (files.isEmpty) return null;
    return files.first.path;
  }

  /// Esporta o copia un file di cattura verso una destinazione condivisa / cartella export
  Future<File> exportCaptureFile({String? sourcePath, String? destinationDir}) async {
    await flush();

    final String path = sourcePath ?? await getLatestCapturePath() ?? (_currentFile?.path ?? '');
    if (path.isEmpty) {
      throw StateError('Nessun file di cattura disponibile per l\'esportazione.');
    }

    final srcFile = File(path);
    if (!await srcFile.exists()) {
      throw StateError('File di cattura sorgente non trovato: $path');
    }

    final Directory destDirectory;
    if (destinationDir != null) {
      destDirectory = Directory(destinationDir);
    } else {
      final capturesDir = await getCapturesDirectory();
      destDirectory = Directory(p.join(capturesDir.path, 'exports'));
    }

    if (!destDirectory.existsSync()) {
      destDirectory.createSync(recursive: true);
    }

    final destPath = p.join(destDirectory.path, p.basename(srcFile.path));
    final exportedFile = await srcFile.copy(destPath);

    StructuredLogger.instance.info(
      LogTag.ble,
      'RawCaptureService: File esportato con successo in $destPath',
    );

    return exportedFile;
  }

  /// Rilascia le risorse
  Future<void> dispose() async {
    await stopCapture();
    _buffer.clear();
  }

  static String _buildCaptureFileName(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final h = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    final s = dt.second.toString().padLeft(2, '0');
    return 'whoop_raw_capture_$y$m${d}_$h$min$s.ndjson';
  }
}
