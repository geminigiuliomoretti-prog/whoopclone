import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:whoop_clone/data/ble/ble_connection_manager.dart';
import 'package:whoop_clone/data/ble/noop_protocol_decoder.dart';
import 'package:whoop_clone/data/database/database_helper.dart';
import 'package:whoop_clone/data/repositories/sqlite_whoop_repository.dart';
import 'package:whoop_clone/data/services/overnight_sleep_engine.dart';
import 'package:whoop_clone/data/services/telemetry_ingestion_service.dart';
import 'package:whoop_clone/viewmodels/whoop_viewmodel.dart';

Uint8List buildSampled96BytePacket({
  required int seqNum,
  required DateTime timestamp,
  required int hrBpm,
  required double rmssdMs,
  required double accelX,
  required double accelY,
  required double accelZ,
  int rawTemp = 4480, // 35.0 °C
  double spo2Ratio = 0.48, // 98.0%
  double respRate = 14.5,
}) {
  final bytes = Uint8List(96);
  bytes[0] = 0xAA; // 96-byte packet sync byte
  bytes[1] = 0x00;
  final bd = ByteData.sublistView(bytes);

  bd.setUint16(2, seqNum & 0xFFFF, Endian.little);
  bd.setUint32(4, timestamp.toUtc().millisecondsSinceEpoch ~/ 1000, Endian.little);
  bytes[8] = hrBpm & 0xFF;
  bd.setUint16(9, (rmssdMs * 10).toInt(), Endian.little);
  bd.setInt16(11, (accelX * 1000).toInt(), Endian.little);
  bd.setInt16(13, (accelY * 1000).toInt(), Endian.little);
  bd.setInt16(15, (accelZ * 1000).toInt(), Endian.little);
  bd.setFloat32(20, respRate, Endian.little);
  bd.setUint16(28, rawTemp, Endian.little);
  bd.setFloat32(32, spo2Ratio, Endian.little);

  return bytes;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  DatabaseHelper.isTestMode = true;

  late DatabaseHelper dbHelper;
  late SqliteWhoopRepository repository;
  late TelemetryIngestionService ingestionService;
  late OvernightSleepEngine sleepEngine;
  late BleConnectionManager bleManager;
  late WhoopViewModel viewModel;

  setUp(() async {
    dbHelper = DatabaseHelper();
    await dbHelper.clearAllTables();
    repository = SqliteWhoopRepository(dbHelper: dbHelper);
    ingestionService = TelemetryIngestionService(dbHelper: dbHelper);
    sleepEngine = OvernightSleepEngine();
    bleManager = BleConnectionManager();
    bleManager.resetStateForTest();
    viewModel = WhoopViewModel(
      repository: repository,
      bleManager: bleManager,
    );
  });

  tearDown(() async {
    ingestionService.dispose();
    bleManager.dispose();
    await dbHelper.clearAllTables();
  });

  group('END-TO-END PIPELINE FORENSIC INTEGRATION TEST (Phase 18)', () {
    test('Full E2E Lifecycle: Ingestion (120 packets with dups and corrupt) -> SQLite -> Sleep Engine -> Manual Sleep -> Truthful UI', () async {
      // ─────────────────────────────────────────────────────────────
      // STAGE 1: INGESTION PIPELINE (120 PACKETS)
      // 100 valid unique packets, 15 duplicates, 5 corrupt packets
      // ─────────────────────────────────────────────────────────────
      const String targetSleepDateIso = '2026-10-03';
      final sleepStart = DateTime(2026, 10, 2, 23, 0); // 23:00
      final sleepEnd = DateTime(2026, 10, 3, 7, 0);    // 07:00

      final List<Uint8List> validPackets = [];
      const totalValid = 100;
      const int stepSeconds = (8 * 3600) ~/ totalValid; // ~288 seconds per packet

      for (int i = 0; i < totalValid; i++) {
        final packetTime = sleepStart.add(Duration(seconds: i * stepSeconds));
        // Physiological curve: lower HR and higher HRV during middle of night (SWS)
        final isMiddleNight = i >= 30 && i <= 70;
        final hr = isMiddleNight ? 48 + (i % 5) : 58 + (i % 6);
        final rmssd = isMiddleNight ? 75.0 + (i % 10) : 48.0 + (i % 8);
        final accelZ = isMiddleNight ? 0.995 : 0.950;

        final pkt = buildSampled96BytePacket(
          seqNum: i + 1,
          timestamp: packetTime,
          hrBpm: hr,
          rmssdMs: rmssd,
          accelX: 0.01,
          accelY: -0.01,
          accelZ: accelZ,
          rawTemp: 4480,
          spo2Ratio: 0.48,
        );
        validPackets.add(pkt);
      }

      // Generate 15 duplicates (re-sending packets from index 10 to 24)
      final List<Uint8List> duplicatePackets = validPackets.sublist(10, 25);

      // Generate 5 corrupted frames (CRC8 corrupted)
      final List<Uint8List> corruptPackets = [];
      for (int i = 0; i < 5; i++) {
        final framed = HapticClockEncoder.buildFramedCommand(cmd: 0x44, seq: 200 + i);
        final corrupt = Uint8List.fromList(framed);
        corrupt[3] ^= 0xFF; // Invert CRC8
        corruptPackets.add(corrupt);
      }

      // Ingest live streaming first (first 50 packets)
      for (int i = 0; i < 50; i++) {
        final res = await ingestionService.ingestRawPacket(
          validPackets[i],
          source: 'REAL_STREAM',
          deviceId: 'WHOOP_E2E_DEVICE',
        );
        expect(res.accepted, isTrue);
      }

      // Ingest store-and-forward batch (remaining 50 valid + 15 duplicates + 5 corrupt = 70 packets)
      final List<List<int>> sfBatch = [
        ...validPackets.sublist(50),
        ...duplicatePackets,
        ...corruptPackets,
      ];

      final batchRes = await ingestionService.ingestBatch(
        sfBatch,
        source: 'STORE_FORWARD',
        deviceId: 'WHOOP_E2E_DEVICE',
      );

      // Verify Ingestion Diagnostic Counters
      expect(ingestionService.packetsReceived, equals(120));
      expect(ingestionService.packetsSaved, equals(100));
      expect(ingestionService.packetsDuplicate, equals(15));
      expect(ingestionService.packetsInvalid, equals(5));

      expect(batchRes.saved, equals(50));
      expect(batchRes.duplicates, equals(15));
      expect(batchRes.invalid, equals(5));

      // ─────────────────────────────────────────────────────────────
      // STAGE 2: DATABASE PERSISTENCE FORENSICS (Schema v15)
      // ─────────────────────────────────────────────────────────────
      final db = await dbHelper.database;
      final savedRows = await db.query(
        DatabaseHelper.tableTelemetriaGrezza,
        orderBy: 'timestamp_utc_ms ASC',
      );

      expect(savedRows.length, equals(100));
      for (final row in savedRows) {
        expect(row['is_valid'], equals(1));
        expect(row['crc_valid'], equals(1));
        expect(row['duplicate'], equals(0));
        expect(row['accel_enmo'], isNotNull);
        // Invariant: accel_enmo must NOT be fabricated default 0.002
        expect(row['accel_enmo'], isNot(equals(0.002)));
      }

      // Verify stream sources: 50 REAL_STREAM, 50 STORE_FORWARD
      final realStreamCount = savedRows.where((r) => r['source'] == 'REAL_STREAM').length;
      final storeForwardCount = savedRows.where((r) => r['source'] == 'STORE_FORWARD').length;
      expect(realStreamCount, equals(50));
      expect(storeForwardCount, equals(50));

      // ─────────────────────────────────────────────────────────────
      // STAGE 3: PHYSIOLOGICAL SLEEP & RECOVERY ENGINE
      // ─────────────────────────────────────────────────────────────
      final sleepResult = await sleepEngine.processNightlyTelemetry(
        rawTelemetryRecords: savedRows,
        userBaseline30d: {
          'rhr_mean': 54.0,
          'rmssd_mean': 65.0,
          'baseline_temp_celsius': 35.0,
          'sleep_need_min': 480.0,
        },
        windowStart: sleepStart,
        windowEnd: sleepEnd,
        targetDateIso: targetSleepDateIso,
      );

      expect(sleepResult['manual_no_ble'], isFalse);
      expect(sleepResult['total_sleep_min'], equals(50.0)); // Exactly 100 epochs of 30s = 50 min of real data
      expect(sleepResult['missing_min'], greaterThan(400.0)); // Unobserved gaps truthfully identified as missing
      expect(sleepResult['sws_min'], greaterThan(0));
      expect(sleepResult['recovery_score'], isNotNull);
      expect(sleepResult['rhr_notte'], isNotNull);
      expect(sleepResult['hrv_notte'], isNotNull);

      // Verify DB persistence of overnight results
      final sonnoRow = await dbHelper.getSonnoByDate(targetSleepDateIso);
      expect(sonnoRow, isNotNull);
      expect(sonnoRow!['provenance'], equals('REAL'));
      expect(sonnoRow['sonno_profondo_min'], greaterThan(0));

      final cicloRow = await dbHelper.getCicloByDate(targetSleepDateIso);
      expect(cicloRow, isNotNull);
      expect(cicloRow!['provenance'], equals('REAL'));
      expect(cicloRow['recovery_score'], isNotNull);

      // ─────────────────────────────────────────────────────────────
      // STAGE 4: MANUAL SLEEP ENTRY ON SEPARATE DATE (ZERO FAKE DATA)
      // ─────────────────────────────────────────────────────────────
      const manualDateIso = '2026-10-01';
      final manualStart = DateTime(2026, 9, 30, 23, 30);
      final manualEnd = DateTime(2026, 10, 1, 7, 0);

      await viewModel.processAndAddManualSleep(
        startTime: manualStart,
        endTime: manualEnd,
        dateIso: manualDateIso,
      );

      final manualSonno = await dbHelper.getSonnoByDate(manualDateIso);
      expect(manualSonno, isNotNull);
      expect(manualSonno!['provenance'], equals('USER_ENTERED'));
      expect(manualSonno['sonno_profondo_min'], equals(0));
      expect(manualSonno['sonno_rem_min'], equals(0));
      expect(manualSonno['durata_tot_min'], equals(450)); // 7h30m = 450 min
      expect(manualSonno['efficienza_pct'], isNull);

      final manualCiclo = await dbHelper.getCicloByDate(manualDateIso);
      expect(manualCiclo, isNotNull);
      expect(manualCiclo!['provenance'], equals('USER_ENTERED'));
      expect(manualCiclo['recovery_score'], isNull);
      expect(manualCiclo['hrv_notte'], isNull);
      expect(manualCiclo['rhr_notte'], isNull);

      // ─────────────────────────────────────────────────────────────
      // STAGE 5: TRUTHFUL VIEWMODEL METRICS & HAPTICS STATUS
      // ─────────────────────────────────────────────────────────────
      // 1. Load real data date
      viewModel.setSelectedDate(DateTime.parse(targetSleepDateIso));
      await viewModel.loadData();
      expect(viewModel.recoveryScore, isNotNull);
      expect(viewModel.sleepPerformance, isNotNull);

      // 2. Load manual date
      viewModel.setSelectedDate(DateTime.parse(manualDateIso));
      await viewModel.loadData();
      expect(viewModel.recoveryScore, isNull, reason: 'Recovery score MUST be null for manual sleep without BLE vitals');
      expect(viewModel.ultimoSonno, isNotNull);
      expect(viewModel.ultimoSonno!.durataTotMin, equals(450));
      expect(viewModel.ultimoSonno!.sonnoLeggeroMin, equals(0.0), reason: 'Manual sleep must NEVER dump 100% of duration into light sleep');

      // 3. Test Truthful Haptic Command
      final hapticStatus = await bleManager.sendHapticVibrationCommand(pattern: 2);
      expect(
        hapticStatus,
        anyOf(equals(HapticResultStatus.phoneHapticOnly), equals(HapticResultStatus.notConnected)),
        reason: 'When BLE is disconnected, sendHapticVibrationCommand must NEVER return strapCommandSent',
      );
      expect(hapticStatus.isStrapSuccess, isFalse);
    });
  });
}
