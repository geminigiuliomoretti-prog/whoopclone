import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:whoop_clone/data/ble/noop_protocol_decoder.dart';
import 'package:whoop_clone/data/database/database_helper.dart';
import 'package:whoop_clone/data/services/telemetry_ingestion_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late DatabaseHelper dbHelper;
  late TelemetryIngestionService ingestionService;

  setUpAll(() {
    DatabaseHelper.isTestMode = true;
  });

  setUp(() async {
    dbHelper = DatabaseHelper();
    await dbHelper.clearAllTables();
    ingestionService = TelemetryIngestionService(dbHelper: dbHelper);
  });

  tearDown(() async {
    ingestionService.dispose();
    await dbHelper.clearAllTables();
  });

  group('TELEMETRY INGESTION SERVICE (Phase 2 & 5 Forensics)', () {
    test('1. GIVEN valid framed WHOOP command packet WHEN ingested THEN accepted, saved, and emitted on stream', () async {
      final frame = HapticClockEncoder.buildFramedCommand(
        cmd: 0x44, // RUN_ALARM
        seq: 1,
        payload: [0x01, 60], // bpm 60
      );

      IngestedTelemetry? receivedEvent;
      final sub = ingestionService.telemetryStream.listen((event) {
        receivedEvent = event;
      });

      final result = await ingestionService.ingestRawPacket(
        frame,
        source: 'REAL_STREAM',
        deviceId: 'TEST_STRAP_01',
      );

      await Future.delayed(const Duration(milliseconds: 50));
      await sub.cancel();

      expect(result.accepted, isTrue);
      expect(result.telemetry, isNotNull);
      expect(result.telemetry!.sequenceNumber, equals(1));
      expect(result.telemetry!.quality, equals('VALID'));
      expect(ingestionService.packetsReceived, equals(1));
      expect(ingestionService.packetsSaved, equals(1));
      expect(ingestionService.packetsInvalid, equals(0));
      expect(receivedEvent, isNotNull);

      // Verify SQLite row was persisted with Schema v15 columns
      final db = await dbHelper.database;
      final rows = await db.query(DatabaseHelper.tableTelemetriaGrezza);
      expect(rows.length, equals(1));
      expect(rows.first['device_id'], equals('TEST_STRAP_01'));
      expect(rows.first['crc_valid'], equals(1));
      expect(rows.first['is_valid'], equals(1));
      expect(rows.first['source'], equals('REAL_STREAM'));
    });

    test('2. GIVEN corrupted CRC-8 header WHEN ingested THEN dropped immediately and packetsInvalid incremented', () async {
      final frame = HapticClockEncoder.buildFramedCommand(
        cmd: 0x44,
        seq: 2,
        payload: [0x01],
      );
      final corruptFrame = Uint8List.fromList(frame);
      // Corrupt CRC-8 at byte 3
      corruptFrame[3] = corruptFrame[3] ^ 0xFF;

      final result = await ingestionService.ingestRawPacket(corruptFrame);

      expect(result.accepted, isFalse);
      expect(result.isValidCrc, isFalse);
      expect(result.dropReason, equals('HEADER_CRC8_MISMATCH'));
      expect(ingestionService.packetsReceived, equals(1));
      expect(ingestionService.packetsSaved, equals(0));
      expect(ingestionService.packetsInvalid, equals(1));
    });

    test('3. GIVEN corrupted CRC-32 payload tail WHEN ingested THEN dropped with PAYLOAD_CRC32_MISMATCH', () async {
      final frame = HapticClockEncoder.buildFramedCommand(
        cmd: 0x44,
        seq: 3,
        payload: [0x01],
      );
      final corruptFrame = Uint8List.fromList(frame);
      // Corrupt last CRC32 byte
      corruptFrame[corruptFrame.length - 1] = corruptFrame[corruptFrame.length - 1] ^ 0xFF;

      final result = await ingestionService.ingestRawPacket(corruptFrame);

      expect(result.accepted, isFalse);
      expect(result.isValidCrc, isFalse);
      expect(result.dropReason, equals('PAYLOAD_CRC32_MISMATCH'));
      expect(ingestionService.packetsInvalid, equals(1));
      expect(ingestionService.packetsSaved, equals(0));
    });

    test('4. GIVEN identical packet ingested twice WHEN ingested THEN sliding dedup window drops duplicate', () async {
      final frame = HapticClockEncoder.buildFramedCommand(
        cmd: 0x03,
        seq: 4,
        payload: [0x01],
      );

      final first = await ingestionService.ingestRawPacket(frame);
      expect(first.accepted, isTrue);
      expect(ingestionService.packetsSaved, equals(1));

      final second = await ingestionService.ingestRawPacket(frame);
      expect(second.accepted, isFalse);
      expect(second.isDuplicate, isTrue);
      expect(second.dropReason, equals('DUPLICATE_PACKET'));
      expect(ingestionService.packetsDuplicate, equals(1));
      expect(ingestionService.packetsSaved, equals(1)); // Still only 1 saved
    });

    test('5. GIVEN sequence gap (seq 10 followed by seq 15) WHEN ingested THEN detects 4 missing packets', () async {
      final frame1 = HapticClockEncoder.buildFramedCommand(cmd: 0x03, seq: 10);
      final frame2 = HapticClockEncoder.buildFramedCommand(cmd: 0x03, seq: 15);

      await ingestionService.ingestRawPacket(frame1);
      expect(ingestionService.lastSequenceNumber, equals(10));
      expect(ingestionService.packetsMissing, equals(0));

      final result = await ingestionService.ingestRawPacket(frame2);
      expect(result.accepted, isTrue, reason: result.dropReason);
      expect(result.missingGap, equals(4)); // 11, 12, 13, 14
      expect(ingestionService.packetsMissing, equals(4));
      expect(ingestionService.lastSequenceNumber, equals(15));
    });

    test('6. GIVEN physiological extreme outlier (HR 290 bpm) WHEN ingested THEN flags INVALID quality and increments packetsInvalid', () async {
      final bytes = Uint8List(96);
      bytes[0] = 0xAA; // framed
      bytes[1] = 92;   // body length lo (96 - 4)
      bytes[2] = 0;    // body length hi
      bytes[3] = WhoopCrc8.compute([bytes[1], bytes[2]]);
      bytes[8] = 252;  // HR 252 bpm (> 250 limit)

      // Populate CRC32
      final inner = bytes.sublist(4, 92);
      final crc32 = WhoopCrc32.compute(inner);
      bytes[92] = crc32 & 0xFF;
      bytes[93] = (crc32 >> 8) & 0xFF;
      bytes[94] = (crc32 >> 16) & 0xFF;
      bytes[95] = (crc32 >> 24) & 0xFF;

      final result = await ingestionService.ingestRawPacket(bytes);
      expect(result.accepted, isTrue, reason: result.dropReason); // Ingested for forensic audit
      expect(result.telemetry!.isValid, isFalse);
      expect(result.telemetry!.quality, equals('INVALID'));
      expect(ingestionService.packetsInvalid, equals(1));
    });

    test('7. GIVEN store-and-forward batch of 5 packets with 1 duplicate WHEN ingestBatch THEN correct counts', () async {
      final f1 = HapticClockEncoder.buildFramedCommand(cmd: 0x01, seq: 100);
      final f2 = HapticClockEncoder.buildFramedCommand(cmd: 0x01, seq: 101);
      final f3 = HapticClockEncoder.buildFramedCommand(cmd: 0x01, seq: 102);
      final f4 = HapticClockEncoder.buildFramedCommand(cmd: 0x01, seq: 104); // gap of 1 (103)
      final fDuplicate = f1;

      final batch = [f1, f2, f3, f4, fDuplicate];
      final batchResult = await ingestionService.ingestBatch(
        batch,
        source: 'STORE_FORWARD',
        deviceId: 'FLASH_STRAP_01',
      );

      expect(batchResult.invalid, equals(0));
      expect(batchResult.duplicates, equals(1));
      expect(batchResult.totalReceived, equals(5));
      expect(batchResult.saved, equals(4));
      expect(batchResult.gapsDetected, equals(1));
      expect(ingestionService.packetsSaved, equals(4));
    });
  });
}
