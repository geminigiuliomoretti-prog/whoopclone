import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:whoop_clone/data/ble/noop_protocol_decoder.dart';
import 'package:whoop_clone/data/database/database_helper.dart';
import 'package:whoop_clone/data/services/overnight_sleep_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  DatabaseHelper.isTestMode = true;

  group('WHOOP 5.0 Overnight Telemetry & Sleep Staging Engine Tests', () {
    late DatabaseHelper dbHelper;
    late OvernightSleepEngine sleepEngine;

    setUp(() async {
      dbHelper = DatabaseHelper();
      await dbHelper.clearAllTables();
      sleepEngine = OvernightSleepEngine(dbHelper: dbHelper);
    });

    test('1. Test CRC-32 Frame BLE: Inviluppo 0xAA 0x01 con CRC-16 e CRC-32 Custom (0xF43F44AC)', () {
      final innerPayload = [0x00, 0x10, 0x22, 0x44, 0x55, 0x1A, 0x01, 0x02, 0x03, 0x04];
      final declLen = innerPayload.length;
      final computedCrc32 = WhoopCrc32.compute(innerPayload);

      final List<int> rawFrame = [
        0xAA, // Start Marker
        0x01, // Prefix Marker
        declLen & 0xFF,
        (declLen >> 8) & 0xFF,
        ...innerPayload,
        computedCrc32 & 0xFF,
        (computedCrc32 >> 8) & 0xFF,
        (computedCrc32 >> 16) & 0xFF,
        (computedCrc32 >> 24) & 0xFF,
      ];

      final result = validateAndParseBleFrame(rawFrame);

      expect(result, isNotNull);
      expect(result!.isValid, isTrue);
      expect(result.crc16Passed, isTrue);
      expect(result.crc32Passed, isTrue);
      expect(result.declLen, equals(declLen));
      expect(result.versionType, equals(0x1A));
    });

    test('2. Test Store-and-Forward Opcodes (22/23): Reconstitution et Generazione Pacchetti', () {
      final opcode22 = StoreAndForwardHandler.buildOpcode22SendHistoricalData();
      expect(opcode22[0], equals(0xAA));
      expect(opcode22[4], equals(0x01)); // Type 0x01
      expect(opcode22[6], equals(0x16)); // SEND_HISTORICAL_DATA (Cmd 0x16)

      final opcode23 = StoreAndForwardHandler.buildOpcode23HistoricalDataResult(42);
      expect(opcode23[0], equals(0xAA));
      expect(opcode23[4], equals(0x01)); // Type 0x01
      expect(opcode23[6], equals(0x17)); // HISTORICAL_DATA_RESULT (Cmd 0x17)
      expect(opcode23[7], equals(42)); // Seq ACK in payload
    });

    test('3. Test Estrazione HRV in SWS (Brevetto US9750415B2): rMSSD estratto esattamente dall\'ultimo ciclo SWS', () async {
      // Simula una notte di 8 ore (960 epoche da 30 secondi) con 3 cicli SWS
      final List<Map<String, dynamic>> records = [];

      for (int i = 0; i < 960; i++) {
        double motion = 0.002;
        double hr = 55.0;
        double rmssd = 60.0;
        double respPower = 0.4; // Light sleep standard resp power (<0.6)
        List<double> pp = [0.95, 0.96, 0.94, 0.95, 0.96]; // ~63 BPM, ~20ms diff

        // Ciclo SWS 1 (epoche 100..150): rMSSD = 50ms
        if (i >= 100 && i < 150) {
          hr = 50.0;
          rmssd = 50.0;
          respPower = 0.8;
          pp = [1.20, 1.25, 1.18, 1.22, 1.20]; // rMSSD ~50ms
        }
        // Ciclo SWS 2 (epoche 400..450): rMSSD = 65ms
        else if (i >= 400 && i < 450) {
          hr = 48.0;
          rmssd = 65.0;
          respPower = 0.85;
          pp = [1.25, 1.32, 1.23, 1.30, 1.25]; // rMSSD ~65ms
        }
        // Ciclo SWS 3 (Ultimo ciclo SWS prima del risveglio, epoche 750..800): rMSSD target = 88ms
        else if (i >= 750 && i < 800) {
          hr = 46.0;
          rmssd = 88.0;
          respPower = 0.90;
          pp = [1.30, 1.39, 1.28, 1.37, 1.30]; // rMSSD target ~88ms
        }

        records.add({
          'motion_var': motion,
          'hr': hr,
          'rmssd': rmssd,
          'resp_power': respPower,
          'pp_intervals': pp,
        });
      }

      final userBaseline = {
        'rhr_mean': 55.0,
        'rmssd_mean': 65.0,
        'baseline_temp_celsius': 36.5,
      };

      final result = await sleepEngine.processNightlyTelemetry(
        rawTelemetryRecords: records,
        userBaseline30d: userBaseline,
      );

      final double extractedHrv = result['hrv_rmssd_ms'];
      final double recoveryScore = result['recovery_score'];

      expect(extractedHrv, closeTo(88.0, 5.0)); // Estratto dall'ultimo ciclo SWS
      expect(recoveryScore, greaterThan(60.0));
      expect(result['hypnogram'], hasLength(960));

      // Verifica Scrittura Transazionale su SQLite
      final cicli = await dbHelper.getAllCicli();
      expect(cicli, isNotEmpty);
      expect(cicli.first['recovery_score'], closeTo(recoveryScore, 1.0));
    });
  });
}
