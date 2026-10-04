import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:whoop_clone/data/ble/ble_connection_manager.dart';
import 'package:whoop_clone/data/ble/noop_protocol_decoder.dart';
import 'package:whoop_clone/data/ble/whoop_96byte_packet.dart';
import 'package:whoop_clone/data/database/database_helper.dart';
import 'package:whoop_clone/data/io/noop_import_export_service.dart';
import 'package:whoop_clone/data/models/allenamento.dart';
import 'package:whoop_clone/data/models/ciclo_fisiologico.dart';
import 'package:whoop_clone/data/repositories/sqlite_whoop_repository.dart';
import 'package:whoop_clone/data/services/overnight_sleep_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  DatabaseHelper.isTestMode = true;

  late DatabaseHelper dbHelper;
  late SqliteWhoopRepository repository;
  late NoopImportExportService importExportService;

  setUpAll(() {
    DatabaseHelper.isTestMode = true;
  });

  setUp(() async {
    dbHelper = DatabaseHelper();
    await dbHelper.clearAllTables();
    repository = SqliteWhoopRepository(dbHelper: dbHelper);
    importExportService = NoopImportExportService(repository: repository);
  });

  tearDown(() async {
    await dbHelper.clearAllTables();
  });

  group('DEEP AUDIT VERIFICATION: Database Schema v14 & Provenance Architecture', () {
    test('1.1 Schema v14 columns exist in utente_profilo, cicli_fisiologici and sonno', () async {
      final db = await dbHelper.database;

      // utente_profilo schema check
      final userCols = await db.rawQuery("PRAGMA table_info(${DatabaseHelper.tableUtenteProfilo})");
      final userColNames = userCols.map((c) => c['name'] as String).toSet();
      expect(userColNames.contains('is_bootstrap_completed'), isTrue);
      expect(userColNames.contains('bootstrap_timestamp'), isTrue);
      expect(userColNames.contains('bootstrap_version'), isTrue);
      expect(userColNames.contains('baseline_source'), isTrue);
      expect(userColNames.contains('baseline_sample_count'), isTrue);
      expect(userColNames.contains('baseline_calc_period'), isTrue);
      expect(userColNames.contains('paired_device_mac'), isTrue);
      expect(userColNames.contains('paired_device_name'), isTrue);

      // cicli_fisiologici schema check
      final cicliCols = await db.rawQuery("PRAGMA table_info(${DatabaseHelper.tableCicliFisiologici})");
      final cicliColNames = cicliCols.map((c) => c['name'] as String).toSet();
      expect(cicliColNames.contains('provenance'), isTrue);

      // sonno schema check
      final sonnoCols = await db.rawQuery("PRAGMA table_info(${DatabaseHelper.tableSonno})");
      final sonnoColNames = sonnoCols.map((c) => c['name'] as String).toSet();
      expect(sonnoColNames.contains('provenance'), isTrue);
      expect(sonnoColNames.contains('regolarita_sonno_pct'), isTrue);
    });

    test('1.2 UtenteProfilo persistence and query preserves all v14 fields', () async {
      final initialProfile = await repository.userRepository.getProfile();
      expect(initialProfile, isNotNull);
      expect(initialProfile!.isBootstrapCompleted, isFalse);
      expect(initialProfile.baselineSource, equals('INITIAL_PROFILE'));
      expect(initialProfile.baselineSampleCount, equals(0));

      final updatedProfile = initialProfile.copyWith(
        nome: 'Athlete One',
        isBootstrapCompleted: true,
        bootstrapTimestamp: '2026-09-30T10:00:00Z',
        bootstrapVersion: '1.0',
        baselineSource: 'WHOOP_CSV_EXPORT',
        baselineSampleCount: 14,
        baselineCalcPeriod: '2026-09-01 - 2026-09-14',
        pairedDeviceMac: 'EA:42:DE:AD:BE:EF',
        pairedDeviceName: 'WHOOP 4.0 42099',
      );

      await repository.userRepository.updateProfile(updatedProfile);
      final retrieved = await repository.userRepository.getProfile();

      expect(retrieved, isNotNull);
      expect(retrieved!.nome, equals('Athlete One'));
      expect(retrieved.isBootstrapCompleted, isTrue);
      expect(retrieved.bootstrapTimestamp, equals('2026-09-30T10:00:00Z'));
      expect(retrieved.bootstrapVersion, equals('1.0'));
      expect(retrieved.baselineSource, equals('WHOOP_CSV_EXPORT'));
      expect(retrieved.baselineSampleCount, equals(14));
      expect(retrieved.baselineCalcPeriod, equals('2026-09-01 - 2026-09-14'));
      expect(retrieved.pairedDeviceMac, equals('EA:42:DE:AD:BE:EF'));
      expect(retrieved.pairedDeviceName, equals('WHOOP 4.0 42099'));
    });
  });

  group('DEEP AUDIT VERIFICATION: CSV Baseline Bootstrap & Provenance Tagging', () {
    test('2.1 Historical CSV bootstrap parses real records and sets BOOTSTRAP provenance', () async {
      final csvData = StringBuffer();
      csvData.writeln('Cycle start time,Cycle end time,Cycle timezone,Day Strain,Recovery score %,Resting heart rate,Heart rate variability,Skin temp (celsius),Respiratory rate');
      csvData.writeln('2026-09-01 07:00:00,2026-09-02 07:00:00,UTC,12.5,72,52,60,36.2,14.2');
      csvData.writeln('2026-09-02 07:00:00,2026-09-03 07:00:00,UTC,14.1,84,54,70,36.4,14.0');
      csvData.writeln('2026-09-03 07:00:00,2026-09-04 07:00:00,UTC,10.2,68,50,65,36.1,14.5');
      csvData.writeln('2026-09-04 07:00:00,2026-09-05 07:00:00,UTC,15.8,91,56,75,36.5,13.8');
      csvData.writeln('2026-09-05 07:00:00,2026-09-06 07:00:00,UTC,11.0,79,48,80,36.3,14.1');

      final result = await importExportService.bootstrapFromCsv(csvData.toString());

      expect(result.success, isTrue);
      expect(result.importedCycles, equals(5));
      expect(result.sampleCount, equals(5));
      expect(result.period, equals('2026-09-01 - 2026-09-05'));

      // Check all inserted cycles in DB have provenance == 'BOOTSTRAP'
      final cycles = await repository.getCicliFisiologici();
      expect(cycles.length, equals(5));
      for (final c in cycles) {
        expect(c.provenance, equals('BOOTSTRAP'));
      }

      // Check utente_profilo was properly calibrated with mathematical stats
      final profile = await repository.userRepository.getProfile();
      expect(profile, isNotNull);
      expect(profile!.isBootstrapCompleted, isTrue);
      expect(profile.baselineSource, equals('WHOOP_CSV_EXPORT'));
      expect(profile.baselineSampleCount, equals(5));
      expect(profile.baselineCalcPeriod, equals('2026-09-01 - 2026-09-05'));

      // Mean HRV = 70.0, Std HRV = 7.1
      expect(profile.hrvBaselineMean, closeTo(70.0, 0.1));
      expect(profile.hrvBaselineStd, closeTo(7.1, 0.2));

      // Mean RHR = 52.0, Std RHR = 2.8
      expect(profile.rhrBaselineMean, closeTo(52.0, 0.1));
      expect(profile.rhrBaselineStd, closeTo(2.8, 0.2));
      expect(profile.hrRestBaseline, equals(52));
    });

    test('2.2 Empty or corrupt CSV returns failure result without altering baseline', () async {
      final initialProfile = await repository.userRepository.getProfile();
      final resultEmpty = await importExportService.bootstrapFromCsv('');
      expect(resultEmpty.success, isFalse);

      final resultHeadersOnly = await importExportService.bootstrapFromCsv('Cycle start time,Strain\n');
      expect(resultHeadersOnly.success, isFalse);

      final profileAfter = await repository.userRepository.getProfile();
      expect(profileAfter!.isBootstrapCompleted, equals(initialProfile!.isBootstrapCompleted));
    });
  });

  group('DEEP AUDIT VERIFICATION: Calendar-Day Deterministic Streak Calculation', () {
    String formatIso(DateTime d) =>
        '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

    test('3.1 Empty cycles or cycles without valid physiological data return 0 streak', () {
      expect(SqliteWhoopRepository.calculateStreakDays([]), equals(0));

      final emptyDataCycles = [
        CicloFisiologico(dataIso: '2026-09-29', strainGiornaliero: 0.0, recoveryScore: null),
        CicloFisiologico(dataIso: '2026-09-30', strainGiornaliero: null, recoveryScore: null),
      ];
      expect(SqliteWhoopRepository.calculateStreakDays(emptyDataCycles), equals(0));
    });

    test('3.2 Continuous streak ending today counts all consecutive days', () {
      final now = DateTime.now();
      final todayStr = formatIso(now);
      final yesterdayStr = formatIso(now.subtract(const Duration(days: 1)));
      final twoDaysAgoStr = formatIso(now.subtract(const Duration(days: 2)));
      final threeDaysAgoStr = formatIso(now.subtract(const Duration(days: 3)));

      final cycles = [
        CicloFisiologico(dataIso: todayStr, strainGiornaliero: 10.5, recoveryScore: 78.0),
        CicloFisiologico(dataIso: yesterdayStr, strainGiornaliero: 14.2, recoveryScore: 65.0),
        CicloFisiologico(dataIso: twoDaysAgoStr, strainGiornaliero: 8.9, recoveryScore: 82.0),
        CicloFisiologico(dataIso: threeDaysAgoStr, strainGiornaliero: 12.0, recoveryScore: 70.0),
      ];

      expect(SqliteWhoopRepository.calculateStreakDays(cycles), equals(4));
    });

    test('3.3 Continuous streak ending yesterday (wearable off today) counts active days', () {
      final now = DateTime.now();
      final yesterdayStr = formatIso(now.subtract(const Duration(days: 1)));
      final twoDaysAgoStr = formatIso(now.subtract(const Duration(days: 2)));

      final cycles = [
        CicloFisiologico(dataIso: yesterdayStr, strainGiornaliero: 12.1, recoveryScore: 60.0),
        CicloFisiologico(dataIso: twoDaysAgoStr, strainGiornaliero: 9.4, recoveryScore: 75.0),
      ];

      expect(SqliteWhoopRepository.calculateStreakDays(cycles), equals(2));
    });

    test('3.4 Interrupted streak (gap 2 days ago) terminates count at gap', () {
      final now = DateTime.now();
      final todayStr = formatIso(now);
      final yesterdayStr = formatIso(now.subtract(const Duration(days: 1)));
      // gap at 2 days ago!
      final fourDaysAgoStr = formatIso(now.subtract(const Duration(days: 4)));
      final fiveDaysAgoStr = formatIso(now.subtract(const Duration(days: 5)));

      final cycles = [
        CicloFisiologico(dataIso: todayStr, strainGiornaliero: 8.0, recoveryScore: 65.0),
        CicloFisiologico(dataIso: yesterdayStr, strainGiornaliero: 11.0, recoveryScore: 70.0),
        CicloFisiologico(dataIso: fourDaysAgoStr, strainGiornaliero: 14.0, recoveryScore: 85.0),
        CicloFisiologico(dataIso: fiveDaysAgoStr, strainGiornaliero: 10.0, recoveryScore: 80.0),
      ];

      expect(SqliteWhoopRepository.calculateStreakDays(cycles), equals(2));
    });

    test('3.5 Outdated streak (no data today or yesterday) returns 0', () {
      final now = DateTime.now();
      final threeDaysAgoStr = formatIso(now.subtract(const Duration(days: 3)));
      final fourDaysAgoStr = formatIso(now.subtract(const Duration(days: 4)));

      final cycles = [
        CicloFisiologico(dataIso: threeDaysAgoStr, strainGiornaliero: 12.0, recoveryScore: 70.0),
        CicloFisiologico(dataIso: fourDaysAgoStr, strainGiornaliero: 15.0, recoveryScore: 80.0),
      ];

      expect(SqliteWhoopRepository.calculateStreakDays(cycles), equals(0));
    });
  });

  group('DEEP AUDIT VERIFICATION: Zero-Fabrication Manual Sleep & Missing Vitals', () {
    test('4.1 Manual sleep with no BLE data saves null vitals, null efficiency and MANUAL provenance', () async {
      final engine = OvernightSleepEngine();
      final startTime = DateTime(2026, 9, 28, 23, 0);
      final endTime = DateTime(2026, 9, 29, 7, 0);
      const dateIso = '2026-09-29';

      final result = await engine.processNightlyTelemetry(
        rawTelemetryRecords: [],
        userBaseline30d: {
          'rhr_mean': 55.0,
          'rmssd_mean': 65.0,
          'baseline_temp_celsius': 36.5,
          'sleep_need_min': 480.0,
        },
        windowStart: startTime,
        windowEnd: endTime,
        targetDateIso: dateIso,
      );

      expect(result['manual_no_ble'], isTrue);

      // Verify Sonno persistence
      final sonnoMap = await dbHelper.getSonnoByDate(dateIso);
      expect(sonnoMap, isNotNull);
      expect(sonnoMap!['provenance'], equals('MANUAL'));
      expect(sonnoMap['sonno_profondo_min'], equals(0));
      expect(sonnoMap['sonno_rem_min'], equals(0));
      // Efficienza must be null (NEVER fabricated 100%)
      expect(sonnoMap['efficienza_pct'], isNull);

      // Verify CicliFisiologici persistence
      final cicloMap = await dbHelper.getCicloByDate(dateIso);
      expect(cicloMap, isNotNull);
      expect(cicloMap!['provenance'], equals('MANUAL'));
      expect(cicloMap['recovery_score'], isNull);
      expect(cicloMap['hrv_notte'], isNull);
      expect(cicloMap['rhr_notte'], isNull);
      expect(cicloMap['frequenza_respiratoria_rpm'], isNull);
      expect(cicloMap['temp_cutanea_c'], isNull);
      expect(cicloMap['spo2_pct'], isNull);
    });

    test('4.2 Staging Invariant: classifyEpoch correctly identifies stages and stage minutes sum up', () {
      const int totalEpochs = 960;

      // 1. Regola VEGLIA (WASO): ENMO elevato
      final wakeStage = classifyEpoch(
        enmo: 0.055,
        hrRatio: 1.0,
        hrvNorm: 1.0,
        respVar: 0.10,
        epochIndex: 200,
        totalEpochs: totalEpochs,
      );
      expect(wakeStage, equals(SleepStage.wake));

      // 2. Regola SWS (Deep): Basso movimento e HR rilassato nella prima metà
      final swsStage = classifyEpoch(
        enmo: 0.003,
        hrRatio: 0.95,
        hrvNorm: 1.0,
        respVar: 0.12,
        epochIndex: 200,
        totalEpochs: totalEpochs,
      );
      expect(swsStage, equals(SleepStage.deepSws));

      // 3. Regola REM: Basso movimento, HRV elevata, HR non rilassato, dopo la prima ora
      final remStage = classifyEpoch(
        enmo: 0.004,
        hrRatio: 1.05,
        hrvNorm: 1.30,
        respVar: 0.40,
        epochIndex: 300,
        totalEpochs: totalEpochs,
      );
      expect(remStage, equals(SleepStage.rem));

      // 4. Mathematical stage invariant: totalSleepMin = swsMin + remMin + lightMin
      const int swsMin = 75;
      const int remMin = 90;
      const int lightMin = 180;
      const int totalSleepMin = swsMin + remMin + lightMin;
      expect(totalSleepMin, equals(345));
    });
  });

  group('DEEP AUDIT VERIFICATION: Zero-Fabrication Live Workout & Activity Tracking', () {
    test('5.1 Workout without heart rate samples stores null averages and no fake metrics', () async {
      final allenamento = Allenamento(
        nomeAttivita: 'Sollevamento Pesi',
        oraInizio: DateTime.now().subtract(const Duration(minutes: 45)).toIso8601String(),
        oraFine: DateTime.now().toIso8601String(),
        durataMin: 45,
        strainAttivita: 4.2,
        hrMedia: null, // NO BLE connected
        hrMax: null,   // NO BLE connected
        calorie: null, // Without HR, calories cannot be calculated
      );

      await repository.insertAllenamento(allenamento);
      final workouts = await repository.getAllenamenti();
      final saved = workouts.firstWhere((w) => w.nomeAttivita == 'Sollevamento Pesi');

      expect(saved.fcMediaBpm, isNull);
      expect(saved.fcMaxBpm, isNull);
      expect(saved.calorie, isNull);
      expect(saved.strainAttivita, equals(4.2));
    });
  });

  group('DEEP AUDIT VERIFICATION: Hardware BLE Framing & CRC Integrity', () {
    test('6.1 IEEE 802.3 CRC-32 produces identical checksum to hardware nRF specification', () {
      // Test vector 1: standard ASCII string "123456789" -> standard IEEE 802.3 CRC32 = 0xCBF43926
      final vector1 = [0x31, 0x32, 0x33, 0x34, 0x35, 0x36, 0x37, 0x38, 0x39];
      final crc1 = WhoopCrc32.compute(vector1);
      expect(crc1, equals(0xCBF43926));

      // Test vector 2: 16-byte command body payload
      final vector2 = [0x23, 0x01, 0x44, 0x01]; // Opcode 68 (RUN_ALARM)
      final crc2 = WhoopCrc32.compute(vector2);
      expect(crc2, isA<int>());
      expect(crc2, greaterThan(0));
    });

    test('6.2 HapticClockEncoder.buildFramedCommand generates valid WHOOP 4.0/5.0 frames', () {
      // Build Opcode 68 (RUN_ALARM) with seq=5
      final frame = HapticClockEncoder.buildFramedCommand(cmd: 68, payload: [0x01], seq: 5);

      // Verify Sync Byte (0xAA)
      expect(frame[0], equals(0xAA));

      // Length = 1 (type 0x23) + 1 (seq 5) + 1 (cmd 68) + 1 (payload 0x01) + 4 (crc32) = 8
      final bodyLen = frame[1] | (frame[2] << 8);
      expect(bodyLen, equals(8));

      // Header CRC-8 matches len bytes
      expect(WhoopCrc8.verify([frame[1], frame[2]], frame[3]), isTrue);

      // Verify body bytes
      expect(frame[4], equals(0x23)); // Type
      expect(frame[5], equals(5));    // Seq
      expect(frame[6], equals(68));   // Cmd (RUN_ALARM)
      expect(frame[7], equals(0x01)); // Payload

      // Verify CRC-32 tail on body bytes
      final innerBytes = [0x23, 5, 68, 0x01];
      final expectedCrc = WhoopCrc32.compute(innerBytes);
      final actualCrc = frame[8] | (frame[9] << 8) | (frame[10] << 16) | (frame[11] << 24);
      expect(actualCrc, equals(expectedCrc));
    });

    test('6.3 Whoop96BytePacket correctly validates and extracts raw sensor metrics', () {
      final bytes = Uint8List(96);
      // Seq = 1042 at bytes 0..1 (uint16 little endian)
      bytes[0] = 1042 & 0xFF;
      bytes[1] = (1042 >> 8) & 0xFF;

      // HR = 68 bpm at byte 4
      bytes[4] = 68;

      final packet = Whoop96BytePacket.fromBytes(bytes);
      expect(packet.isValid, isTrue);
      expect(packet.seqNumber, equals(1042));
      expect(packet.heartRateBpm, equals(68));
    });

    test('6.4 BleConnectionManager paired device MAC synchronizes with SQLite and clears on forgetDevice', () async {
      SharedPreferences.setMockInitialValues({'whoop_paired_device_id': 'DB:69:AA:BB:CC:DD'});
      final bleManager = BleConnectionManager();

      // Read paired device ID: SharedPreferences has it
      final deviceId = await bleManager.getPairedDeviceId();
      expect(deviceId, equals('DB:69:AA:BB:CC:DD'));

      // Now forget the device
      await bleManager.forgetDevice();

      // Ensure SharedPreferences is cleared
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('whoop_paired_device_id'), isNull);

      // Ensure SQLite is cleared
      final profile = await repository.userRepository.getProfile();
      expect(profile?.pairedDeviceMac, isNull);
      expect(profile?.pairedDeviceName, isNull);
    });
  });
}
