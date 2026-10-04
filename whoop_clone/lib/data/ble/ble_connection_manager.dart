import 'dart:async';
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

enum BleState {
  disconnected,
  requestingPermissions,
  scanning,
  connecting,
  bonding,
  connected,
  reconnecting,
  error,
}

/// BleConnectionManager gestisce la connessione BLE con il bracciale Whoop:
/// 1. Richiesta permessi Android (BLUETOOTH_SCAN, BLUETOOTH_CONNECT, ACCESS_FINE_LOCATION).
/// 2. Flusso Zero-Scan all'avvio dell'app via SharedPreferences e FlutterBluePlus.systemDevices.
/// 3. Binding reattivo CCCD per la caratteristica Heart Rate 0x2A37 (Service 0x180D).
/// 4. Prevenzione deadlock GATT e resetto degli stati incagliati.
/// 5. Invocazione multi-protocollo comandi allarme/vibrazione haptic (WriteWithResponse e WriteWithoutResponse).
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
  
  bool _isProprietaryChannelActive = false;
  bool _fallbackModeActive = false;
  BluetoothCharacteristic? _cmdToStrapChar;

  final StreamController<HrDataPacket> _hrStreamController =
      StreamController<HrDataPacket>.broadcast();
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
  StreamSubscription<List<int>>? _96ByteNotificationSubscription;
  StreamSubscription<List<int>>? _batteryNotificationSubscription;
  StreamSubscription<List<int>>? _ackNotificationSubscription;
  StreamSubscription<List<int>>? _eventsNotificationSubscription;
  Timer? _reconnectTimer;
  Timer? _proprietaryTimeoutTimer;

  // Getters
  BleState get state => _state;
  String? get statusMessage => _statusMessage;
  BluetoothDevice? get connectedDevice => _connectedDevice;
  int? get batteryLevelPct => _batteryLevelPct;
  bool get isProprietaryChannelActive => _isProprietaryChannelActive;
  bool get fallbackModeActive => _fallbackModeActive;

  Stream<HrDataPacket> get hrStream => _hrStreamController.stream;
  Stream<Whoop96BytePacket> get packet96ByteStream => _96ByteStreamController.stream;
  Stream<BleState> get stateStream => _stateStreamController.stream;
  Stream<int> get batteryStream => _batteryStreamController.stream;
  Stream<List<int>> get ackNotificationStream => _ackNotificationStreamController.stream;
  Stream<List<ScanResult>> get scanResultsStream => FlutterBluePlus.scanResults;

  void _updateState(BleState newState, [String? message]) {
    _state = newState;
    _statusMessage = message;
    if (!_stateStreamController.isClosed) {
      _stateStreamController.add(_state);
    }
  }

  void resetStateForTest() {
    _state = BleState.disconnected;
    _statusMessage = null;
    _connectedDevice = null;
    _cmdToStrapChar = null;
    if (!_stateStreamController.isClosed) {
      _stateStreamController.add(_state);
    }
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
  Future<void> startScanOnly({Duration timeout = const Duration(seconds: 15)}) async {
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
  Future<void> connectToSpecificDevice(BluetoothDevice device) async {
    try {
      await FlutterBluePlus.stopScan();
    } catch (_) {}

    await _connectToDevice(device);
  }

  /// Scansione automatica e prima connessione Whoop trovata
  Future<void> startScanAndConnect() async {
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
            await FlutterBluePlus.stopScan();
            await _connectToDevice(r.device);
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
    await disconnect();
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
  Future<bool> connectSavedDevice() async {
    final savedId = await getPairedDeviceId();
    if (savedId == null || savedId.isEmpty) {
      debugPrint('BleConnectionManager: Nessun ID salvato. Avvio scansione...');
      await startScanAndConnect();
      return false;
    }

    if (_state == BleState.connecting || _state == BleState.bonding) {
      debugPrint('BleConnectionManager: Resetto stato incagliato...');
      final preservedReconnectTimer = _reconnectTimer;
      await disconnect(cancelReconnectTimer: false);
      if (preservedReconnectTimer != null && preservedReconnectTimer.isActive) {
        _reconnectTimer = preservedReconnectTimer;
      }
    }

    debugPrint('BleConnectionManager: Flusso Zero-Scan per dispositivo salvato: $savedId');

    try {
      final device = BluetoothDevice.fromId(savedId);
      _connectedDevice = device;
      _updateState(BleState.connecting, 'Riconnessione al cinturino WHOOP...');

      List<BluetoothDevice> systemDevices = [];
      try {
        systemDevices = await FlutterBluePlus.systemDevices([]);
      } catch (_) {}

      bool isAlreadyConnectedToOs = systemDevices.any((d) => d.remoteId.str == savedId);

      _connectionSubscription?.cancel();
      _connectionSubscription = device.connectionState.listen((state) async {
        debugPrint('BleConnectionManager: ConnectionState reattivo -> $state');
        if (state == BluetoothConnectionState.connected) {
          _updateState(BleState.connected, 'WHOOP Connesso');
          try {
            await device.requestMtu(247);
          } catch (_) {}
          await _bindToDevice(device);
        } else if (state == BluetoothConnectionState.disconnected && _state == BleState.connected) {
          _updateState(BleState.disconnected, 'Connessione al cinturino WHOOP interrotta.');
          _handleAutoReconnection();
        }
      });

      if (isAlreadyConnectedToOs) {
        debugPrint('BleConnectionManager: Dispositivo già connesso all\'OS. Binding diretto...');
        try {
          await device.requestMtu(247);
        } catch (_) {}
        await _bindToDevice(device);
        return true;
      } else {
        try {
          await device.connect(autoConnect: true, timeout: const Duration(seconds: 6));
          try {
            await device.requestMtu(247);
          } catch (_) {}
          _updateState(BleState.connected, 'WHOOP Connesso');
          await _bindToDevice(device);
          return true;
        } catch (e) {
          debugPrint('BleConnectionManager: Connessione diretta non riuscita subito ($e). Avvio riconnessione automatica e scansione...');
          _updateState(BleState.reconnecting, 'Riconnessione in corso...');
          _handleAutoReconnection();
          return false;
        }
      }
    } catch (e) {
      debugPrint('BleConnectionManager: Errore Zero-Scan ($e)');
      _updateState(BleState.reconnecting, 'Riconnessione in corso...');
      _handleAutoReconnection();
      return false;
    }
  }

  /// 3. Connessione e Pairing con il Sensore
  Future<void> _connectToDevice(BluetoothDevice device) async {
    _updateState(BleState.connecting, 'Connessione a ${device.platformName}...');
    _connectedDevice = device;

    try {
      await _savePairedDeviceId(device.remoteId.str, device.platformName);

      _connectionSubscription?.cancel();
      _connectionSubscription = device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected && _state == BleState.connected) {
          _updateState(BleState.disconnected, 'Connessione al cinturino WHOOP interrotta.');
          _handleAutoReconnection();
        }
      });

      await device.connect(autoConnect: false, timeout: const Duration(seconds: 8));

      // Negoziazione MTU a 247 per consentire il passaggio diretto di frame a 96-Byte
      try {
        await device.requestMtu(247);
      } catch (_) {}

      _updateState(BleState.bonding, 'Creazione Bonding / Pairing BLE...');
      try {
        await device.createBond();
      } catch (_) {}

      _updateState(BleState.connected, 'WHOOP Connesso');
      await _bindToDevice(device);
    } catch (e) {
      _updateState(BleState.error, 'Errore di connessione BLE: $e');
      _handleAutoReconnection();
    }
  }

  /// Binding e sottoscrizione GATT (Zero-Scan Re-engagement & CCCD Binding)
  Future<void> _bindToDevice(BluetoothDevice device) async {
    if (_state != BleState.connected) {
      _updateState(BleState.connected, 'WHOOP Connesso');
    }

    // Avvia il Foreground Service Android nativo per mantenere la connessione attiva ad app chiusa
    _startNativeForegroundService();

    try {
      await _discoverAndSetupServices(device);
    } catch (e) {
      debugPrint('BleConnectionManager: Errore durante _bindToDevice: $e');
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

  /// 4. Discovery dei Servizi GATT e Sottoscrizione
  /// 4. Discovery dei Servizi GATT e Sottoscrizione con sequenza rigida WHOOP (0004 -> 0007 -> 0005 -> 0003 -> 0x2A37)
  Future<void> _discoverAndSetupServices(BluetoothDevice device) async {
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
          _eventsNotificationSubscription = eventsChar.onValueReceived.listen((eventBytes) {
            if (eventBytes.isNotEmpty) {
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
      if (dataChar != null) {
        try {
          await dataChar.setNotifyValue(true);
          _96ByteNotificationSubscription?.cancel();
          _96ByteNotificationSubscription = dataChar.onValueReceived.listen((bytes) async {
            if (bytes.length >= 96) {
              final p96 = Whoop96BytePacket.fromBytes(Uint8List.fromList(bytes));
              if (!_96ByteStreamController.isClosed) {
                _96ByteStreamController.add(p96);
              }
              _isProprietaryChannelActive = true;
              _fallbackModeActive = false;

              // Invia la risposta ACK Opcode 0x17 per far avanzare il puntatore Flash nello strap
              final ackFrame = Uint8List.fromList(
                StoreAndForwardHandler.buildOpcode23HistoricalDataResult(p96.seqNumber),
              );
              await writeAlarmCommand(ackFrame);
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
          _ackNotificationSubscription = cmdFromStrapChar.onValueReceived.listen((ackBytes) {
            if (ackBytes.isNotEmpty) {
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
            _batteryNotificationSubscription = batteryChar.onValueReceived.listen((val) {
              if (val.isNotEmpty) {
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
          _hrNotificationSubscription = hrChar.onValueReceived.listen((value) {
            if (value.isNotEmpty) {
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

      // SEQUENZA DI SBLOCCO SENSORI DORMISCENTI (Preludio di Inizializzazione Hardware Profonda):
      await _executeHardwareUnlockSequence(device);
    } else {
      _fallbackModeActive = true;
      if (hrChar != null) {
        try {
          await hrChar.setNotifyValue(true);
          _hrNotificationSubscription?.cancel();
          _hrNotificationSubscription = hrChar.onValueReceived.listen((value) {
            if (value.isNotEmpty) {
              final packet = HrDataPacket.fromBytes(value);
              if (!_hrStreamController.isClosed) {
                _hrStreamController.add(packet);
              }
            }
          });
        } catch (_) {}
      }
    }
  }

  /// Esegue la sequenza di risveglio e sblocco hardware del sensore WHOOP (Connessione a fondo)
  Future<void> _executeHardwareUnlockSequence(BluetoothDevice device) async {
    try {
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
    } catch (e) {
      debugPrint('BleConnectionManager: Errore durante sequenza di sblocco hardware: $e');
    }
  }

  /// Invia l'Handshake di Sincronizzazione Opcode 0x16 (Trigger Data Retrieval) a CMD_TO_STRAP
  Future<void> sendStoreAndForwardSyncHandshake() async {
    if (_state != BleState.connected) return;
    final handshakeFrame = Uint8List.fromList(StoreAndForwardHandler.buildOpcode22SendHistoricalData());
    await writeAlarmCommand(handshakeFrame);
    debugPrint('BleConnectionManager: Inviato Handshake Opcode 0x16 (Trigger Data Retrieval)');
  }

  /// 5. Gestione Riconnessione Automatica Ininterrotta in Background
  void _handleAutoReconnection() {
    if (_state == BleState.reconnecting) return;
    _autoReconnectAttempts = 0;
    _updateState(BleState.reconnecting, 'Connessione persa. Riconnessione automatica in corso...');

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      if (_state == BleState.connected) {
        timer.cancel();
        _autoReconnectAttempts = 0;
        return;
      }

      _autoReconnectAttempts++;
      debugPrint('BleConnectionManager: Tentativo di riconnessione automatica ininterrotta #$_autoReconnectAttempts...');

      // Prima prova il dispositivo salvato via Zero-Scan
      bool reconnected = await connectSavedDevice();
      if (reconnected) {
        timer.cancel();
        return;
      }

      // Se il dispositivo salvato non risponde subito, avvia la scansione attiva
      if (_autoReconnectAttempts % 3 == 0) {
        debugPrint('BleConnectionManager: Scansione attiva per ritrovare la strap WHOOP...');
        await startScanAndConnect();
      }
    });
  }

  /// Public method per forzare il ripristino della connessione BLE
  Future<void> ensureConnected() async {
    if (_state == BleState.disconnected || _state == BleState.reconnecting) {
      final reconnected = await connectSavedDevice();
      if (!reconnected) {
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

    if (_state != BleState.connected || _connectedDevice == null) {
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

  /// Invia il pacchetto di prova vibrazione immediata con tutti i protocolli WHOOP (Opcode 68 RUN_ALARM + Opcode 79 HAPTICS + Opcode 19 MAVERICK + Opcode 66 ALARM)
  Future<bool> sendTestVibrationPulseNow() async {
    _hapticPacketCounter = (_hapticPacketCounter + 1) & 0xFF;

    // 1. Invocazione haptic immediata su smartphone
    try {
      HapticFeedback.heavyImpact();
    } catch (_) {}

    // 2. Invio dei frame di comando haptic reali WHOOP
    if (_state == BleState.connected && _connectedDevice != null) {
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

  /// Invia la sequenza di vibrazione haptic immediata alla strap WHOOP BLE e al motore aptico dello smartphone
  Future<bool> sendHapticVibrationCommand({int pattern = 1}) async {
    // 1. Vibrazione fisica immediata sul motore dello smartphone
    try {
      HapticFeedback.heavyImpact();
      await Future.delayed(const Duration(milliseconds: 80));
      HapticFeedback.vibrate();
      await Future.delayed(const Duration(milliseconds: 80));
      HapticFeedback.heavyImpact();
    } catch (_) {}

    // 2. Invocazione multi-protocollo al cinturino WHOOP BLE (Opcode 68, Opcode 79, Opcode 19, Motor Direct)
    if (_state == BleState.connected && _connectedDevice != null) {
      try {
        _hapticPacketCounter = (_hapticPacketCounter + 1) & 0xFF;

        // Opcode 68 (RUN_ALARM immediato)
        final runAlarm = HapticClockEncoder.buildRunAlarmCommand(seq: _hapticPacketCounter);
        await writeAlarmCommand(runAlarm);
        await Future.delayed(const Duration(milliseconds: 50));

        // Opcode 79 (RUN_HAPTICS_PATTERN WHOOP 4.0)
        final runHaptics = HapticClockEncoder.buildRunHapticsPatternCommand(
          seq: (_hapticPacketCounter + 1) & 0xFF,
          patternId: pattern > 0 ? pattern : 2,
        );
        await writeAlarmCommand(runHaptics);
        await Future.delayed(const Duration(milliseconds: 50));

        // Opcode 19 (RUN_HAPTIC_PATTERN_MAVERICK per WHOOP 5.0)
        final runMaverick = HapticClockEncoder.buildRunHapticPatternMaverickCommand(
          seq: (_hapticPacketCounter + 2) & 0xFF,
          loops: 3,
        );
        await writeAlarmCommand(runMaverick);
        await Future.delayed(const Duration(milliseconds: 50));

        // Direct haptic motor
        final payloadDirect = HapticClockEncoder.encodeHapticMotorDirect(pattern: pattern);
        await writeAlarmCommand(payloadDirect);

        _hapticPacketCounter = (_hapticPacketCounter + 4) & 0xFF;
        return true;
      } catch (e) {
        debugPrint('Errore invio sequenza vibrazione BLE: $e');
      }
    }
    return true;
  }

  /// Invia il comando di cancellazione sveglia alla strap WHOOP
  Future<bool> sendCancelAlarmCommand() async {
    if (_state == BleState.connected && _connectedDevice != null) {
      _hapticPacketCounter = (_hapticPacketCounter + 1) & 0xFF;
      // Opcode 69: DISABLE_ALARM
      final disableCmd = HapticClockEncoder.buildDisableAlarmCommand(seq: _hapticPacketCounter);
      await writeAlarmCommand(disableCmd);
      await Future.delayed(const Duration(milliseconds: 40));

      final payload = HapticClockEncoder.encodeCancelAlarm();
      return await writeAlarmCommand(payload);
    }
    return false;
  }

  /// Disconnessione manuale e pulizia risorse
  Future<void> disconnect({bool cancelReconnectTimer = true}) async {
    if (cancelReconnectTimer) {
      _reconnectTimer?.cancel();
      _reconnectTimer = null;
    }
    _proprietaryTimeoutTimer?.cancel();
    _scanSubscription?.cancel();
    _connectionSubscription?.cancel();
    _hrNotificationSubscription?.cancel();
    _96ByteNotificationSubscription?.cancel();
    _batteryNotificationSubscription?.cancel();
    _ackNotificationSubscription?.cancel();
    _eventsNotificationSubscription?.cancel();

    if (_connectedDevice != null) {
      try {
        await _connectedDevice!.disconnect();
      } catch (_) {}
      _connectedDevice = null;
    }

    _cmdToStrapChar = null;
    _batteryLevelPct = null;
    _isProprietaryChannelActive = false;
    _fallbackModeActive = false;
    _updateState(BleState.disconnected, 'Disconnesso.');
  }

  void dispose() {
    disconnect();
    if (!_hrStreamController.isClosed) _hrStreamController.close();
    if (!_96ByteStreamController.isClosed) _96ByteStreamController.close();
    if (!_stateStreamController.isClosed) _stateStreamController.close();
    if (!_batteryStreamController.isClosed) _batteryStreamController.close();
    if (!_ackNotificationStreamController.isClosed) _ackNotificationStreamController.close();
    if (!_debugLogsController.isClosed) _debugLogsController.close();
  }
}
