import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Livelli di log standard
enum LogLevel {
  debug('DEBUG'),
  info('INFO'),
  warn('WARN'),
  error('ERROR');

  final String label;
  const LogLevel(this.label);
}

/// Tag standard WHOOP per logging strutturato
class LogTag {
  static const String ble = '[BLE]';
  static const String ingest = '[INGEST]';
  static const String sleep = '[SLEEP]';
  static const String db = '[DB]';
  static const String haptic = '[HAPTIC]';
  static const String ui = '[UI]';

  static const List<String> all = [ble, ingest, sleep, db, haptic, ui];
}

/// Singola voce di log strutturato
class LogEntry {
  final DateTime timestamp;
  final LogLevel level;
  final String tag;
  final String message;
  final Object? error;
  final StackTrace? stackTrace;

  LogEntry({
    required this.timestamp,
    required this.level,
    required this.tag,
    required this.message,
    this.error,
    this.stackTrace,
  });

  String get formatted {
    final ts = timestamp.toIso8601String();
    final errStr = error != null ? ' | Error: $error' : '';
    return '$ts [${level.label}] $tag $message$errStr';
  }

  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp.toUtc().toIso8601String(),
      'level': level.label,
      'tag': tag,
      'message': message,
      if (error != null) 'error': error.toString(),
      if (stackTrace != null) 'stackTrace': stackTrace.toString(),
    };
  }

  @override
  String toString() => formatted;
}

/// Logger strutturato con buffer circolare RAM (200 messaggi)
/// e rotazione su file in cartella logs/ (max 5 file da 2MB).
class StructuredLogger {
  static StructuredLogger? _instance;
  static StructuredLogger get instance => _instance ??= StructuredLogger();
  static bool enableFileFlushTimer = true;

  final Directory? _customLogsDir;
  final int maxFileSizeBytes;
  final int maxFiles;
  final int bufferCapacity;
  final bool printToConsole;

  final Queue<LogEntry> _recentBuffer = Queue<LogEntry>();
  final StreamController<LogEntry> _logStreamController =
      StreamController<LogEntry>.broadcast();

  IOSink? _currentFileSink;
  File? _currentFile;
  int _currentFileBytes = 0;
  bool _isRotating = false;
  final List<String> _pendingFileWrites = [];
  Timer? _fileFlushTimer;

  StructuredLogger({
    Directory? logsDirectory,
    this.maxFileSizeBytes = 2 * 1024 * 1024, // 2MB
    this.maxFiles = 5,
    this.bufferCapacity = 200,
    this.printToConsole = true,
  }) : _customLogsDir = logsDirectory {
    _startFileFlushTimer();
  }

  /// Inizializza o reimposta l'istanza singleton (utile nei test)
  static void setMockInstance(StructuredLogger mock) {
    _instance?.dispose();
    _instance = mock;
  }

  /// Stream reattivo dei nuovi log per la UI
  Stream<LogEntry> get logStream => _logStreamController.stream;

  /// Buffer circolare degli ultimi messaggi in RAM (max 200)
  List<LogEntry> get recentLogs => _recentBuffer.toList();

  /// Filtra i log recenti per tag
  List<LogEntry> getRecentLogsByTag(String tag) {
    return _recentBuffer.where((e) => e.tag == tag).toList();
  }

  /// Filtra i log recenti per livello minimo
  List<LogEntry> getRecentLogsByLevel(LogLevel level) {
    return _recentBuffer.where((e) => e.level.index >= level.index).toList();
  }

  // Metodi di logging rapidi
  void debug(String tag, String message, {Object? error, StackTrace? stackTrace}) =>
      log(LogLevel.debug, tag, message, error, stackTrace);

  void info(String tag, String message, {Object? error, StackTrace? stackTrace}) =>
      log(LogLevel.info, tag, message, error, stackTrace);

  void warn(String tag, String message, {Object? error, StackTrace? stackTrace}) =>
      log(LogLevel.warn, tag, message, error, stackTrace);

  void warning(String tag, String message, {Object? error, StackTrace? stackTrace}) =>
      log(LogLevel.warn, tag, message, error, stackTrace);

  void error(String tag, String message, {Object? error, StackTrace? stackTrace}) =>
      log(LogLevel.error, tag, message, error, stackTrace);

  /// Registra un evento di log
  void log(
    LogLevel level,
    String tag,
    String message, [
    Object? err,
    StackTrace? st,
  ]) {
    final entry = LogEntry(
      timestamp: DateTime.now(),
      level: level,
      tag: tag.startsWith('[') ? tag : '[$tag]',
      message: message,
      error: err,
      stackTrace: st,
    );

    // 1. Buffer circolare RAM (max 200)
    _recentBuffer.addLast(entry);
    while (_recentBuffer.length > bufferCapacity) {
      _recentBuffer.removeFirst();
    }

    // 2. Notifica Stream per la UI
    if (!_logStreamController.isClosed) {
      _logStreamController.add(entry);
    }

    // 3. Stampa console / debugPrint
    if (printToConsole) {
      debugPrint(entry.formatted);
      if (st != null) {
        debugPrint(st.toString());
      }
    }

    // 4. Coda di scrittura su file rotante
    _pendingFileWrites.add('${entry.formatted}\n');
  }

  void _startFileFlushTimer() {
    if (!enableFileFlushTimer) return;
    _fileFlushTimer?.cancel();
    _fileFlushTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      flushToFile();
    });
  }

  Future<Directory> getLogsDirectory() async {
    if (_customLogsDir != null) {
      if (!_customLogsDir!.existsSync()) {
        _customLogsDir!.createSync(recursive: true);
      }
      return _customLogsDir!;
    }

    try {
      final appDocs = await getApplicationDocumentsDirectory();
      final logsDir = Directory(p.join(appDocs.path, 'logs'));
      if (!logsDir.existsSync()) {
        logsDir.createSync(recursive: true);
      }
      return logsDir;
    } catch (_) {
      final fallbackDir = Directory('logs');
      if (!fallbackDir.existsSync()) {
        fallbackDir.createSync(recursive: true);
      }
      return fallbackDir;
    }
  }

  /// Scrive i messaggi pendenti su file ed esegue rotazione se necessario
  Future<void> flushToFile() async {
    if (_pendingFileWrites.isEmpty || _isRotating) return;

    final toWrite = List<String>.from(_pendingFileWrites);
    _pendingFileWrites.clear();

    try {
      final dir = await getLogsDirectory();
      _currentFile ??= File(p.join(dir.path, 'whoop_app.log'));

      if (!await _currentFile!.exists()) {
        await _currentFile!.create(recursive: true);
        _currentFileBytes = 0;
      } else if (_currentFileBytes == 0) {
        _currentFileBytes = await _currentFile!.length();
      }

      final combined = toWrite.join();
      final addedBytes = combined.length;

      // Verifica rotazione file (max 2MB)
      if (_currentFileBytes + addedBytes > maxFileSizeBytes) {
        await _rotateLogFiles(dir);
      }

      _currentFileSink ??= _currentFile!.openWrite(mode: FileMode.append);
      _currentFileSink!.write(combined);
      await _currentFileSink!.flush();
      _currentFileBytes += addedBytes;
    } catch (e) {
      // In caso di errore riaccoda
      _pendingFileWrites.insertAll(0, toWrite);
    }
  }

  /// Ruota i file di log fino a maxFiles (es. whoop_app.log -> whoop_app.1.log -> ...)
  Future<void> _rotateLogFiles(Directory dir) async {
    _isRotating = true;
    try {
      if (_currentFileSink != null) {
        await _currentFileSink!.flush();
        await _currentFileSink!.close();
        _currentFileSink = null;
      }

      // Elimina il file più vecchio se esiste
      final oldestFile = File(p.join(dir.path, 'whoop_app.${maxFiles - 1}.log'));
      if (await oldestFile.exists()) {
        await oldestFile.delete();
      }

      // Rinomina i file precedenti a catena decrescente
      for (int i = maxFiles - 2; i >= 1; i--) {
        final src = File(p.join(dir.path, 'whoop_app.$i.log'));
        final dest = File(p.join(dir.path, 'whoop_app.${i + 1}.log'));
        if (await src.exists()) {
          await src.rename(dest.path);
        }
      }

      // Rinomina file attivo in whoop_app.1.log
      final baseFile = File(p.join(dir.path, 'whoop_app.log'));
      if (await baseFile.exists()) {
        await baseFile.rename(p.join(dir.path, 'whoop_app.1.log'));
      }

      _currentFile = File(p.join(dir.path, 'whoop_app.log'));
      await _currentFile!.create(recursive: true);
      _currentFileBytes = 0;
      _currentFileSink = _currentFile!.openWrite(mode: FileMode.append);
    } finally {
      _isRotating = false;
    }
  }

  /// Elenca tutti i file di log presenti su disco
  Future<List<File>> getLogFiles() async {
    final dir = await getLogsDirectory();
    if (!dir.existsSync()) return [];
    final files = dir
        .listSync()
        .whereType<File>()
        .where((f) => p.basename(f.path).startsWith('whoop_app') && f.path.endsWith('.log'))
        .toList();
    files.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
    return files;
  }

  /// Svuota il buffer circolare in RAM
  void clearBuffer() {
    _recentBuffer.clear();
  }

  /// Rilascia le risorse
  Future<void> dispose() async {
    _fileFlushTimer?.cancel();
    _fileFlushTimer = null;
    await flushToFile();
    if (_currentFileSink != null) {
      await _currentFileSink!.flush();
      await _currentFileSink!.close();
      _currentFileSink = null;
    }
    if (!_logStreamController.isClosed) {
      await _logStreamController.close();
    }
  }
}
