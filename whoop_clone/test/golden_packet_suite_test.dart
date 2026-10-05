import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:whoop_clone/data/ble/noop_protocol_decoder.dart';
import 'package:whoop_clone/data/ble/whoop_96byte_packet.dart';
import 'package:whoop_clone/data/database/database_helper.dart';
import 'package:whoop_clone/data/services/telemetry_ingestion_service.dart';

Uint8List hexToBytes(String hex) {
  final clean = hex.replaceAll(' ', '').trim();
  final len = clean.length ~/ 2;
  final bytes = Uint8List(len);
  for (int i = 0; i < len; i++) {
    bytes[i] = int.parse(clean.substring(i * 2, i * 2 + 2), radix: 16);
  }
  return bytes;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  DatabaseHelper.isTestMode = true;

  late DatabaseHelper dbHelper;
  late TelemetryIngestionService ingestionService;

  setUp(() async {
    dbHelper = DatabaseHelper();
    await dbHelper.clearAllTables();
    ingestionService = TelemetryIngestionService(dbHelper: dbHelper);
  });

  tearDown(() async {
    ingestionService.dispose();
    await dbHelper.clearAllTables();
  });

  group('GOLDEN PACKET SUITE (Phase 8 Forensics)', () {
    test('1. Golden Framed 0xAA Command: Bit-perfect header, payload, CRC32, and SQLite persistence', () async {
      final jsonFile = File('test/fixtures/ble/framed_0xaa_command.json');
      expect(jsonFile.existsSync(), isTrue, reason: 'framed_0xaa_command.json missing');

      final data = jsonDecode(jsonFile.readAsStringSync()) as Map<String, dynamic>;
      final rawHex = data['raw_hex'] as String;
      final rawBytes = hexToBytes(rawHex);

      expect(rawBytes.length, equals(data['total_bytes']));

      // 1. Header Verification
      final header = data['header'] as Map<String, dynamic>;
      expect(rawBytes[0], equals(header['sync_byte']));
      final bodyLen = rawBytes[1] | (rawBytes[2] << 8);
      expect(bodyLen, equals(header['body_length']));
      expect(rawBytes[3], equals(header['crc8']));
      expect(WhoopCrc8.compute([rawBytes[1], rawBytes[2]]), equals(header['crc8']));

      // 2. Body Verification
      final body = data['body'] as Map<String, dynamic>;
      expect(rawBytes[4], equals(body['type']));
      expect(rawBytes[5], equals(body['sequence_number']));
      expect(rawBytes[6], equals(body['command_opcode']));
      expect(rawBytes[7].toRadixString(16).padLeft(2, '0'), equals(body['payload_hex']));

      // 3. Tail Verification
      final tail = data['tail'] as Map<String, dynamic>;
      final inner = rawBytes.sublist(4, 4 + bodyLen - 4);
      final computedCrc32 = WhoopCrc32.compute(inner);
      final actualCrc32 = ByteData.sublistView(rawBytes).getUint32(rawBytes.length - 4, Endian.little);
      expect(actualCrc32, equals(computedCrc32));
      expect(actualCrc32, equals(tail['crc32_uint32']));

      // 4. Ingestion Pipeline
      final result = await ingestionService.ingestRawPacket(
        rawBytes,
        source: 'REAL_STREAM',
        deviceId: 'GOLDEN_DEVICE_01',
      );
      expect(result.accepted, isTrue);
      expect(result.telemetry, isNotNull);
      expect(result.telemetry!.sequenceNumber, equals(body['sequence_number']));
      expect(ingestionService.packetsSaved, equals(1));
    });

    test('2. Golden 96-Byte Sensor Packet: Complete biometric extraction and range verification', () async {
      final jsonFile = File('test/fixtures/ble/whoop_96byte_sensor_packet.json');
      expect(jsonFile.existsSync(), isTrue, reason: 'whoop_96byte_sensor_packet.json missing');

      final data = jsonDecode(jsonFile.readAsStringSync()) as Map<String, dynamic>;
      final rawHex = data['raw_hex'] as String;
      final rawBytes = hexToBytes(rawHex);

      expect(rawBytes.length, equals(96));

      // 1. Direct Packet Parser Verification
      final packet = Whoop96BytePacket.fromBytes(rawBytes);
      final exp = data['expected'] as Map<String, dynamic>;

      expect(packet.sequenceNumber, equals(exp['sequence_number']));
      expect(packet.heartRateBpm, equals(exp['heart_rate_bpm']));
      expect(packet.hrvRmssdMs, closeTo(exp['hrv_rmssd_ms'] as num, 0.01));
      expect(packet.respiratoryRate, closeTo(exp['respiratory_rate'] as num, 0.01));
      expect(packet.skinTempRaw, equals(exp['skin_temp_raw']));
      expect(packet.spo2Ratio, closeTo(exp['spo2_ratio'] as num, 0.01));
      expect(packet.accelX, closeTo(exp['accel_x_g'] as num, 0.001));
      expect(packet.accelY, closeTo(exp['accel_y_g'] as num, 0.001));
      expect(packet.accelZ, closeTo(exp['accel_z_g'] as num, 0.001));

      // 2. Ingestion Pipeline & Persistence Verification
      final result = await ingestionService.ingestRawPacket(
        rawBytes,
        source: 'REAL_STREAM',
        deviceId: 'GOLDEN_STRAP_96',
      );
      expect(result.accepted, isTrue);
      expect(result.telemetry, isNotNull);
      expect(result.telemetry!.bpm, equals(58));
      expect(result.telemetry!.rmssdMs, closeTo(65.0, 0.01));
      expect(result.telemetry!.skinTempCelsius, closeTo(35.0, 0.1));
      expect(result.telemetry!.spo2Pct, closeTo(98.0, 0.1));

      // Verify DB Persistence
      final db = await dbHelper.database;
      final rows = await db.query(DatabaseHelper.tableTelemetriaGrezza);
      expect(rows.length, equals(1));
      final row = rows.first;
      expect(row['bpm'], equals(58));
      expect(row['rmssd_ms'], closeTo(65.0, 0.01));
      expect(row['skin_temp_raw'], equals(4480));
      expect(row['source'], equals('REAL_STREAM'));
      expect(row['packet_type'], equals('WHOOP_96BYTE'));
    });

    test('3. Golden Store-and-Forward Batch: Opcode 22 request & Opcode 23 ACK validation', () async {
      final jsonFile = File('test/fixtures/ble/store_and_forward_batch.json');
      expect(jsonFile.existsSync(), isTrue, reason: 'store_and_forward_batch.json missing');

      final data = jsonDecode(jsonFile.readAsStringSync()) as Map<String, dynamic>;

      // Verify Opcode 22
      final op22Data = data['opcode_22_send_historical'] as Map<String, dynamic>;
      final op22Bytes = hexToBytes(op22Data['raw_hex'] as String);
      expect(op22Bytes[0], equals(0xAA));
      expect(op22Bytes[6], equals(0x16)); // 22 SEND_HISTORICAL_DATA
      expect(op22Bytes[5], equals(op22Data['seq']));

      // Verify Opcode 23
      final op23Data = data['opcode_23_ack_result'] as Map<String, dynamic>;
      final op23Bytes = hexToBytes(op23Data['raw_hex'] as String);
      expect(op23Bytes[0], equals(0xAA));
      expect(op23Bytes[6], equals(0x17)); // 23 HISTORICAL_DATA_RESULT
      expect(op23Bytes[5], equals(op23Data['seq']));

      // Acked sequence extraction from payload
      final ackedSeq = op23Bytes[7] | (op23Bytes[8] << 8);
      expect(ackedSeq, equals(op23Data['acked_sequence']));

      // Batch ingestion simulation
      final batchResult = await ingestionService.ingestBatch(
        [op22Bytes, op23Bytes],
        source: 'STORE_FORWARD',
        deviceId: 'GOLDEN_FLASH_STRAP',
      );
      expect(batchResult.totalReceived, equals(2));
      expect(batchResult.saved, equals(2));
      expect(batchResult.invalid, equals(0));
    });

    test('4. Golden Corrupt CRC: Deterministic rejection of altered CRC-8 and CRC-32 frames', () async {
      final jsonFile = File('test/fixtures/ble/corrupt_crc_packet.json');
      expect(jsonFile.existsSync(), isTrue, reason: 'corrupt_crc_packet.json missing');

      final data = jsonDecode(jsonFile.readAsStringSync()) as Map<String, dynamic>;

      // 1. Corrupt CRC-8
      final c8Data = data['corrupt_crc8_header'] as Map<String, dynamic>;
      final c8Bytes = hexToBytes(c8Data['raw_hex'] as String);
      final r1 = await ingestionService.ingestRawPacket(c8Bytes);
      expect(r1.accepted, isFalse);
      expect(r1.isValidCrc, isFalse);
      expect(r1.dropReason, equals(c8Data['expected_rejection_reason']));

      // 2. Corrupt CRC-32
      final c32Data = data['corrupt_crc32_tail'] as Map<String, dynamic>;
      final c32Bytes = hexToBytes(c32Data['raw_hex'] as String);
      final r2 = await ingestionService.ingestRawPacket(c32Bytes);
      expect(r2.accepted, isFalse);
      expect(r2.isValidCrc, isFalse);
      expect(r2.dropReason, equals(c32Data['expected_rejection_reason']));

      // Zero fake data saved
      expect(ingestionService.packetsSaved, equals(0));
      expect(ingestionService.packetsInvalid, equals(2));

      final db = await dbHelper.database;
      final rows = await db.query(DatabaseHelper.tableTelemetriaGrezza);
      expect(rows, isEmpty, reason: 'Corrupt packets must NEVER be saved to telemetria_grezza');
    });
  });
}
