import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:whoop_clone/data/ble/noop_protocol_decoder.dart';
import 'package:whoop_clone/data/database/database_helper.dart';
import 'package:whoop_clone/data/io/noop_import_export_service.dart';
import 'package:whoop_clone/data/models/ciclo_fisiologico.dart';
import 'package:whoop_clone/data/repositories/sqlite_whoop_repository.dart';
import 'package:whoop_clone/data/services/noop_workout_detector.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  DatabaseHelper.isTestMode = true;

  group('Sprint 7 — NOOP Repository Logic & Infrastructure Tests', () {
    late DatabaseHelper dbHelper;
    late SqliteWhoopRepository repository;
    late NoopImportExportService importExportService;

    setUp(() async {
      dbHelper = DatabaseHelper();
      await dbHelper.clearAllTables();
      repository = SqliteWhoopRepository(dbHelper: dbHelper);
      importExportService = NoopImportExportService(repository: repository);
    });

    test('1. CRC-32 Custom WHOOP (0xF43F44AC) & 20-Byte HapticClockEncoder Payload', () {
      final testData = [0xAA, 0x10, 0x00, 0x57, 0x23, 0x70, 0x42, 0x01, 0x50, 0x11, 0x65, 0x66, 0x00, 0x00, 0x00, 0x00];
      final crc = WhoopCrc32.compute(testData);
      expect(crc, isA<int>());
      expect(crc, greaterThan(0));

      const targetUtc = 1717171717;
      final payload = HapticClockEncoder.BuildAlarmCommandPayload(targetUtc, 0x01, 0x0142);

      expect(payload.length, equals(20));
      expect(payload[0], equals(0xAA));
      expect(payload[1], equals(0x10));
      expect(payload[2], equals(0x00));
      expect(payload[3], equals(0x57));
      expect(payload[4], equals(0x23));

      expect(payload[5], equals(0x01));

      expect(payload[6], equals(0x42));
      expect(payload[7], equals(0x01));

      final extractedUtc = payload[8] | (payload[9] << 8) | (payload[10] << 16) | (payload[11] << 24);
      expect(extractedUtc, equals(targetUtc));

      expect(payload[12], equals(0x00));
      expect(payload[13], equals(0x00));
      expect(payload[14], equals(0x00));
      expect(payload[15], equals(0x00));

      expect(WhoopCrc32.verify(payload), isTrue);
    });

    test('2. WHOOP CSV Export & Import Roundtrip (StrandImport da noop)', () async {
      await repository.insertCicloFisiologico(const CicloFisiologico(
        dataIso: '2026-08-09',
        strainGiornaliero: 14.5,
        recoveryScore: 82.0,
        rhrNotte: 52.0,
        hrvNotte: 78.0,
      ));

      final csv = await importExportService.exportPhysiologicalCyclesCsv();
      expect(csv, contains('Cycle start time,Cycle end time'));
      expect(csv, contains('2026-08-09'));
      expect(csv, contains('14.5'));
      expect(csv, contains('82'));

      await dbHelper.clearAllTables();
      final count = await importExportService.importPhysiologicalCyclesCsv(csv);
      expect(count, equals(1));

      final importedCiclo = await repository.physiologyRepository.getByDate('2026-08-09');
      expect(importedCiclo, isNotNull);
      expect(importedCiclo!.sforzoGiornaliero, equals(14.5));
      expect(importedCiclo.punteggioRecuperoPct, equals(82.0));
    });

    test('3. AutoWorkoutDetector: Elevazione prolungata HR genera allenamento automatico (StrandAnalytics da noop)', () async {
      final detector = AutoWorkoutDetector(
        restHr: 60.0,
        minDurationMinutes: 15,
        hrThresholdMultiplier: 1.3,
        dbHelper: dbHelper,
      );
      final now = DateTime.now();

      bool workoutTriggered = false;
      detector.autoWorkoutDetectedStream.listen((allenamento) {
        workoutTriggered = true;
        expect(allenamento.durataMin, greaterThanOrEqualTo(15));
        expect(allenamento.hrMedia, greaterThanOrEqualTo(130));
      });

      for (int i = 0; i < 16 * 60; i++) {
        detector.processBpmSample(140, now.add(Duration(seconds: i)));
      }
      detector.processBpmSample(65, now.add(const Duration(minutes: 17)));

      await Future.delayed(const Duration(milliseconds: 100));
      expect(workoutTriggered, isTrue);
    });

    test('4. BatteryEstimator: Calcolo tasso scarica e stima ore rimanenti (StrandAnalytics da noop)', () {
      final estimator = BatteryEstimator();
      final t0 = DateTime.now();

      estimator.recordBatteryLevel(100, t0);
      estimator.recordBatteryLevel(96, t0.add(const Duration(hours: 5)));

      final rate = estimator.calculateDischargeRatePctPerHour();
      expect(rate, closeTo(0.8, 0.05));

      final remainingHours = estimator.estimateHoursRemaining(96);
      expect(remainingHours, closeTo(120.0, 5.0));
    });

    test('5. Auto Workout Detector: FSM Start-Backdating, End-Backdating, Classificazione Corsa & Scrittura SQLite', () async {
      final detector = AutoWorkoutDetector(
        restHr: 60.0,
        maxHr: 190.0,
        tSustainSec: 60, // 60s per test rapido
        tCooldownSec: 30, // 30s cooldown per test rapido
        dbHelper: dbHelper,
      );

      final startTimeBase = DateTime(2026, 8, 10, 10, 0, 0);

      // 1. Fase Riposo (30 sec @ 60 BPM, ENMO 0.010g)
      for (int i = 0; i < 30; i++) {
        detector.ingestSensorFrame(
          startTimeBase.add(Duration(seconds: i)),
          60,
          enmo: 0.010,
        );
      }

      // 2. Fase Inizio Corsa t = 30s (Innalzamento a 150 BPM, ENMO 0.300g per Corsa)
      for (int i = 30; i < 120; i++) {
        detector.ingestSensorFrame(
          startTimeBase.add(Duration(seconds: i)),
          155,
          enmo: 0.300,
        );
      }

      expect(detector.state, equals(AutoWorkoutState.workoutActive));
      expect(detector.activeWorkoutStart, isNotNull);
      expect(detector.activeWorkoutStart!.difference(startTimeBase).inSeconds, closeTo(30, 2));

      // 3. Fase Cooldown a Riposo per 35 sec (BPM 62 < hrEnd, ENMO 0.01g)
      for (int i = 120; i < 160; i++) {
        detector.ingestSensorFrame(
          startTimeBase.add(Duration(seconds: i)),
          62,
          enmo: 0.010,
        );
      }

      await Future.delayed(const Duration(milliseconds: 100));

      expect(detector.state, equals(AutoWorkoutState.idleMonitoring));

      // Verifica Scrittura Transazionale su SQLite WAL
      final allenamenti = await dbHelper.getAllAllenamenti();
      expect(allenamenti, isNotEmpty);

      final lastWorkout = allenamenti.first;
      expect(lastWorkout['nome_attivita'], equals('Corsa'));
      expect(lastWorkout['hr_media'], greaterThanOrEqualTo(140));
    });
  });
}
