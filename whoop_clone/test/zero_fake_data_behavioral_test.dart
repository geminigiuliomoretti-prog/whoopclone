import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:whoop_clone/data/biometrics/recovery_engine.dart';
import 'package:whoop_clone/data/ble/whoop_96byte_packet.dart';
import 'package:whoop_clone/data/database/database_helper.dart';
import 'package:whoop_clone/data/repositories/sqlite_whoop_repository.dart';
import 'package:whoop_clone/data/repositories/user_repository.dart';
import 'package:whoop_clone/data/services/overnight_sleep_engine.dart';
import 'package:whoop_clone/viewmodels/whoop_viewmodel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  DatabaseHelper.isTestMode = true;

  late DatabaseHelper dbHelper;
  late SqliteWhoopRepository repository;
  late UserRepository userRepository;
  late WhoopViewModel viewModel;
  late OvernightSleepEngine sleepEngine;

  setUpAll(() {
    DatabaseHelper.isTestMode = true;
  });

  setUp(() async {
    dbHelper = DatabaseHelper();
    await dbHelper.clearAllTables();
    repository = SqliteWhoopRepository(dbHelper: dbHelper);
    userRepository = UserRepository(db: dbHelper);
    viewModel = WhoopViewModel(repository: repository, userRepository: userRepository);
    sleepEngine = OvernightSleepEngine();
    await viewModel.loadData();
  });

  tearDown(() async {
    await dbHelper.clearAllTables();
  });

  group('ZERO FAKE PHYSIOLOGICAL DATA & TRUTHFUL STATE VERIFICATION (Phase 1)', () {
    test('1. GIVEN disconnected BLE & empty SQLite WHEN dashboard loads THEN strictly null vitals and zero fake fallbacks', () async {
      // GIVEN: BLE is disconnected, database is empty
      expect(viewModel.liveBpm, equals(0));
      expect(viewModel.liveHrvRmssd, equals(0.0));
      expect(viewModel.liveStressIndex, equals(0.0));

      // WHEN: dashboard loads
      await viewModel.loadData();

      // THEN: no fake physiology (no 55 bpm, no 65 ms, no 36.5°C)
      expect(viewModel.ultimoCiclo, isNull);
      expect(viewModel.ultimoSonno, isNull);
      expect(viewModel.recoveryScore, isNull);
      expect(viewModel.hrv, isNull);
      expect(viewModel.restingHr, isNull);
      expect(viewModel.respiratoryRate, isNull);
      expect(viewModel.skinTempDelta, isNull);
      expect(viewModel.bloodOxygenSpo2, isNull);

      // Vital evaluations must all be null
      final vitals = viewModel.vitalEvaluations;
      for (final v in vitals) {
        expect(v.currentVal, isNull, reason: 'Vital ${v.key} must be null when no data exists');
      }
    });

    test('2. GIVEN an overnight telemetry gap WHEN processed THEN gap epochs are marked MISSING and NEVER LIGHT SLEEP', () async {
      // GIVEN: 1 hour of valid sleep followed by 4 hours of missing telemetry (disconnection)
      final start = DateTime(2026, 10, 1, 23, 0);
      final nightEnd = start.add(const Duration(hours: 5)); // 5 hours total = 600 epochs

      // Insert 1 hour of quiet sleep
      final records = <Map<String, dynamic>>[];
      for (int s = 0; s < 120; s++) {
        records.add({
          'timestamp': start.add(Duration(seconds: s * 30)).toIso8601String(),
          'bpm': 50,
          'hr': 50.0,
          'rmssd': 70.0,
          'motion_var': 0.002,
          'resp_power': 0.8,
          'resp_rate': 14.0,
        });
      }

      // WHEN: OvernightSleepEngine processes the entire 5-hour window
      final result = await sleepEngine.processNightlyTelemetry(
        rawTelemetryRecords: records,
        userBaseline30d: {'rhr_mean': 52.0, 'rmssd_mean': 68.0, 'rmssd_std': 12.0},
        windowStart: start,
        windowEnd: nightEnd,
        targetDateIso: '2026-10-02',
      );

      // THEN: Total sleep must NOT count the 4-hour gap as sleep!
      expect(result['has_data'], isTrue);
      final double totalSleepMin = (result['total_sleep_min'] as num).toDouble();
      final double lightMin = (result['light_min'] as num).toDouble();
      final double missingMin = (result['missing_min'] as num).toDouble();

      // The 4-hour gap is 240 minutes. It must be tracked as missing_min, NOT light_min!
      expect(missingMin, greaterThanOrEqualTo(230.0), reason: 'Gap epochs must be classified as missing');
      expect(lightMin, lessThanOrEqualTo(65.0), reason: 'Missing epochs must NEVER become light sleep');
      expect(totalSleepMin, lessThanOrEqualTo(65.0), reason: 'Missing telemetry must NEVER inflate sleep duration');
    });

    test('3. GIVEN user manual sleep entry (7h45) without BLE THEN provenance is USER_ENTERED and stages/recovery are strictly 0/null', () async {
      // GIVEN: User inputs 7h45m sleep from 23:00 to 06:45 without any BLE telemetry in SQLite
      final start = DateTime(2026, 10, 2, 23, 0);
      final end = DateTime(2026, 10, 3, 6, 45);
      const dateIso = '2026-10-03';

      // WHEN: processAndAddManualSleep is called
      final res = await viewModel.processAndAddManualSleep(
        startTime: start,
        endTime: end,
        dateIso: dateIso,
        allowFallback: false,
      );

      // THEN: exactly 465 minutes recorded, with zero fake stages and null recovery/vitals
      expect(res['success'], isTrue);
      expect(res['hasRealBleData'], isFalse);
      expect(res['totalSleepMin'], equals(465.0));
      expect(res['swsMin'], equals(0.0));
      expect(res['remMin'], equals(0.0));
      expect(res['lightMin'], equals(0.0), reason: 'Manual sleep without BLE must not fabricate light sleep');
      expect(res['recoveryScore'], isNull);
      expect(res['hrv'], isNull);
      expect(res['rhr'], isNull);

      // Database verification
      final sonnoInDb = await dbHelper.getSonnoByDate(dateIso);
      expect(sonnoInDb, isNotNull);
      expect(sonnoInDb!['durata_tot_min'], equals(465));
      expect(sonnoInDb['sonno_profondo_min'], equals(0));
      expect(sonnoInDb['sonno_rem_min'], equals(0));
      expect(sonnoInDb['provenance'], equals('USER_ENTERED'));
    });

    test('4. GIVEN missing HRV in RecoveryEngine WHEN calculateRecoveryScore is called THEN returns strictly null', () {
      // GIVEN: RHR is available but HRV is missing (null or <= 0)
      final nullHrvResult = RecoveryEngine.calculateRecoveryScore(
        currentRmssdMs: null,
        historicalLnRmssd: [4.1, 4.2, 4.15],
        currentFcrBpm: 54.0,
        historicalRhr: [52.0, 53.0, 52.5],
      );
      expect(nullHrvResult, isNull, reason: 'Missing HRV must not produce recovery');

      final zeroHrvResult = RecoveryEngine.calculateRecoveryScore(
        currentRmssdMs: 0.0,
        historicalLnRmssd: [4.1, 4.2, 4.15],
        currentFcrBpm: 54.0,
        historicalRhr: [52.0, 53.0, 52.5],
      );
      expect(zeroHrvResult, isNull, reason: 'Zero HRV must not produce recovery');

      // GIVEN: HRV is available but RHR is missing (null or <= 0)
      final nullRhrResult = RecoveryEngine.calculateRecoveryScore(
        currentRmssdMs: 65.0,
        historicalLnRmssd: [4.1, 4.2, 4.15],
        currentFcrBpm: null,
        historicalRhr: [52.0, 53.0, 52.5],
      );
      expect(nullRhrResult, isNull, reason: 'Missing RHR must not produce recovery');
    });

    test('5. GIVEN stationary Whoop96BytePacket WHEN motion is absent THEN motionVariance returns 0.0 and NEVER 0.002', () {
      // GIVEN: flat 96-byte packet with 0.0 in motion variance bytes (bytes 8..11)
      final flatBytes = List<int>.filled(96, 0);
      final packet = Whoop96BytePacket.fromBytes(flatBytes);

      // THEN: motion is strictly 0.0
      expect(packet.motionVariance, equals(0.0), reason: 'Stationary packet motionVariance must be 0.0, never 0.002');
    });
  });
}
