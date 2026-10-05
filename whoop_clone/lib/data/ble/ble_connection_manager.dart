import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'hr_data_packet.dart';
import 'whoop_96byte_packet.dart';
import 'noop_protocol_decoder.dart';
import '../services/overnight_sleep_engine.dart';
import '../database/database_helper.dart';
import 'ble_diagnostic_service.dart';
import '../services/raw_capture_service.dart';
import '../../core/logging/structured_logger.dart';

enum BleState {
  disconnected,
  scanning,
  connecting,
  discovering,
  subscribing,
  initializing,
  syncingHistory,
  streaming,
  reconnecting,
  failed,

  // Compatibilità per UI e test legacy
  requestingPermissions,
  bonding,
  connected,
  error,
}

/// Risultato veritiero dell'invio del comando di vibrazione (Truthful Haptics)
enum HapticResultStatus {
  phoneHapticOnly,
  strapCommandSent,
  strapAcknowledged,
  strapFailed,
  notConnected;

  bool get isStrapSuccess =>
      this == HapticResultStatus.strapCommandSent ||
      this == HapticResultStatus.strapAcknowledged;
  bool get wasPhoneVibrated =>
      this == HapticResultStatus.phoneHapticOnly ||
      this == HapticResultStatus.strapCommandSent ||
      this == HapticResultStatus.strapAcknowledged ||
      this == HapticResultStatus.strapFailed;
}

/// BLE-06: Evento di disconnessione tracciato con status code nativo e diagnostica
class DisconnectionEvent {
  final DateTime timestamp;
  final int? statusCode;
  final String reason;
  final Duration sessionDuration;

  DisconnectionEvent({
    required this.timestamp,
    this.statusCode,
    required this.reason,
    required this.sessionDuration,
  });

  @override
  String toString() =>
      'DisconnectionEvent(timestamp: $timestamp, code: $statusCode, reason: $reason, duration: ${sessionDuration.inSeconds}s)';
}

/// BLE-06: Interprete dei codici di disconnessione standard Android / iOS GATT
String interpretDisconnectCode(int? code, [String? description]) {
  if (code == null) return description ?? 'Disconnessione sconosciuta';
  switch (code) {
    case 0:
      return 'GATT_SUCCESS (Disconnessione normale)';
    case 8:
      return 'GATT_CONN_TIMEOUT (Timeout di connessione superato)';
    case 19:
      return 'GATT_CONN_TERMINATE_PEER_USER (Terminata dal cinturino/peer)';
    case 22:
      return 'GATT_CONN_TERMINATE_LOCAL_HOST (Terminata dall\'host locale)';
    case 34:
      return 'GATT_CONN_LMP_TIMEOUT (LMP Response Timeout)';
    case 62:
      return 'GATT_CONN_FAIL_ESTABLISH (Impossibile stabilire connessione)';
    case 133:
      return 'GATT_ERROR 133 (Errore stack Android / Dispositivo non raggiungibile)';
    default:
      if (description != null && description.isNotEmpty) {
        return 'GATT Error $code ($description)';
      }
      return 'GATT Error $code';
  }
}

/// BleConnectionManager gestisce la connessione BLE con il bracciale Whoop:
/// BLE-01: Single-flight lock, protezione disconnect in connecting, backoff esponenziale con jitter e reset solo dopo >60s streaming.
/// BLE-02: Unico percorso reattivo di bind da listener connected, guard atomica _bindInProgress, cancellazione preventiva sottoscrizioni.
/// BLE-03: Scansione ordinata (stopScan prima di connect), blocco scansione se in connecting, bonding eseguito una sola volta se non bonded.
/// BLE-04: Coda TX asincrona non bloccante per ACK Opcode 23 storico (nessun await nel listener 1Hz, nessun ACK in streaming live).
/// BLE-05: Politica autoConnect uniforme (false per manuale, true per background).
/// BLE-06: Tracciamento status code reali di disconnessione in lista circolare (ultimi 20 eventi).
/// Data Watchdog: Connessione zombie interrotta se nessun dato per >15s in streaming.
class BleConnectionManager {
  static const String heartRateServiceUuid = '180d';
  static const String heartRateCharUuid = '2a37';
  static const String batteryServiceUuid = '180f';
  static const String batteryLevelCharUuid = '2a19';

  // UUID proprietari WHOOP 5.0 / 4.0 (da ryanbr/noop)
  static const String whoop4ServiceUuid = '61080001-8d6d-82b8-614a-1c8cb0f8dcc6';
  static const String whoop4TxCharUuid = '61080002-8d6d-82b8-614a-1c8cb0f8dcc6';
  static const String whoop4AckCharUuid = '61080003-8d6d-82b8-614a-1c8cb0f8dcc6';
  static const String whoop4Rx96ByteCharUuid = '61080005-8d6d-82b8-614a-1c8cb0f8dcc6';

  static const String whoop5ServiceUuid = 'fd4b0001-8d6d-82b8-614a-1c8cb0f8dcc6';
  static const String whoop5TxCharUuid = 'fd4b0002-8d6d-82b8-614a-1c8cb0f8dcc6';
  static const String whoop5AckCharUuid = 'fd4b0003-8d6d-82b8-614a-1c8cb0f8dcc6';
  static const String whoop5Rx96ByteCharUuid = 'fd4b0005-8d6d-82b8-614a-1c8cb0f8dcc6';

  BleState _state = BleState.disconnected;
  String? _statusMessage;
  BluetoothDevice? _connectedDevice;
  int? _batteryLevelPct;
  int _autoReconnectAttempts = 0;
  int _backoffAttempt = 0;
  final math.Random _random = math.Random();

  // BLE-01: Lock atomico single-flight per tentativi di connessione
  bool _isConnecting = false;
  // BLE-02: Guard atomica per impedire binding paralleli
  bool _bindInProgress = false;
  // BLE-03: Set dei dispositivi per cui è già stato richiesto/verificato il bonding
  final Set<String> _bondedDevices = <String>{};

  // BLE-04: Coda di scrittura asincrona non bloccante
  final List<Uint8List> _txQueue = [];
  bool _isTxProcessing = false;

  // BLE-06: Lista circolare ultimi 20 eventi di disconnessione
  final List<DisconnectionEvent> _disconnectionHistory = [];
  DateTime? _sessionStartTime;

  bool _isProprietaryChannelActive = false;
  bool _fallbackModeActive = false;
  BluetoothCharacteristic? _cmdToStrapChar;

  final StreamController<HrDataPacket> _hrStreamController =
      StreamController<HrDataPacket>.broadcast();
  // ignore: non_constant_identifier_names
  final StreamController<Whoop96BytePacket> _96ByteStreamController =
      StreamController<Whoop96BytePacket>.broadcast();
  final StreamController<BleState> _stateStreamController =
      StreamController<BleState>.broadcast();
  final StreamController<int> _batteryStreamController =
      StreamController<int>.broadcast();
  final StreamController<List<int>> _ackNotificationStreamController =
      StreamController<List<int>>.broadcast();

  StreamSubscription<List<ScanResult>>? _scanSubscription;
  StreamSubscription<BluetoothConnectionState>? _connectionSubscription;
  StreamSubscription<List<int>>? _hrNotificationSubscription;
  // ignore: non_constant_identifier_names
  StreamSubscription<List<int>>? _96ByteNotificationSubscription;
  StreamSubscription<List<int>>? _batteryNotificationSubscription;
  StreamSubscription<List<int>>? _ackNotificationSubscription;
  StreamSubscription<List<int>>? _eventsNotificationSubscription;

  Timer? _reconnectTimer;
  Timer? _proprietaryTimeoutTimer;
  Timer? _stateTransitionTimer;
  Timer? _stableStreamingTimer;
  Timer? _dataWatchdogTimer;

  // Data Watchdog: timeout 15 secondi per assenza dati in streaming
  static const Duration defaultDataWatchdogTimeout = Duration(seconds: 15);
  Duration dataWatchdogTimeout = defaultDataWatchdogTimeout;

  // Getters
  BleState get state => _state;
  bool get isConnected =>
      _state == BleState.connected ||
      _state == BleState.streaming ||
      _state == BleState.syncingHistory;
  bool get isStreaming => _state == BleState.streaming;
  bool get isConnecting => _isConnecting || _state == BleState.connecting;
  String? get statusMessage => _statusMessage;
  BluetoothDevice? get connectedDevice => _connectedDevice;
  int? get batteryLevelPct => _batteryLevelPct;
  bool get isProprietaryChannelActive => _isProprietaryChannelActive;
  bool get fallbackModeActive => _fallbackModeActive;
  List<DisconnectionEvent> get disconnectionHistory => List.unmodifiable(_disconnectionHistory);
  int get backoffAttempt => _backoffAttempt;
  int get autoReconnectAttempts => _autoReconnectAttempts;

  Stream<HrDataPacket> get hrStream => _hrStreamController.stream;
  Stream<Whoop96BytePacket> get packet96ByteStream => _96ByteStreamController.stream;
  Stream<BleState> get stateStream => _stateStreamController.stream;
  Stream<int> get batteryStream => _batteryStreamController.stream;
  Stream<List<int>> get ackNotificationStream => _ackNotificationStreamController.stream;
  Stream<List<ScanResult>> get scanResultsStream => FlutterBluePlus.scanResults;

  void _updateState(BleState newState, [String? message, Duration? transitionTimeout]) {
    _stateTransitionTimer?.cancel();
    _state = newState;
    _statusMessage = message;

    // Gestione timer watchdog e stabilità in base al nuovo stato
    if (newState == BleState.streaming) {
      _startDataWatchdog();
      _startStableStreamingTimer();
    } else if (newState != BleState.syncingHistory) {
      _dataWatchdogTimer?.cancel();
      _stableStreamingTimer?.cancel();
    }

    if (!_stateStreamController.isClosed) {
      _stateStreamController.add(_state);
    }

    BleDiagnosticService.instance.recordStateTransition(newState, message);
    StructuredLogger.instance.info(
      LogTag.ble,
      'Transizione stato BLE: $newState ${message != null ? "($message)" : ""}',
    );

    final isTransient = newState == BleState.connecting ||
        newState == BleState.discovering ||
        newState == BleState.subscribing ||
        newState == BleState.initializing ||
        newState == BleState.syncingHistory ||
        newState == BleState.bonding ||
        newState == BleState.requestingPermissions;

    if (isTransient) {
      final timeoutDuration = transitionTimeout ?? const Duration(seconds: 15);
      _stateTransitionTimer = Timer(timeoutDuration, () {
        if (_state == newState) {
          debugPrint('BleConnectionManager: TIMEOUT transizione stato $newState superato (${timeoutDuration.inSeconds}s)');
          _recordDisconnection(8, 'Timeout transizione di stato: $newState');
          _updateState(BleState.failed, 'Timeout transizione per lo stato $newState');
          _handleAutoReconnection();
        }
      });
    }
  }

  void resetStateForTest() {
    _stateTransitionTimer?.cancel();
    _stateTransitionTimer = null;
    _dataWatchdogTimer?.cancel();
    _dataWatchdogTimer = null;
    _stableStreamingTimer?.cancel();
    _stableStreamingTimer = null;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _cancelAllSubscriptions();
    _txQueue.clear();
    _disconnectionHistory.clear();
    _bondedDevices.clear();
    _isConnecting = false;
    _bindInProgress = false;
    _isTxProcessing = false;
    _backoffAttempt = 0;
    _sessionStartTime = null;
    _state = BleState.disconnected;
    _statusMessage = null;
    _connectedDevice = null;
    _cmdToStrapChar = null;
    _isProprietaryChannelActive = false;
    _fallbackModeActive = false;
    _batteryLevelPct = null;
    if (!_stateStreamController.isClosed) {
      _stateStreamController.add(_state);
    }
  }

  /// Cancella tutte le sottoscrizioni a notifiche BLE
  void _cancelAllSubscriptions() {
    _hrNotificationSubscription?.cancel();
    _hrNotificationSubscription = null;
    _96ByteNotificationSubscription?.cancel();
    _96ByteNotificationSubscription = null;
    _batteryNotificationSubscription?.cancel();
    _batteryNotificationSubscription = null;
    _ackNotificationSubscription?.cancel();
    _ackNotificationSubscription = null;
    _eventsNotificationSubscription?.cancel();
    _eventsNotificationSubscription = null;
  }

  /// 1. Richiesta permessi Android per Bluetooth e Posizione
  Future<bool> requestBlePermissions() async {
    _updateState(BleState.requestingPermissions, 'Richiesta permessi Android...');

    try {
      Map<Permission, PermissionStatus> statuses = await [
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.notification,
        Permission.locationWhenInUse,
        Permission.location,
        Permission.bluetooth,
        Permission.ignoreBatteryOptimizations,
      ].request();

      try {
        final adapterState = await FlutterBluePlus.adapterState.first;
        if (adapterState != BluetoothAdapterState.on) {
          await FlutterBluePlus.turnOn();
        }
      } catch (_) {}

      final scanGranted = statuses[Permission.bluetoothScan]?.isGranted ?? true;
      final connectGranted = statuses[Permission.bluetoothConnect]?.isGranted ?? true;
      final locationGranted = (statuses[Permission.locationWhenInUse]?.isGranted ?? false) ||
          (statuses[Permission.location]?.isGranted ?? false);

      if (!scanGranted || !connectGranted || !locationGranted) {
        _updateState(BleState.error, 'Permessi Bluetooth/Posizione non concessi.');
        return false;
      }
      return true;
    } catch (e) {
      debugPrint('BleConnectionManager: Errore durante richiesta permessi: $e');
      _updateState(BleState.error, 'Errore richiesta permessi: $e');
      return false;
    }
  }

  /// Avvia la scansione BLE attiva
  /// BLE-03: Non avvia la scansione se un tentativo di connessione è già in corso
  Future<void> startScanOnly({Duration timeout = const Duration(seconds: 15)}) async {
    if (isConnecting) {
      debugPrint('BleConnectionManager: startScanOnly ignorato - connessione in corso (BLE-03)');
      return;
    }

    final hasPermissions = await requestBlePermissions();
    if (!hasPermissions) return;

    _updateState(BleState.scanning, 'Scansione dispositivi BLE nelle vicinanze...');

    try {
      await FlutterBluePlus.startScan(
        timeout: timeout,
        androidUsesFineLocation: true,
      );
    } catch (e) {
      _updateState(BleState.error, 'Errore avvio scansione BLE: $e');
    }
  }

  /// Connette ad uno specifico dispositivo selezionato
  /// BLE-01: Single-flight lock
  /// BLE-03: Ferma immediatamente la scansione prima di iniziare connect()
  Future<void> connectToSpecificDevice(BluetoothDevice device, {bool isAutoReconnect = false}) async {
    if (isConnecting) {
      debugPrint('BleConnectionManager: connectToSpecificDevice ignorato - connessione già in corso (BLE-01)');
      return;
    }

    try {
      _scanSubscription?.cancel();
      _scanSubscription = null;
      await FlutterBluePlus.stopScan();
    } catch (_) {}

    await _connectToDevice(device, isAutoReconnect: isAutoReconnect);
  }

  /// Alias per compatibilità
  Future<void> connectToDevice(BluetoothDevice device, {bool isAutoReconnect = false}) =>
      connectToSpecificDevice(device, isAutoReconnect: isAutoReconnect);

  /// Scansione automatica e prima connessione Whoop trovata
  /// BLE-03: Non avvia se isConnecting; ferma scansione prima di connettere
  Future<void> startScanAndConnect() async {
    if (isConnecting) {
      debugPrint('BleConnectionManager: startScanAndConnect ignorato - connessione in corso (BLE-03)');
      return;
    }

    final hasPermissions = await requestBlePermissions();
    if (!hasPermissions) return;

    _updateState(BleState.scanning, 'Scansione dispositivi Whoop in corso...');

    try {
      _scanSubscription?.cancel();
      _scanSubscription = FlutterBluePlus.scanResults.listen((results) async {
        for (ScanResult r in results) {
          final deviceName = r.device.platformName.toUpperCase();
          final advName = r.advertisementData.advName.toUpperCase();

          if (deviceName.contains('WHOOP') ||
              advName.contains('WHOOP') ||
              deviceName.contains('WP4') ||
              deviceName.contains('WP5')) {
            // BLE-03: Ferma immediatamente la scansione prima di avviare connect()
            await _scanSubscription?.cancel();
            _scanSubscription = null;
            try {
              await FlutterBluePlus.stopScan();
            } catch (_) {}
            await _connectToDevice(r.device, isAutoReconnect: false);
            break;
          }
        }
      });

      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 15),
        androidUsesFineLocation: true,
      );
    } catch (e) {
      _updateState(BleState.error, 'Errore avvio scansione: $e');
    }
  }

  /// Salva l'ID/MAC del dispositivo accoppiato per la riconnessione automatica (SharedPreferences + SQLite)
  Future<void> _savePairedDeviceId(String deviceId, [String? deviceName]) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('whoop_paired_device_id', deviceId);
      debugPrint('BleConnectionManager: Salvato ID dispositivo accoppiato: $deviceId');

      try {
        final db = await DatabaseHelper().database;
        final updateMap = <String, dynamic>{
          'paired_device_mac': deviceId,
        };
        if (deviceName != null && deviceName.isNotEmpty) {
          updateMap['paired_device_name'] = deviceName;
        }
        await db.update(
          DatabaseHelper.tableUtenteProfilo,
          updateMap,
          where: 'id = ?',
          whereArgs: [1],
        );
      } catch (_) {}
    } catch (e) {
      debugPrint('Errore salvataggio ID dispositivo: $e');
    }
  }

  /// Legge l'ID/MAC del dispositivo accoppiato salvato in SharedPreferences (con fallback su SQLite)
  Future<String?> getPairedDeviceId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final id = prefs.getString('whoop_paired_device_id');
      if (id != null && id.isNotEmpty) return id;

      try {
        final profile = await DatabaseHelper().getUserProfile();
        final dbMac = profile?['paired_device_mac'] as String?;
        if (dbMac != null && dbMac.isNotEmpty) {
          await prefs.setString('whoop_paired_device_id', dbMac);
          return dbMac;
        }
      } catch (_) {}

      return null;
    } catch (_) {
      return null;
    }
  }

  /// Dimentica l'accoppiamento con il dispositivo WHOOP corrente
  Future<void> forgetDevice() async {
    if (_state != BleState.connecting && !_isConnecting) {
      await disconnect();
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('whoop_paired_device_id');
    } catch (_) {}
    try {
      final db = await DatabaseHelper().database;
      await db.update(
        DatabaseHelper.tableUtenteProfilo,
        {
          'paired_device_mac': null,
          'paired_device_name': null,
        },
        where: 'id = ?',
        whereArgs: [1],
      );
    } catch (_) {}
  }

  /// 2. Flusso Zero-Scan all'avvio dell'applicazione
  /// BLE-01: Single-flight lock idempotente; NON esegue disconnect se connecting
  /// BLE-05: autoConnect: false per manuale, autoConnect: true per background reconnection
  Future<bool> connectSavedDevice({bool isAutoReconnect = false}) async {
    if (isConnecting) {
      debugPrint('BleConnectionManager: connectSavedDevice ignorato - connessione già in corso (BLE-01)');
      return false;
    }

    final savedId = await getPairedDeviceId();
    if (savedId == null || savedId.isEmpty) {
      debugPrint('BleConnectionManager: Nessun ID salvato. Avvio scansione...');
      await startScanAndConnect();
      return false;
    }

    _isConnecting = true;
    _updateState(BleState.connecting, 'Riconnessione al cinturino WHOOP...');
    debugPrint('BleConnectionManager: Flusso Zero-Scan per dispositivo salvato: $savedId (autoConnect: $isAutoReconnect)');

    try {
      final device = BluetoothDevice.fromId(savedId);
      _connectedDevice = device;

      List<BluetoothDevice> systemDevices = [];
      try {
        systemDevices = await FlutterBluePlus.systemDevices([]);
      } catch (_) {}

      bool isAlreadyConnectedToOs = systemDevices.any((d) => d.remoteId.str == savedId);

      // BLE-02: Configura l'UNICO listener di stato da cui partirà _bindToDevice
      _setupConnectionStateListener(device);

      if (isAlreadyConnectedToOs) {
        debugPrint('BleConnectionManager: Dispositivo già connesso a livello OS.');
        try {
          final currentConnState = await device.connectionState.first.timeout(
            const Duration(seconds: 2),
            onTimeout: () => BluetoothConnectionState.connected,
          );
          if (currentConnState == BluetoothConnectionState.connected && _state != BleState.connected) {
            _sessionStartTime ??= DateTime.now();
            _updateState(BleState.connected, 'WHOOP Connesso');
            await _bindToDevice(device);
          }
        } catch (_) {}
        return true;
      } else {
        // BLE-05: Connessione con autoConnect configurato e timeout pulito di 15s
        await device.connect(
          autoConnect: isAutoReconnect,
          timeout: const Duration(seconds: 15),
        );
        // BLE-02: _bindToDevice partirà dal connectionState listener
        return true;
      }
    } catch (e) {
      debugPrint('BleConnectionManager: Errore connessione dispositivo salvato ($e)');
      _recordDisconnection(8, 'Timeout o fallimento connessione saved device: $e');
      _updateState(BleState.reconnecting, 'Riconnessione in corso...');
      _handleAutoReconnection();
      return false;
    } finally {
      _isConnecting = false;
    }
  }

  /// 3. Connessione e Pairing con il Sensore
  /// BLE-01: Single-flight lock idempotente
  /// BLE-02: NON invoca _bindToDevice direttamente qui (unico percorso dal listener)
  /// BLE-03: Bonding eseguito solo una volta e solo se non già bonded
  /// BLE-05: autoConnect: false per prima connessione
  Future<void> _connectToDevice(BluetoothDevice device, {bool isAutoReconnect = false}) async {
    if (isConnecting) {
      debugPrint('BleConnectionManager: _connectToDevice ignorato - connessione già in corso (BLE-01)');
      return;
    }
    _isConnecting = true;
    _updateState(BleState.connecting, 'Connessione a ${device.platformName}...');
    _connectedDevice = device;

    try {
      await _savePairedDeviceId(device.remoteId.str, device.platformName);

      // BLE-02: Configura l'UNICO listener di stato
      _setupConnectionStateListener(device);

      // BLE-03: Bonding ordinato
      await _ensureBonded(device);

      // BLE-05: Connessione con timeout 15s
      await device.connect(
        autoConnect: isAutoReconnect,
        timeout: const Duration(seconds: 15),
      );

      // BLE-02: Non invochiamo _bindToDevice qui!
      // Verrà scatenato UNICAMENTE da _setupConnectionStateListener quando state == connected
    } catch (e) {
      debugPrint('BleConnectionManager: Errore durante connect: $e');
      _recordDisconnection(133, 'Errore di connessione BLE: $e');
      _updateState(BleState.failed, 'Errore di connessione BLE: $e');
      _handleAutoReconnection();
    } finally {
      _isConnecting = false;
    }
  }

  /// BLE-02 & BLE-06: Configura l'UNICO listener di stato del dispositivo
  void _setupConnectionStateListener(BluetoothDevice device) {
    _connectionSubscription?.cancel();
    _connectionSubscription = device.connectionState.listen((connState) async {
      debugPrint('BleConnectionManager: ConnectionState reattivo -> $connState');
      if (connState == BluetoothConnectionState.connected) {
        _sessionStartTime ??= DateTime.now();
        _updateState(BleState.connected, 'WHOOP Connesso');
        await _bindToDevice(device);
      } else if (connState == BluetoothConnectionState.disconnected) {
        final code = device.disconnectReason?.code;
        final desc = device.disconnectReason?.description;
        _recordDisconnection(code, desc);
        _cancelAllSubscriptions();
        _dataWatchdogTimer?.cancel();
        _stableStreamingTimer?.cancel();
        _bindInProgress = false;
        _updateState(BleState.disconnected, 'Connessione al cinturino WHOOP interrotta.');
        _handleAutoReconnection();
      }
    });
  }

  /// BLE-03: Verifica ed esecuzione ordinata del bonding (solo Android, una volta per sessione)
  Future<void> _ensureBonded(BluetoothDevice device) async {
    if (kIsWeb) return;
    if (defaultTargetPlatform != TargetPlatform.android) return;

    final deviceId = device.remoteId.str;
    if (_bondedDevices.contains(deviceId)) {
      debugPrint('BleConnectionManager: Dispositivo $deviceId già verificato come bonded.');
      return;
    }

    try {
      BluetoothBondState currentBond = device.prevBondState ?? BluetoothBondState.none;
      if (currentBond != BluetoothBondState.bonded) {
        try {
          currentBond = await device.bondState.first.timeout(const Duration(seconds: 2));
        } catch (_) {}
      }

      if (currentBond == BluetoothBondState.bonded) {
        _bondedDevices.add(deviceId);
        debugPrint('BleConnectionManager: Dispositivo $deviceId già accoppiato/bonded.');
        return;
      }

      _updateState(BleState.bonding, 'Creazione Bonding / Pairing BLE...');
      debugPrint('BleConnectionManager: Invocazione createBond per $deviceId...');
      await device.createBond().timeout(const Duration(seconds: 10));
      _bondedDevices.add(deviceId);
      debugPrint('BleConnectionManager: createBond completato per $deviceId.');
    } catch (e) {
      debugPrint('BleConnectionManager: Avviso createBond: $e');
    }
  }

  /// BLE-02: Binding e sottoscrizione GATT (Unico Percorso di Bind protetto da guard atomica)
  Future<void> _bindToDevice(BluetoothDevice device) async {
    if (_bindInProgress) {
      debugPrint('BleConnectionManager: _bindToDevice già in corso (guard atomica BLE-02). Ignoro chiamata.');
      return;
    }
    _bindInProgress = true;
    debugPrint('BleConnectionManager: Avvio _bindToDevice (Unico percorso)');

    try {
      // 1. Elimina/cancella esplicitamente le sottoscrizioni precedenti prima di ri-sottoscrivere
      _cancelAllSubscriptions();

      // 2. Avvia il Foreground Service Android nativo per connessione persistente
      _startNativeForegroundService();

      // 3. Negoziazione MTU a 247 sequenziale
      try {
        await device.requestMtu(247).timeout(const Duration(seconds: 4));
        debugPrint('BleConnectionManager: MTU 247 negoziata con successo');
      } catch (e) {
        debugPrint('BleConnectionManager: MTU request fallback/warning: $e');
      }

      // 4. Discovery e sottoscrizione sequenziale
      await _discoverAndSetupServices(device);
    } catch (e) {
      debugPrint('BleConnectionManager: Errore durante _bindToDevice: $e');
      _updateState(BleState.failed, 'Errore configurazione servizi: $e');
    } finally {
      _bindInProgress = false;
    }
  }

  Future<void> _startNativeForegroundService() async {
    try {
      const channel = MethodChannel('com.example.whoop_clone/foreground_service');
      await channel.invokeMethod('startForegroundService');
      debugPrint('BleConnectionManager: Avviato Android Foreground Service per connessione BLE persistente ad app chiusa');
    } catch (e) {
      debugPrint('BleConnectionManager: Fallback/non-Android Foreground Service: $e');
    }
  }

  /// 4. Discovery dei Servizi GATT e Sottoscrizione Sequenziale
  Future<void> _discoverAndSetupServices(BluetoothDevice device) async {
    _updateState(BleState.discovering, 'Discovery servizi GATT in corso...');
    _cmdToStrapChar = null;
    List<BluetoothService> services = await device.discoverServices();
    BluetoothService? whoopProprietaryService;
    BluetoothCharacteristic? hrChar;
    BluetoothCharacteristic? batteryChar;

    for (BluetoothService service in services) {
      final uuidStr = service.uuid.toString().toLowerCase();

      // Service 0x180D (Heart Rate Standard)
      if (uuidStr.contains(heartRateServiceUuid)) {
        for (BluetoothCharacteristic c in service.characteristics) {
          if (c.uuid.toString().toLowerCase().contains(heartRateCharUuid)) {
            hrChar = c;
          }
        }
      }

      // Service 0x180F (Battery Service Standard)
      if (uuidStr.contains(batteryServiceUuid)) {
        for (BluetoothCharacteristic c in service.characteristics) {
          if (c.uuid.toString().toLowerCase().contains(batteryLevelCharUuid)) {
            batteryChar = c;
          }
        }
      }

      // Canale Proprietario WHOOP (Service 61080001 o FD4B0001)
      if (uuidStr.contains('6108') || uuidStr.contains('fd4b')) {
        whoopProprietaryService = service;
      }
    }

    _updateState(BleState.subscribing, 'Sottoscrizione canali telemetrici in corso...');

    if (whoopProprietaryService != null) {
      BluetoothCharacteristic? eventsChar;
      BluetoothCharacteristic? memfaultChar;
      BluetoothCharacteristic? dataChar;
      BluetoothCharacteristic? cmdFromStrapChar;

      for (BluetoothCharacteristic c in whoopProprietaryService.characteristics) {
        final cUuid = c.uuid.toString().toLowerCase();

        // 61080004 / fd4b0004: EVENTS_FROM_STRAP
        if (cUuid.contains('61080004') || cUuid.contains('fd4b0004')) {
          eventsChar = c;
        }
        // 61080007 / fd4b0007: MEMFAULT / DIAGNOSTIC
        else if (cUuid.contains('61080007') || cUuid.contains('fd4b0007')) {
          memfaultChar = c;
        }
        // 61080005 / fd4b0005: DATA_FROM_STRAP (96-Byte Telemetry)
        else if (cUuid.contains('61080005') || cUuid.contains('fd4b0005')) {
          dataChar = c;
        }
        // 61080003 / fd4b0003: CMD_FROM_STRAP (ACK / Command Response)
        else if (cUuid.contains('61080003') || cUuid.contains('fd4b0003')) {
          cmdFromStrapChar = c;
        }
        // 61080002 / fd4b0002: CMD_TO_STRAP (Write Command)
        else if (cUuid.contains('61080002') || cUuid.contains('fd4b0002') || cUuid.contains('0010')) {
          _cmdToStrapChar = c;
          debugPrint('BleConnectionManager: Memorizzata CMD_TO_STRAP (${c.uuid})');
        }
      }

      // Fallback per CMD_TO_STRAP se non trovata esplicitamente
      if (_cmdToStrapChar == null) {
        for (BluetoothCharacteristic c in whoopProprietaryService.characteristics) {
          if (c.properties.writeWithoutResponse || c.properties.write) {
            _cmdToStrapChar = c;
            debugPrint('BleConnectionManager: Fallback CMD_TO_STRAP trovata (${c.uuid})');
            break;
          }
        }
      }

      // SOTTOSCRIZIONI NEL RIGIDO ORDINE RICHIESTO DALLA STRAP:
      // 1. Events (0004)
      if (eventsChar != null) {
        try {
          await eventsChar.setNotifyValue(true);
          _eventsNotificationSubscription?.cancel();
          final charUuidStr = eventsChar.uuid.toString();
          _eventsNotificationSubscription = eventsChar.onValueReceived.listen((eventBytes) {
            if (eventBytes.isNotEmpty) {
              final u8 = Uint8List.fromList(eventBytes);
              RawCaptureService.instance.recordNotification(charUuidStr, u8);
              BleDiagnosticService.instance.recordPacketReceived(charUuid: charUuidStr, bytes: u8);
              debugPrint('BleConnectionManager: Evento strap ricevuto (0004): $eventBytes');
            }
          });
          debugPrint('BleConnectionManager: [1/5] Sottoscritto canale 0004 (Events)');
        } catch (e) {
          debugPrint('BleConnectionManager: Errore sottoscrizione 0004 (Events): $e');
        }
      }

      // 2. Memfault (0007, se presente)
      if (memfaultChar != null) {
        try {
          await memfaultChar.setNotifyValue(true);
          debugPrint('BleConnectionManager: [2/5] Sottoscritto canale 0007 (Memfault)');
        } catch (_) {}
      }

      // 3. Data (0005) - Telemetria e Streaming 96-Byte
      // BLE-04: Listener non bloccante. Non invia ACK per lo streaming live a 1 Hz!
      if (dataChar != null) {
        try {
          await dataChar.setNotifyValue(true);
          _96ByteNotificationSubscription?.cancel();
          final dataCharUuidStr = dataChar.uuid.toString();
          _96ByteNotificationSubscription = dataChar.onValueReceived.listen((bytes) {
            if (bytes.length >= 96) {
              final bytesU8 = Uint8List.fromList(bytes);
              RawCaptureService.instance.recordNotification(dataCharUuidStr, bytesU8);
              BleDiagnosticService.instance.recordPacketReceived(charUuid: dataCharUuidStr, bytes: bytesU8);
              final p96 = Whoop96BytePacket.fromBytes(bytesU8);
              if (!_96ByteStreamController.isClosed) {
                _96ByteStreamController.add(p96);
              }
              _isProprietaryChannelActive = true;
              _fallbackModeActive = false;
              _onTelemetryDataReceived();

              // BLE-04: Non inviare ACK per i normali pacchetti live di streaming.
              // Solo durante sync storico (syncingHistory) si invia l'ACK opcode 23,
              // e viene accodato in modo asincrono non bloccante (NO await).
              if (_state == BleState.syncingHistory) {
                final ackFrame = Uint8List.fromList(
                  StoreAndForwardHandler.buildOpcode23HistoricalDataResult(p96.seqNumber),
                );
                enqueueCommand(ackFrame);
              }
            }
          });
          debugPrint('BleConnectionManager: [3/5] Sottoscritto canale 0005 (Data 96-Byte)');
        } catch (e) {
          debugPrint('BleConnectionManager: Errore sottoscrizione 0005 (Data): $e');
        }
      }

      // 4. Command Responses (0003)
      if (cmdFromStrapChar != null) {
        try {
          await cmdFromStrapChar.setNotifyValue(true);
          _ackNotificationSubscription?.cancel();
          final cmdCharUuidStr = cmdFromStrapChar.uuid.toString();
          _ackNotificationSubscription = cmdFromStrapChar.onValueReceived.listen((ackBytes) {
            if (ackBytes.isNotEmpty) {
              final bytesU8 = Uint8List.fromList(ackBytes);
              RawCaptureService.instance.recordNotification(cmdCharUuidStr, bytesU8);
              BleDiagnosticService.instance.recordPacketReceived(charUuid: cmdCharUuidStr, bytes: bytesU8);
              BleDiagnosticService.instance.recordAckReceived(ackBytes);
              StructuredLogger.instance.info(LogTag.ble, 'ACK/Response ricevuto da CMD_FROM_STRAP: $ackBytes');
              debugPrint('BleConnectionManager: ACK/Response ricevuto da CMD_FROM_STRAP: $ackBytes');
              if (!_ackNotificationStreamController.isClosed) {
                _ackNotificationStreamController.add(ackBytes);
              }
            }
          });
          debugPrint('BleConnectionManager: [4/5] Sottoscritto canale 0003 (Commands ACK)');
        } catch (e) {
          debugPrint('BleConnectionManager: Errore sottoscrizione 0003 (Commands): $e');
        }
      }

      // 5. Battery Service Standard (0x180F)
      if (batteryChar != null) {
        try {
          final val = await batteryChar.read();
          if (val.isNotEmpty) {
            _batteryLevelPct = val[0];
            if (!_batteryStreamController.isClosed) {
              _batteryStreamController.add(_batteryLevelPct!);
            }
          }
          if (batteryChar.properties.notify) {
            await batteryChar.setNotifyValue(true);
            _batteryNotificationSubscription?.cancel();
            final batteryCharUuidStr = batteryChar.uuid.toString();
            _batteryNotificationSubscription = batteryChar.onValueReceived.listen((val) {
              if (val.isNotEmpty) {
                final bytesU8 = Uint8List.fromList(val);
                RawCaptureService.instance.recordNotification(batteryCharUuidStr, bytesU8);
                BleDiagnosticService.instance.recordPacketReceived(charUuid: batteryCharUuidStr, bytes: bytesU8);
                _batteryLevelPct = val[0];
                if (!_batteryStreamController.isClosed) {
                  _batteryStreamController.add(_batteryLevelPct!);
                }
              }
            });
          }
        } catch (_) {}
      }

      // 6. Standard Heart Rate Service (0x180D -> 0x2A37)
      if (hrChar != null) {
        try {
          await hrChar.setNotifyValue(true);
          _hrNotificationSubscription?.cancel();
          final hrCharUuidStr = hrChar.uuid.toString();
          _hrNotificationSubscription = hrChar.onValueReceived.listen((value) {
            if (value.isNotEmpty) {
              final bytesU8 = Uint8List.fromList(value);
              RawCaptureService.instance.recordNotification(hrCharUuidStr, bytesU8);
              BleDiagnosticService.instance.recordPacketReceived(charUuid: hrCharUuidStr, bytes: bytesU8);
              _onTelemetryDataReceived();
              final packet = HrDataPacket.fromBytes(value);
              if (!_hrStreamController.isClosed) {
                _hrStreamController.add(packet);
              }
            }
          });
          debugPrint('BleConnectionManager: [5/5] Sottoscritto canale 0x2A37 (Standard HR)');
        } catch (e) {
          debugPrint('BleConnectionManager: Errore sottoscrizione HR 0x2A37: $e');
        }
      }

      // SEQUENZA DI SBLOCCO SENSORI DORMISCENTI:
      await _executeHardwareUnlockSequence(device);
    } else {
      _fallbackModeActive = true;
      if (hrChar != null) {
        try {
          await hrChar.setNotifyValue(true);
          _hrNotificationSubscription?.cancel();
          final fallbackHrCharUuidStr = hrChar.uuid.toString();
          _hrNotificationSubscription = hrChar.onValueReceived.listen((value) {
            if (value.isNotEmpty) {
              final bytesU8 = Uint8List.fromList(value);
              RawCaptureService.instance.recordNotification(fallbackHrCharUuidStr, bytesU8);
              BleDiagnosticService.instance.recordPacketReceived(charUuid: fallbackHrCharUuidStr, bytes: bytesU8);
              _onTelemetryDataReceived();
              final packet = HrDataPacket.fromBytes(value);
              if (!_hrStreamController.isClosed) {
                _hrStreamController.add(packet);
              }
            }
          });
        } catch (_) {}
      }
      _updateState(BleState.connected, 'WHOOP Connesso (Fallback HR)');
      _updateState(BleState.streaming, 'WHOOP Connesso - Streaming HR');
    }
  }

  /// Esegue la sequenza di risveglio e sblocco hardware del sensore WHOOP
  Future<void> _executeHardwareUnlockSequence(BluetoothDevice device) async {
    try {
      _updateState(BleState.initializing, 'Inizializzazione hardware...');
      final isMaverick = device.platformName.toUpperCase().contains('5.0') ||
          device.platformName.toUpperCase().contains('WP5');

      debugPrint('BleConnectionManager: Avvio sequenza di sblocco hardware profondo (isMaverick=$isMaverick)...');

      // 1. GET_HELLO (Opcode 35 su 4.0, 145 su 5.0)
      _hapticPacketCounter = (_hapticPacketCounter + 1) & 0xFF;
      final helloFrame = HapticClockEncoder.buildGetHelloCommand(
        seq: _hapticPacketCounter,
        isMaverick: isMaverick,
      );
      await writeAlarmCommand(helloFrame);
      await Future.delayed(const Duration(milliseconds: 100));

      // 2. SET_CLOCK con l'orario UTC corrente del telefono (Opcode 10)
      _hapticPacketCounter = (_hapticPacketCounter + 1) & 0xFF;
      final nowEpochSec = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
      final clockFrame = HapticClockEncoder.buildSetClockCommand(
        epochSec: nowEpochSec,
        seq: _hapticPacketCounter,
      );
      await writeAlarmCommand(clockFrame);
      await Future.delayed(const Duration(milliseconds: 100));

      // 3. TOGGLE_GENERIC_HR_PROFILE: sblocca la trasmissione BLE Heart Rate standard 0x180D (Opcode 14)
      _hapticPacketCounter = (_hapticPacketCounter + 1) & 0xFF;
      final unlockHrFrame = HapticClockEncoder.buildToggleGenericHrProfileCommand(
        seq: _hapticPacketCounter,
        enable: true,
      );
      await writeAlarmCommand(unlockHrFrame);
      await Future.delayed(const Duration(milliseconds: 100));

      // 4. TOGGLE_REALTIME_HR: attiva lo streaming continuo di campioni 1 Hz (Opcode 3)
      _hapticPacketCounter = (_hapticPacketCounter + 1) & 0xFF;
      final startRtFrame = HapticClockEncoder.buildToggleRealtimeHrCommand(
        seq: _hapticPacketCounter,
        enable: true,
      );
      await writeAlarmCommand(startRtFrame);
      await Future.delayed(const Duration(milliseconds: 100));

      // 5. Store & Forward Handshake
      await sendStoreAndForwardSyncHandshake();

      debugPrint('BleConnectionManager: Sblocco hardware profondo completato con successo!');
      _updateState(BleState.connected, 'WHOOP Connesso');
      _updateState(BleState.streaming, 'WHOOP Connesso - Streaming attivo');
    } catch (e) {
      debugPrint('BleConnectionManager: Errore durante sequenza di sblocco hardware: $e');
      _updateState(BleState.failed, 'Errore durante sequenza di sblocco hardware: $e');
    }
  }

  /// Invia l'Handshake di Sincronizzazione Opcode 0x16 (Trigger Data Retrieval) a CMD_TO_STRAP
  Future<void> sendStoreAndForwardSyncHandshake() async {
    if (!isConnected) return;
    _updateState(BleState.syncingHistory, 'Sincronizzazione dati offline flash...');
    final handshakeFrame = Uint8List.fromList(StoreAndForwardHandler.buildOpcode22SendHistoricalData());
    await writeAlarmCommand(handshakeFrame);
    debugPrint('BleConnectionManager: Inviato Handshake Opcode 0x16 (Trigger Data Retrieval)');
  }

  /// BLE-01: Calcolo Backoff Esponenziale con Jitter (2s -> 4s -> 8s -> 16s -> 32s -> max 60s)
  @visibleForTesting
  static Duration calculateBackoffDelay(int attempt, {bool withJitter = true, math.Random? random}) {
    if (attempt <= 0) attempt = 1;
    int baseSec = 2 * (1 << (attempt - 1));
    if (baseSec > 60 || baseSec < 2) {
      baseSec = 60;
    }
    if (!withJitter) {
      return Duration(seconds: baseSec);
    }
    final rand = random ?? math.Random();
    final jitterMs = rand.nextInt(500); // Jitter tra 0 e 500 ms
    return Duration(milliseconds: (baseSec * 1000) + jitterMs);
  }

  /// BLE-01: Avvio ciclo di riconnessione automatica con backoff
  void _handleAutoReconnection() {
    if (_state == BleState.reconnecting) return;
    _updateState(BleState.reconnecting, 'Connessione persa. Riconnessione automatica in corso...');
    _scheduleNextReconnectAttempt();
  }

  void _scheduleNextReconnectAttempt() {
    _reconnectTimer?.cancel();
    final nextAttempt = _backoffAttempt + 1;
    final delay = calculateBackoffDelay(nextAttempt, withJitter: true, random: _random);
    debugPrint('BleConnectionManager: Prossimo tentativo di riconnessione (#$nextAttempt) programmato tra ${delay.inMilliseconds}ms');

    _reconnectTimer = Timer(delay, () async {
      if (isConnected) return;
      _backoffAttempt++;
      _autoReconnectAttempts++;
      debugPrint('BleConnectionManager: Tentativo di riconnessione automatica #$_backoffAttempt...');

      // BLE-05: autoConnect: true durante riconnessione in background
      bool reconnected = await connectSavedDevice(isAutoReconnect: true);
      if (reconnected) {
        return;
      }

      // Se il dispositivo salvato non risponde dopo 3 tentativi consecutivi, attiva scansione se non in corso
      if (_backoffAttempt % 3 == 0 && !isConnecting) {
        debugPrint('BleConnectionManager: Scansione attiva per ritrovare la strap WHOOP...');
        await startScanAndConnect();
      }

      // Rischedula il prossimo tentativo se ancora disconnesso e non in corso di connessione
      if (!isConnected && !isConnecting) {
        _scheduleNextReconnectAttempt();
      }
    });
  }

  /// BLE-01: Reset del contatore di backoff solo dopo una connessione stabile mantenuta per > 60s in streaming
  void _startStableStreamingTimer() {
    _stableStreamingTimer?.cancel();
    _stableStreamingTimer = Timer(const Duration(seconds: 60), () {
      if (_state == BleState.streaming) {
        debugPrint('BleConnectionManager: Connessione stabile per > 60s in streaming. Reset contatore backoff.');
        _backoffAttempt = 0;
        _autoReconnectAttempts = 0;
      }
    });
  }

  /// Data Watchdog: Avvia il timer di 15 secondi per il controllo ricezione frame in streaming
  void _startDataWatchdog() {
    _dataWatchdogTimer?.cancel();
    _dataWatchdogTimer = Timer(dataWatchdogTimeout, _onDataWatchdogFired);
  }

  /// Resetta il watchdog quando si riceve un pacchetto valido di telemetria
  void _onTelemetryDataReceived() {
    if (_state == BleState.streaming) {
      _dataWatchdogTimer?.cancel();
      _dataWatchdogTimer = Timer(dataWatchdogTimeout, _onDataWatchdogFired);
    }
  }

  /// Data Watchdog: Chiamato se nessun frame viene ricevuto per più di 15s in streaming
  Future<void> _onDataWatchdogFired() async {
    if (_state != BleState.streaming) return;
    debugPrint('BleConnectionManager: DATA WATCHDOG SCATTATO (>15s senza frame in streaming). Connessione zombie rilevata!');
    _recordDisconnection(-1, 'Data Watchdog: Connessione zombie (>15s senza dati)');
    _addDebugLog('[WATCHDOG] Connessione zombie rilevata: nessun dato da 15s in streaming');

    _dataWatchdogTimer?.cancel();
    _dataWatchdogTimer = null;
    _stableStreamingTimer?.cancel();
    _stableStreamingTimer = null;

    // Disconnessione pulita forzata
    _cancelAllSubscriptions();
    if (_connectedDevice != null) {
      final dev = _connectedDevice;
      _connectedDevice = null;
      try {
        await dev!.disconnect();
      } catch (_) {}
    }

    _updateState(BleState.disconnected, 'Connessione zombie terminata da watchdog');
    _handleAutoReconnection();
  }

  /// BLE-06: Registra un evento di disconnessione nella lista circolare (ultimi 20 eventi)
  void _recordDisconnection(int? code, String? description) {
    final duration = _sessionStartTime != null
        ? DateTime.now().difference(_sessionStartTime!)
        : Duration.zero;
    _sessionStartTime = null;

    final reason = interpretDisconnectCode(code, description);
    final event = DisconnectionEvent(
      timestamp: DateTime.now(),
      statusCode: code,
      reason: reason,
      sessionDuration: duration,
    );

    _disconnectionHistory.add(event);
    if (_disconnectionHistory.length > 20) {
      _disconnectionHistory.removeAt(0);
    }

    _addDebugLog('[DISCONNECT] Code: $code, Reason: $reason, Durata: ${duration.inSeconds}s');
    debugPrint('BleConnectionManager: Registrato evento disconnessione: $event');

    BleDiagnosticService.instance.recordDisconnection(code ?? 0, reason);
    StructuredLogger.instance.warn(
      LogTag.ble,
      'Disconnessione: codice $code, motivo "$reason", durata: ${duration.inSeconds}s',
    );
  }

  /// BLE-04: Accoda un comando da inviare a CMD_TO_STRAP in modo asincrono non bloccante
  void enqueueCommand(Uint8List payload) {
    _txQueue.add(payload);
    _processTxQueue();
  }

  Future<void> _processTxQueue() async {
    if (_isTxProcessing) return;
    _isTxProcessing = true;
    try {
      while (_txQueue.isNotEmpty) {
        if (!isConnected || _connectedDevice == null) {
          _txQueue.clear();
          break;
        }
        final payload = _txQueue.removeAt(0);
        await writeAlarmCommand(payload);
        if (_txQueue.isNotEmpty) {
          await Future.delayed(const Duration(milliseconds: 20));
        }
      }
    } catch (e) {
      debugPrint('BleConnectionManager: Errore svuotamento coda comandi TX: $e');
    } finally {
      _isTxProcessing = false;
    }
  }

  /// Public method per forzare il ripristino della connessione BLE
  Future<void> ensureConnected() async {
    if (isConnecting) return;
    if (_state == BleState.disconnected || _state == BleState.reconnecting || _state == BleState.failed) {
      final reconnected = await connectSavedDevice(isAutoReconnect: true);
      if (!reconnected && !isConnecting) {
        await startScanAndConnect();
      }
    }
  }

  final List<String> _debugLogs = [];
  List<String> get debugLogs => List.unmodifiable(_debugLogs);
  final StreamController<List<String>> _debugLogsController = StreamController<List<String>>.broadcast();
  Stream<List<String>> get debugLogsStream => _debugLogsController.stream;

  int _hapticPacketCounter = 0;

  void _addDebugLog(String logMsg) {
    _debugLogs.add(logMsg);
    if (_debugLogs.length > 50) {
      _debugLogs.removeAt(0);
    }
    if (!_debugLogsController.isClosed) {
      _debugLogsController.add(List.unmodifiable(_debugLogs));
    }
  }

  /// Invia un payload di comando allarme/vibrazione a CMD_TO_STRAP gestendo automaticamente write with/without response
  Future<bool> writeAlarmCommand(Uint8List payload) async {
    final hexString = payload.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join(' ');
    final timestamp = DateTime.now().toIso8601String().substring(11, 19);

    if (!isConnected || _connectedDevice == null) {
      _addDebugLog('[$timestamp] [TX ERROR] Dispositivo non connesso. Payload: $hexString');
      return false;
    }

    try {
      BluetoothCharacteristic? cmdToStrapChar = _cmdToStrapChar;

      if (cmdToStrapChar == null) {
        // Fallback: cerca nei servizi già scoperti in memoria senza chiamare discoverServices()
        final services = _connectedDevice!.servicesList;
        for (var s in services) {
          for (var c in s.characteristics) {
            final uuid = c.uuid.toString().toLowerCase();
            if (uuid.contains('61080002') ||
                uuid.contains('fd4b0002') ||
                uuid.contains('0010') ||
                c.properties.writeWithoutResponse ||
                c.properties.write) {
              cmdToStrapChar = c;
              _cmdToStrapChar = c;
              break;
            }
          }
          if (cmdToStrapChar != null) break;
        }
      }

      if (cmdToStrapChar != null) {
        try {
          bool useWithoutResponse = cmdToStrapChar.properties.writeWithoutResponse;
          try {
            await cmdToStrapChar.write(payload, withoutResponse: useWithoutResponse);
          } catch (writeErr) {
            // Se fallisce, tenta la modalità opposta (withResponse vs withoutResponse)
            await cmdToStrapChar.write(payload, withoutResponse: !useWithoutResponse);
          }
          _addDebugLog('[$timestamp] [TX SUCCESS] CMD_TO_STRAP (${cmdToStrapChar.uuid})\nHEX: $hexString');
          debugPrint('BleConnectionManager: Scritto frame su CMD_TO_STRAP (${cmdToStrapChar.uuid}) [HEX: $hexString]');
          final opcode = payload.length > 6 ? payload[6] : (payload.isNotEmpty ? payload[0] : 0);
          BleDiagnosticService.instance.recordWriteSent(
            opcode: opcode,
            bytes: payload,
            description: 'CMD_TO_STRAP (${cmdToStrapChar.uuid})',
          );
          StructuredLogger.instance.info(
            LogTag.haptic,
            'Scritto comando su CMD_TO_STRAP (opcode=0x${opcode.toRadixString(16)}, len=${payload.length})',
          );
          return true;
        } catch (e) {
          _addDebugLog('[$timestamp] [TX GATT ERROR] Errore di scrittura su ${cmdToStrapChar.uuid}: $e\nHEX: $hexString');
          debugPrint('BleConnectionManager: Errore scrittura GATT: $e');
          return false;
        }
      } else {
        _addDebugLog('[$timestamp] [TX ERROR] Caratteristica CMD_TO_STRAP (0x0010/0002) non trovata.');
        return false;
      }
    } catch (e) {
      _addDebugLog('[$timestamp] [TX EXCEPTION] Errore generale BLE: $e');
      debugPrint('BleConnectionManager: Errore durante invio comando allarme: $e');
      return false;
    }
  }

  /// Invia il pacchetto di prova vibrazione immediata con tutti i protocolli WHOOP
  Future<bool> sendTestVibrationPulseNow() async {
    _hapticPacketCounter = (_hapticPacketCounter + 1) & 0xFF;

    // 1. Invocazione haptic immediata su smartphone
    try {
      HapticFeedback.heavyImpact();
    } catch (_) {}

    // 2. Invio dei frame di comando haptic reali WHOOP
    if (isConnected && _connectedDevice != null) {
      // Opcode 68: RUN_ALARM (Trigger immediato buzzer allarme Harvard WHOOP 4.0)
      final runAlarm = HapticClockEncoder.buildRunAlarmCommand(seq: _hapticPacketCounter);
      await writeAlarmCommand(runAlarm);
      await Future.delayed(const Duration(milliseconds: 40));

      // Opcode 79: RUN_HAPTICS_PATTERN (Pattern haptic motor WHOOP 4.0)
      final runHaptics = HapticClockEncoder.buildRunHapticsPatternCommand(
        seq: (_hapticPacketCounter + 1) & 0xFF,
        patternId: 2,
        duration: 4,
      );
      await writeAlarmCommand(runHaptics);
      await Future.delayed(const Duration(milliseconds: 40));

      // Opcode 19: RUN_HAPTIC_PATTERN_MAVERICK (Buzzer WHOOP 5.0 / MG / Maverick)
      final runMaverick = HapticClockEncoder.buildRunHapticPatternMaverickCommand(
        seq: (_hapticPacketCounter + 2) & 0xFF,
        loops: 3,
      );
      await writeAlarmCommand(runMaverick);
      await Future.delayed(const Duration(milliseconds: 40));

      // Opcode 66: SET_ALARM_TIME (Frame 20-byte retrocompatibile)
      final payload20 = HapticClockEncoder.encodeTestVibrationPayload(
        pattern: 1,
        packetCounter: (_hapticPacketCounter + 3) & 0xFF,
      );
      await writeAlarmCommand(payload20);

      _hapticPacketCounter = (_hapticPacketCounter + 4) & 0xFF;
      return true;
    }
    return false;
  }

  /// Invia la sequenza di vibrazione haptic veritiera alla strap WHOOP BLE e allo smartphone
  Future<HapticResultStatus> sendHapticVibrationCommand({int pattern = 1}) async {
    bool phoneVibrated = false;
    // 1. Vibrazione fisica sul motore dello smartphone
    try {
      HapticFeedback.heavyImpact();
      await Future.delayed(const Duration(milliseconds: 80));
      HapticFeedback.vibrate();
      await Future.delayed(const Duration(milliseconds: 80));
      HapticFeedback.heavyImpact();
      phoneVibrated = true;
    } catch (_) {}

    if (!isConnected || _connectedDevice == null) {
      return phoneVibrated
          ? HapticResultStatus.phoneHapticOnly
          : HapticResultStatus.notConnected;
    }

    // 2. Invocazione multi-protocollo al cinturino WHOOP BLE
    try {
      _hapticPacketCounter = (_hapticPacketCounter + 1) & 0xFF;

      // Opcode 68 (RUN_ALARM immediato)
      final runAlarm = HapticClockEncoder.buildRunAlarmCommand(seq: _hapticPacketCounter);
      final okAlarm = await writeAlarmCommand(runAlarm);
      await Future.delayed(const Duration(milliseconds: 50));

      // Opcode 79 (RUN_HAPTICS_PATTERN WHOOP 4.0)
      final runHaptics = HapticClockEncoder.buildRunHapticsPatternCommand(
        seq: (_hapticPacketCounter + 1) & 0xFF,
        patternId: pattern > 0 ? pattern : 2,
      );
      final okHaptics = await writeAlarmCommand(runHaptics);
      await Future.delayed(const Duration(milliseconds: 50));

      // Opcode 19 (RUN_HAPTIC_PATTERN_MAVERICK per WHOOP 5.0)
      final runMaverick = HapticClockEncoder.buildRunHapticPatternMaverickCommand(
        seq: (_hapticPacketCounter + 2) & 0xFF,
        loops: 3,
      );
      final okMaverick = await writeAlarmCommand(runMaverick);
      await Future.delayed(const Duration(milliseconds: 50));

      // Direct haptic motor
      final payloadDirect = HapticClockEncoder.encodeHapticMotorDirect(pattern: pattern);
      final okDirect = await writeAlarmCommand(payloadDirect);

      _hapticPacketCounter = (_hapticPacketCounter + 4) & 0xFF;

      if (okAlarm || okHaptics || okMaverick || okDirect) {
        return HapticResultStatus.strapCommandSent;
      } else {
        return HapticResultStatus.strapFailed;
      }
    } catch (e) {
      debugPrint('Errore invio sequenza vibrazione BLE: $e');
      return HapticResultStatus.strapFailed;
    }
  }

  /// Invia il comando di cancellazione sveglia alla strap WHOOP
  Future<bool> sendCancelAlarmCommand() async {
    if (isConnected && _connectedDevice != null) {
      _hapticPacketCounter = (_hapticPacketCounter + 1) & 0xFF;
      final disableCmd = HapticClockEncoder.buildDisableAlarmCommand(seq: _hapticPacketCounter);
      await writeAlarmCommand(disableCmd);
      await Future.delayed(const Duration(milliseconds: 40));

      final payload = HapticClockEncoder.encodeCancelAlarm();
      return await writeAlarmCommand(payload);
    }
    return false;
  }

  /// Disconnessione manuale e pulizia risorse
  /// BLE-01: Non esegue MAI disconnect() se lo stato è BleState.connecting o se isConnecting
  Future<void> disconnect({bool cancelReconnectTimer = true, bool force = false}) async {
    if (!force && (_state == BleState.connecting || _isConnecting)) {
      debugPrint('BleConnectionManager: disconnect() ignorato durante lo stato connecting (BLE-01)');
      return;
    }

    _stateTransitionTimer?.cancel();
    _stateTransitionTimer = null;
    _dataWatchdogTimer?.cancel();
    _dataWatchdogTimer = null;
    _stableStreamingTimer?.cancel();
    _stableStreamingTimer = null;

    if (cancelReconnectTimer) {
      _reconnectTimer?.cancel();
      _reconnectTimer = null;
    }
    _proprietaryTimeoutTimer?.cancel();
    _scanSubscription?.cancel();
    _connectionSubscription?.cancel();
    _cancelAllSubscriptions();

    if (_connectedDevice != null) {
      final dev = _connectedDevice;
      _connectedDevice = null;
      try {
        await dev!.disconnect();
      } catch (_) {}
    }

    _recordDisconnection(0, 'Disconnessione richiesta dall\'utente');
    _cmdToStrapChar = null;
    _batteryLevelPct = null;
    _isProprietaryChannelActive = false;
    _fallbackModeActive = false;
    _updateState(BleState.disconnected, 'Disconnesso.');
  }

  void dispose() {
    disconnect(force: true);
    if (!_hrStreamController.isClosed) _hrStreamController.close();
    if (!_96ByteStreamController.isClosed) _96ByteStreamController.close();
    if (!_stateStreamController.isClosed) _stateStreamController.close();
    if (!_batteryStreamController.isClosed) _batteryStreamController.close();
    if (!_ackNotificationStreamController.isClosed) _ackNotificationStreamController.close();
    if (!_debugLogsController.isClosed) _debugLogsController.close();
  }

  // --- Testing Hooks ---
  @visibleForTesting
  void setIsConnectingForTesting(bool value) {
    _isConnecting = value;
  }

  @visibleForTesting
  void setBackoffAttemptForTesting(int value) {
    _backoffAttempt = value;
  }

  @visibleForTesting
  void updateStateForTesting(BleState state, [String? message]) {
    _updateState(state, message);
  }

  @visibleForTesting
  void recordDisconnectionForTesting(int? code, String? description) {
    _recordDisconnection(code, description);
  }

  @visibleForTesting
  Future<void> triggerWatchdogForTesting() => _onDataWatchdogFired();

  @visibleForTesting
  void onTelemetryDataReceivedForTesting() => _onTelemetryDataReceived();

  @visibleForTesting
  int get txQueueLength => _txQueue.length;

  @visibleForTesting
  bool get bindInProgress => _bindInProgress;
}
