import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:whoop_clone/data/ble/ble_connection_manager.dart';
import 'package:whoop_clone/data/ble/noop_protocol_decoder.dart';
import 'package:whoop_clone/data/ble/replay_ble_source.dart';
import 'package:whoop_clone/data/database/database_helper.dart';
import 'package:whoop_clone/data/services/telemetry_ingestion_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  DatabaseHelper.isTestMode = true;

  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('replay_ble_test_');
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('ReplayBleSource Unit Tests', () {
    test('1. loadLines() e loadFile() analizzano correttamente i pacchetti NDJSON', () async {
      final replay = ReplayBleSource();

      final lines = [
        jsonEncode({
          'charUuid': '61080005-8d6d-82b8-614a-1c8cb0f8dcc6',
          'timestampUtcMs': 1728114000000,
          'byteLength': 4,
          'hexPayload': 'aa100057',
        }),
        jsonEncode({
          'charUuid': '2a37',
          'timestampUtcMs': 1728114001000,
          'byteLength': 2,
          'hexPayload': '164b',
        }),
      ];

      replay.loadLines(lines);
      expect(replay.totalPackets, equals(2));
      expect(replay.packets[0].charUuid, equals('61080005-8d6d-82b8-614a-1c8cb0f8dcc6'));
      expect(replay.packets[0].rawBytes, equals(Uint8List.fromList([0xAA, 0x10, 0x00, 0x57])));
      expect(replay.packets[1].rawBytes, equals(Uint8List.fromList([0x16, 75])));

      // Test caricamento da file
      final file = File('${tempDir.path}/test_capture.ndjson');
      await file.writeAsString(lines.join('\n'));

      final replayFromFile = ReplayBleSource();
      await replayFromFile.loadFile(file);
      expect(replayFromFile.totalPackets, equals(2));
    });

    test('2. start() emula il ciclo di vita della connessione BLE (connecting -> connected -> streaming -> disconnected)', () async {
      final replay = ReplayBleSource(speedMultiplier: 0); // Istantaneo per test

      final lines = [
        jsonEncode({
          'charUuid': '2a37',
          'timestampUtcMs': 1728114000000,
          'byteLength': 2,
          'hexPayload': '164b',
        }),
      ];
      replay.loadLines(lines);

      final List<BleState> recordedStates = [];
      replay.stateStream.listen(recordedStates.add);

      expect(replay.state, equals(BleState.disconnected));

      await replay.start();

      expect(recordedStates, containsAllInOrder([
        BleState.connecting,
        BleState.connected,
        BleState.streaming,
        BleState.disconnected,
      ]));
      expect(replay.state, equals(BleState.disconnected));
      expect(replay.isReplaying, isFalse);
    });

    test('3. Riproduzione istantanea emette tutti i pacchetti in ordine attraverso rawByteStream e packetStream', () async {
      final replay = ReplayBleSource(speedMultiplier: 0);

      final packets = [
        ReplayPacket(
          charUuid: '0005',
          timestampUtcMs: 1000,
          byteLength: 3,
          hexPayload: 'aa0102',
          rawBytes: Uint8List.fromList([0xAA, 0x01, 0x02]),
        ),
        ReplayPacket(
          charUuid: '0005',
          timestampUtcMs: 2000,
          byteLength: 3,
          hexPayload: 'aa0304',
          rawBytes: Uint8List.fromList([0xAA, 0x03, 0x04]),
        ),
        ReplayPacket(
          charUuid: '0005',
          timestampUtcMs: 3000,
          byteLength: 3,
          hexPayload: 'aa0506',
          rawBytes: Uint8List.fromList([0xAA, 0x05, 0x06]),
        ),
      ];
      replay.loadPackets(packets);

      final List<Uint8List> receivedBytes = [];
      final List<double> progressUpdates = [];

      replay.rawByteStream.listen(receivedBytes.add);
      replay.progressStream.listen(progressUpdates.add);

      await replay.start();

      expect(receivedBytes.length, equals(3));
      expect(receivedBytes[0], equals(Uint8List.fromList([0xAA, 0x01, 0x02])));
      expect(receivedBytes[1], equals(Uint8List.fromList([0xAA, 0x03, 0x04])));
      expect(receivedBytes[2], equals(Uint8List.fromList([0xAA, 0x05, 0x06])));

      expect(progressUpdates.isNotEmpty, isTrue);
      expect(progressUpdates.last, equals(1.0));
    });

    test('4. Configurazione e variazione velocità di riproduzione (speedMultiplier)', () {
      final replay = ReplayBleSource(speedMultiplier: 1.0);
      expect(replay.speedMultiplier, equals(1.0));

      replay.setSpeed(5.0);
      expect(replay.speedMultiplier, equals(5.0));

      replay.setSpeed(20.0);
      expect(replay.speedMultiplier, equals(20.0));
    });

    test('5. pause(), resume() e stop() controllano il flusso della riproduzione', () async {
      final replay = ReplayBleSource(speedMultiplier: 1.0);

      // Genera 10 pacchetti con 100ms di intervallo
      final packets = List.generate(
        10,
        (i) => ReplayPacket(
          charUuid: '0005',
          timestampUtcMs: 1000 + (i * 100),
          byteLength: 2,
          hexPayload: 'aa${i.toRadixString(16).padLeft(2, '0')}',
          rawBytes: Uint8List.fromList([0xAA, i]),
        ),
      );
      replay.loadPackets(packets);

      // Avvia e metti in pausa quasi subito
      final startFuture = replay.start(speed: 10.0); // 10x veloce
      await Future.delayed(const Duration(milliseconds: 100));

      replay.pause();
      expect(replay.isPaused, isTrue);
      final indexAtPause = replay.currentIndex;

      await Future.delayed(const Duration(milliseconds: 150));
      // Durante la pausa l'indice non deve avanzare significativamente
      expect(replay.currentIndex, lessThanOrEqualTo(indexAtPause + 1));

      // Riprendi
      replay.resume();
      expect(replay.isPaused, isFalse);

      // Ferma anticipatamente
      await Future.delayed(const Duration(milliseconds: 50));
      await replay.stop();

      expect(replay.isReplaying, isFalse);
      expect(replay.state, equals(BleState.disconnected));

      await startFuture;
    });

    test('6. Integrazione con TelemetryIngestionService: i pacchetti replayed alimentano la pipeline SQLite', () async {
      final dbHelper = DatabaseHelper();
      await dbHelper.clearAllTables();
      final ingestionService = TelemetryIngestionService(dbHelper: dbHelper);

      final replay = ReplayBleSource(speedMultiplier: 0);

      // Costruisci pacchetto framed valido usando HapticClockEncoder
      final validCommandFrame = HapticClockEncoder.buildFramedCommand(
        cmd: 0x42,
        payload: [0x01, 0x02, 0x03, 0x04],
        seq: 15,
      );

      final hexPayload = validCommandFrame.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

      final lines = [
        jsonEncode({
          'charUuid': '61080005-8d6d-82b8-614a-1c8cb0f8dcc6',
          'timestampUtcMs': DateTime.now().toUtc().millisecondsSinceEpoch,
          'byteLength': validCommandFrame.length,
          'hexPayload': hexPayload,
        }),
      ];
      replay.loadLines(lines);

      // Pipe da replay.rawByteStream a ingestionService.ingestRawPacket
      final sub = replay.rawByteStream.listen((rawBytes) async {
        await ingestionService.ingestRawPacket(
          rawBytes,
          source: 'REPLAY_STREAM',
          deviceId: 'REPLAY_DEVICE_01',
        );
      });

      await replay.start();
      await Future.delayed(const Duration(milliseconds: 100));

      expect(ingestionService.packetsSaved, equals(1));
      expect(ingestionService.lastSequenceNumber, equals(15));

      await sub.cancel();
      ingestionService.dispose();
      await dbHelper.clearAllTables();
    });
  });
}
