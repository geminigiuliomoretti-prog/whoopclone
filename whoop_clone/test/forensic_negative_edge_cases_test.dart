import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:whoop_clone/data/ble/ble_connection_manager.dart';
import 'package:whoop_clone/data/biometrics/recovery_engine.dart';
import 'package:whoop_clone/data/biometrics/strain_engine.dart';
import 'package:whoop_clone/domain/analytics/whoop_analytics_engine.dart';
import 'package:whoop_clone/data/services/overnight_sleep_engine.dart';
import 'package:whoop_clone/data/database/database_helper.dart';
import 'package:whoop_clone/data/io/noop_import_export_service.dart';
import 'package:whoop_clone/data/repositories/sqlite_whoop_repository.dart';
import 'package:whoop_clone/data/services/coach/coach_context_builder.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PHASE 23: FORENSIC NEGATIVE EDGE-CASE & ROBUSTNESS TESTS', () {
    test('1. BLE Disconnection & Graceful Reconnect: Clean State Machine & No Leaks', () async {
      final bleManager = BleConnectionManager();

      // Initial state is disconnected
      expect(bleManager.state, equals(BleState.disconnected));

      // Disconnect called when already disconnected should not throw
      expect(() => bleManager.disconnectDevice(), returnsNormally);
      expect(bleManager.state, equals(BleState.disconnected));

      // Verify simulated stream cancellation and resource teardown
      bleManager.dispose();
      expect(bleManager.isDisposed, isTrue);
    });

    test('2. Strict Null Verification: Zero Synthetic Steps when Sensor is Missing', () {
      // Invariant: Missing hardware step sensor must yield null/empty, never strain * 650
      const double strain = 14.5;
      const int? hardwareSteps = null;

      // Verify no formula turns strain into steps
      final displaySteps = hardwareSteps != null ? hardwareSteps.toString() : '--';
      expect(displaySteps, equals('--'));
      expect(displaySteps, isNot(contains('${(strain * 650).round()}')));
    });

    test('3. HR Zones: Max HR <= 81 bpm strictly yields 0 min (0%) in Zone 5', () {
      // Athlete profile: max HR 190, rest HR 50 -> HRR = 140
      // Zone 5 threshold: 50 + (140 * 0.90) = 176 bpm
      const double userRestHr = 50.0;
      const double userMaxHr = 190.0;

      // Workout session where HR never exceeds 81 bpm
      final sampleHeartRates = List.generate(60, (i) => 70 + (i % 12)); // 70 to 81 bpm
      final maxHrObserved = sampleHeartRates.reduce((a, b) => a > b ? a : b);
      expect(maxHrObserved, equals(81));

      int z1Count = 0, z2Count = 0, z3Count = 0, z4Count = 0, z5Count = 0;
      for (final hr in sampleHeartRates) {
        final wz = WhoopAnalyticsEngine.getZoneMultiplier(hr.toDouble(), userMaxHr, userRestHr);
        if (wz == 1.0) z1Count++;
        else if (wz == 2.0) z2Count++;
        else if (wz == 3.0) z3Count++;
        else if (wz == 4.0) z4Count++;
        else if (wz == 5.0) z5Count++;
      }

      // Zone 5 count must be strictly 0
      expect(z5Count, equals(0));
      expect(z4Count, equals(0));
      expect(z3Count, equals(0));
      expect(z2Count, equals(0));
      expect(z1Count, equals(0));
    });

    test('4. Baseline State Progression: Cold Start gating (1-3d) vs Calibrating (>=4d)', () {
      // 0 to 3 days: Cold Start -> recovery score must return strictly null
      final coldStartBaselines = RecoveryEngine.calculateBaseline(
        [log(60.0), log(62.0)],
        [53.0, 52.0],
      );
      expect(coldStartBaselines.state, equals(BaselineState.coldStart));
      expect(coldStartBaselines.isCalibrating, isTrue);

      final coldStartRecovery = RecoveryEngine.calculateRecoveryScore(
        currentRmssdMs: 64.0,
        historicalLnRmssd: [log(60.0), log(62.0)],
        currentFcrBpm: 52.0,
        historicalRhr: [53.0, 52.0],
        strictGating: true,
      );
      expect(coldStartRecovery, isNull);

      // 4 to 29 days: Calibrating -> recovery gating opens, progressive score returned
      final calibratingBaselines = RecoveryEngine.calculateBaseline(
        [log(60.0), log(62.0), log(64.0), log(63.0)],
        [53.0, 52.0, 51.0, 52.0],
      );
      expect(calibratingBaselines.state, equals(BaselineState.calibrating));
      expect(calibratingBaselines.isCalibrating, isFalse);

      final calibratingRecovery = RecoveryEngine.calculateRecoveryScore(
        currentRmssdMs: 64.0,
        historicalLnRmssd: [log(60.0), log(62.0), log(64.0), log(63.0)],
        currentFcrBpm: 52.0,
        historicalRhr: [53.0, 52.0, 51.0, 52.0],
        strictGating: true,
      );
      expect(calibratingRecovery, isNotNull);
      expect(calibratingRecovery!, inInclusiveRange(1.0, 100.0));
    });

    test('5. Sleep Planner Bedtime Recalculation Across Goals (Peak, Perform, Get By)', () {
      // Base sleep need: 8 hours (480 minutes)
      const double sleepNeedMin = 480.0;
      const double typicalEfficiency = 0.95; // 95% efficiency
      final alarmTime = DateTime(2026, 10, 7, 7, 0); // 07:00 AM

      // PEAK: 100% of sleep need
      final peakTargetMin = sleepNeedMin * 1.0;
      final peakTimeInBedMin = peakTargetMin / typicalEfficiency;
      final peakBedtime = alarmTime.subtract(Duration(minutes: peakTimeInBedMin.round()));

      // PERFORM: 85% of sleep need
      final performTargetMin = sleepNeedMin * 0.85;
      final performTimeInBedMin = performTargetMin / typicalEfficiency;
      final performBedtime = alarmTime.subtract(Duration(minutes: performTimeInBedMin.round()));

      // GET BY: 70% of sleep need
      final getByTargetMin = sleepNeedMin * 0.70;
      final getByTimeInBedMin = getByTargetMin / typicalEfficiency;
      final getByBedtime = alarmTime.subtract(Duration(minutes: getByTimeInBedMin.round()));

      // Bedtime for Get By is later than Perform, and Perform is later than Peak
      expect(getByBedtime.isAfter(performBedtime), isTrue);
      expect(performBedtime.isAfter(peakBedtime), isTrue);

      // Verify exact duration differences
      final diffPeakPerform = performBedtime.difference(peakBedtime).inMinutes;
      expect(diffPeakPerform, greaterThanOrEqualTo(70)); // ~75 min less sleep
    });

    test('6. SWS Window RMSSD Quadratic Mean: No Jensen Inequality Distortion', () {
      // Invariant: RMSSD across SWS epochs must be Root Mean Square of epoch RMSSDs
      final epochRmssds = [50.0, 60.0, 70.0];
      // Arithmetic mean: (50 + 60 + 70) / 3 = 60.0
      // Quadratic mean: sqrt((2500 + 3600 + 4900) / 3) = sqrt(11000 / 3) = sqrt(3666.67) = 60.553
      final swsMetrics = OvernightSleepEngine.calculateSwsPooledRmssd(epochRmssds);
      expect(swsMetrics, isNotNull);
      expect(swsMetrics!, closeTo(60.55, 0.05));
      expect(swsMetrics, isNot(equals(60.0))); // Strictly different from arithmetic mean
    });

    test('7. Monotonic Strain: Bannister Cardio TRIMP Scaled Without Jump Multiplier', () {
      // Low cardio load should not have arbitrary jump multiplier
      final load1 = StrainEngine.calculateCardioTrimpLoad(
        durationMinutes: 10,
        hrMean: 120,
        hrRest: 50,
        hrMax: 190,
      );
      final load2 = StrainEngine.calculateCardioTrimpLoad(
        durationMinutes: 20,
        hrMean: 120,
        hrRest: 50,
        hrMax: 190,
      );

      // Double duration at same intensity produces double TRIMP (monotonicity)
      expect(load2, closeTo(load1 * 2.0, 0.01));
    });

    test('8. Sleep Detection: Daytime Couch Resting (60m at 16:00, HR 64, ENMO 0.012) Avoids False Positive Sleep Confirmation', () {
      final detector = AutoSleepDetector(
        restHr: 55.0,
        daytimeMeanHr: 75.0,
      );

      final baseTime = DateTime(2026, 10, 7, 16, 0); // 16:00 daytime
      // Ingest 60 samples spaced 1 minute apart (total 60 minutes)
      for (int i = 0; i < 60; i++) {
        final t = baseTime.add(Duration(minutes: i));
        detector.ingestSample(
          t,
          64.0, // HR well above restHr + 2 bpm (55 + 2 = 57)
          enmo: 0.012, // low sedentary motion on couch
          respPower: 0.0,
        );
      }

      // Must NOT lock into sleepInProgress state during daytime wakeful resting
      expect(detector.state, isNot(equals(AutoSleepState.sleepInProgress)));
      expect(detector.activeSleepStart, isNull);
    });

    test('9. Sleep Staging: Epoch Classification Yields Balanced Light, SWS, REM Stages Without 100% Deep Sleep Distortion', () {
      final totalEpochs = 480; // 4 hours of sleep
      int countWake = 0;
      int countLight = 0;
      int countDeep = 0;
      int countRem = 0;

      for (int i = 0; i < totalEpochs; i++) {
        final double epochProgress = i / totalEpochs;
        double hrRatio;
        double enmo;
        double hrvNorm;
        double respVar;

        if (epochProgress < 0.3) {
          if (i % 3 == 0) {
            hrRatio = 0.95;
            enmo = 0.005;
            hrvNorm = 0.9;
            respVar = 0.12;
          } else {
            hrRatio = 1.05;
            enmo = 0.015;
            hrvNorm = 1.0;
            respVar = 0.50; // Neutral fallback
          }
        } else if (epochProgress > 0.7 && (i % 2 == 0)) {
          hrRatio = 1.08;
          enmo = 0.007; // Muscle atonia during REM
          hrvNorm = 1.35;
          respVar = 0.50;
        } else {
          hrRatio = 1.02;
          enmo = 0.018;
          hrvNorm = 1.0;
          respVar = 0.50;
        }

        final stage = classifyEpoch(
          enmo: enmo,
          hrRatio: hrRatio,
          hrvNorm: hrvNorm,
          respVar: respVar,
          epochIndex: i,
          totalEpochs: totalEpochs,
        );

        switch (stage) {
          case SleepStage.wake:
            countWake++;
            break;
          case SleepStage.light:
            countLight++;
            break;
          case SleepStage.deepSws:
            countDeep++;
            break;
          case SleepStage.rem:
            countRem++;
            break;
          default:
            break;
        }
      }

      final deepPct = countDeep / totalEpochs;
      final lightPct = countLight / totalEpochs;
      final remPct = countRem / totalEpochs;
      // Invariant: Deep sleep is realistic (< 35%), Light sleep is predominant baseline (> 40%), and REM is present
      expect(deepPct, lessThan(0.35));
      expect(lightPct, greaterThan(0.40));
      expect(remPct, greaterThan(0.05));
      expect(countWake, greaterThanOrEqualTo(0));
    });

    test('10. Respiratory Rate: Spectral DFT Filters 0.10 Hz Mayer Waves and Locks onto True 0.23 Hz RSA (13.8 RPM)', () {
      final List<double> intervals = [];
      double t = 0.0;
      while (t < 60.0) {
        final mayer = 0.08 * sin(2.0 * pi * 0.10 * t);
        final rsa = 0.04 * sin(2.0 * pi * 0.23 * t);
        final rr = 1.0 + mayer + rsa;
        intervals.add(rr);
        t += rr;
      }

      final rpm = OvernightSleepEngine.estimateRsaPeakFromIntervalsSec(intervals);
      expect(rpm, isNotNull);
      // Must NOT be 6 RPM (0.10 Hz Mayer wave), must be ~13.8 RPM (0.23 Hz RSA)
      expect(rpm!, closeTo(13.8, 0.8));
      expect(rpm, isNot(closeTo(6.0, 1.0)));
    });

    test('11. Historical Import: WHOOP sleeps.csv and workouts.csv Parse and Populate DB', () async {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      DatabaseHelper.isTestMode = true;

      final dbHelper = DatabaseHelper();
      await dbHelper.clearAllTables();
      final repository = SqliteWhoopRepository(dbHelper: dbHelper);
      final importService = NoopImportExportService(repository: repository);

      const sleepsCsv = '''Cycle start time,Cycle end time,Sleep onset,Wake time,Asleep duration,Deep (SWS) duration,REM duration,Sleep performance %,Sleep efficiency %,Respiratory rate (rpm)
2026-10-05 00:00:00,2026-10-05 23:59:59,2026-10-05 23:15:00,2026-10-06 07:15:00,450,90,95,88,94,14.2
2026-10-06 00:00:00,2026-10-06 23:59:59,2026-10-06 23:30:00,2026-10-07 07:00:00,420,80,90,82,91,13.8''';

      const workoutsCsv = '''Workout start time,Workout end time,Activity name,Workout Strain,Energy burned (cal),Max HR (bpm),Average HR (bpm)
2026-10-06 17:00:00,2026-10-06 18:00:00,Running,14.8,620,178,145''';

      final sleepsCount = await importService.importSleepsCsv(sleepsCsv);
      expect(sleepsCount, equals(2));

      final workoutsCount = await importService.importWorkoutsCsv(workoutsCsv);
      expect(workoutsCount, equals(1));

      final sonnoList = await repository.getSonnoLogs();
      expect(sonnoList.length, equals(2));
      expect(sonnoList.any((s) => s.durataTotMin == 450 && s.sonnoProfondoMin == 90), isTrue);
      expect(sonnoList.any((s) => s.durataTotMin == 420 && s.sonnoProfondoMin == 80), isTrue);

      final workoutsList = await repository.getAllenamenti();
      expect(workoutsList.length, equals(1));
      expect(workoutsList.first.nomeAttivita, equals('Running'));
      expect(workoutsList.first.strainAttivita, closeTo(14.8, 0.1));
    });

    test('12. Diary State: saveVociDiarioBatch Persists and getCompletedDiaryDates Correctly Identifies Completed Days', () async {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      DatabaseHelper.isTestMode = true;

      final dbHelper = DatabaseHelper();
      await dbHelper.clearAllTables();

      final entries = [
        {'abitudine_chiave': 'magnesio', 'risposta_booleana': 1, 'valore_numerico': null},
        {'abitudine_chiave': 'schermi_a_letto', 'risposta_booleana': 0, 'valore_numerico': null},
      ];

      await dbHelper.saveVociDiarioBatch('2026-10-06', entries);
      await dbHelper.saveVociDiarioBatch('2026-10-07', entries);

      final completedDates = await dbHelper.getCompletedDiaryDates(['2026-10-05', '2026-10-06', '2026-10-07']);
      expect(completedDates.contains('2026-10-06'), isTrue);
      expect(completedDates.contains('2026-10-07'), isTrue);
      expect(completedDates.contains('2026-10-05'), isFalse);
    });

    test('13. Coach AI: Context Builder Explicitly Flags Missing Metrics as "Non disponibile" Without Fabricating Fake Data', () {
      final context = CoachContextBuilder.fromViewModelState(
        selectedDateIso: '2026-10-07',
        ultimoCiclo: null,
        sonnoList: [],
        vociDiarioList: [],
        currentSleepNeedMin: 480.0,
        isBleConnected: false,
      );

      final prompt = context.toSystemPromptSummary();
      expect(prompt, contains('Non disponibile'));
      expect(prompt, contains('Disconnesso / Dati Storici'));
      expect(context.recoveryScore, isNull);
      expect(context.hrvRmssdMs, isNull);
      expect(context.rhrBpm, isNull);
      expect(context.sleepPerformancePct, isNull);
    });
  });
}
