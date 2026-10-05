import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:whoop_clone/data/database/database_helper.dart';
import 'package:whoop_clone/data/services/overnight_sleep_engine.dart';
import 'package:whoop_clone/viewmodels/whoop_viewmodel.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    DatabaseHelper.isTestMode = true;
  });

  tearDown(() async {
    await DatabaseHelper().clearAllTables();
  });

  group('Full Automated Sleep Detection, Staging & Metric Trigger Pipeline Tests', () {
    test('Automated State-Machine Sleep Detection & Last-SWS Extraction (9-Hour Telemetry Stream)', () async {
      final dbHelper = DatabaseHelper();
      final engine = OvernightSleepEngine(dbHelper: dbHelper);

      // Simula 9 ore di telemetria a epoche di 30 secondi (1080 epoche = 9h)
      // Base time: ieri sera ore 22:30 fino a stamattina ore 07:30 (SLP-02: risveglio il 2026-08-14)
      final baseStartTime = DateTime(2026, 8, 13, 22, 30);
      final dateIso = '2026-08-14';

      final autoSleepDetector = AutoSleepDetector(
        restHr: 52.0,
        daytimeMeanHr: 76.0,
        hrvBaseline: 68.0,
        enmoSleepThresh: 0.015,
        enmoWakeThresh: 0.080,
        tSleepSustainSec: 30, // Finestra adattata a 30 campioni per simulazione fluida
        tWakeSustainSec: 15,
        sleepEngine: engine,
        userBaselineProvider: () => {
          'rhr_mean': 52.0,
          'rmssd_mean': 68.0,
          'rmssd_std': 12.0,
          'baseline_temp_celsius': 36.5,
          'sleep_baseline_min': 480,
          'sleep_need_min': 480,
        },
      );

      Map<String, dynamic>? emittedResult;
      final sub = autoSleepDetector.autoSleepDetectedStream.listen((res) {
        emittedResult = res;
      });

      // 1. VEGLIA SERALE (45 min = 90 epoche): Movimento attivo, HR elevata
      for (int i = 0; i < 90; i++) {
        final ts = baseStartTime.add(Duration(seconds: i * 30));
        autoSleepDetector.ingestSample(
          ts,
          78.0, // HR serale
          enmo: 0.095, // Movimento > 0.080g
          rmssd: 45.0,
          respPower: 0.35,
          respRate: 17.0,
        );
      }
      expect(autoSleepDetector.state, isIn([AutoSleepState.idleAwake, AutoSleepState.sleepCandidateBuffering]));

      // 2. NOTTE DI SONNO (7.5 ore = 900 epoche): Fasi alternate
      // 2.1 Sonno Leggero iniziale (60 min = 120 epoche)
      for (int i = 90; i < 210; i++) {
        final ts = baseStartTime.add(Duration(seconds: i * 30));
        autoSleepDetector.ingestSample(
          ts,
          54.0,
          enmo: 0.004,
          rmssd: 58.0,
          respPower: 0.45,
          respRate: 15.0,
        );
      }
      expect(autoSleepDetector.state, equals(AutoSleepState.sleepInProgress));
      expect(autoSleepDetector.activeSleepStart, isNotNull);

      // 2.2 Primo Ciclo Sonno Profondo / SWS (60 min = 120 epoche): HR 50, HRV 74
      for (int i = 210; i < 330; i++) {
        final ts = baseStartTime.add(Duration(seconds: i * 30));
        autoSleepDetector.ingestSample(
          ts,
          50.0,
          enmo: 0.001,
          rmssd: 74.0,
          respPower: 0.85,
          respRate: 13.8,
        );
      }

      // 2.3 Primo Ciclo Sonno REM (60 min = 120 epoche): Atonia, instabilità HR & HRV
      for (int i = 330; i < 450; i++) {
        final ts = baseStartTime.add(Duration(seconds: i * 30));
        autoSleepDetector.ingestSample(
          ts,
          56.0,
          enmo: 0.002,
          rmssd: 62.0,
          respPower: 0.50,
          respRate: 15.5,
          rmssdVar: 0.40,
          hrFluc: 8,
        );
      }

      // 2.4 Sonno Leggero Intermedio con breve risveglio WASO (60 min = 120 epoche)
      for (int i = 450; i < 570; i++) {
        final ts = baseStartTime.add(Duration(seconds: i * 30));
        final isWaso = (i >= 500 && i < 515);
        autoSleepDetector.ingestSample(
          ts,
          isWaso ? 74.0 : 53.0,
          enmo: isWaso ? 0.070 : 0.004,
          rmssd: isWaso ? 40.0 : 60.0,
          respPower: 0.45,
          respRate: 15.0,
        );
      }

      // 2.5 SECONDO ED ULTIMO CICLO SWS PRIMA DEL RISVEGLIO (60 min = 120 epoche):
      // Target Brevetto US9750415B2: HR = 47.0 bpm, HRV (rMSSD) = 86.0 ms
      for (int i = 570; i < 690; i++) {
        final ts = baseStartTime.add(Duration(seconds: i * 30));
        autoSleepDetector.ingestSample(
          ts,
          47.0, // FCR bersaglio dell'ultimo ciclo SWS
          enmo: 0.001,
          rmssd: 86.0, // VFC bersaglio dell'ultimo ciclo SWS
          respPower: 0.90,
          respRate: 13.5,
        );
      }

      // 2.6 Secondo Ciclo REM (60 min = 120 epoche)
      for (int i = 690; i < 810; i++) {
        final ts = baseStartTime.add(Duration(seconds: i * 30));
        autoSleepDetector.ingestSample(
          ts,
          57.0,
          enmo: 0.002,
          rmssd: 64.0,
          respPower: 0.50,
          respRate: 15.8,
          rmssdVar: 0.38,
          hrFluc: 7,
        );
      }

      // 2.7 Sonno Leggero Finale prima del risveglio (90 min = 180 epoche)
      for (int i = 810; i < 990; i++) {
        final ts = baseStartTime.add(Duration(seconds: i * 30));
        autoSleepDetector.ingestSample(
          ts,
          53.0,
          enmo: 0.003,
          rmssd: 61.0,
          respPower: 0.52,
          respRate: 14.8,
        );
      }

      // 3. RISVEGLIO MATTUTINO (45 min = 90 epoche): Movimento sostenuto ENMO > 0.080g & HR > FCR + 20 bpm
      for (int i = 990; i < 1080; i++) {
        final ts = baseStartTime.add(Duration(seconds: i * 30));
        autoSleepDetector.ingestSample(
          ts,
          85.0, // HR > 52 + 20
          enmo: 0.120, // ENMO > 0.080g
          rmssd: 40.0,
          respPower: 0.30,
          respRate: 18.5,
        );
      }

      // Attesa completamento elaborazione asincrona
      int waitMs = 0;
      while (emittedResult == null && waitMs < 2000) {
        await Future.delayed(const Duration(milliseconds: 50));
        waitMs += 50;
      }

      expect(emittedResult, isNotNull);
      final res = emittedResult!;

      // Verifiche Stadi del Sonno
      final double totalSleepMin = (res['total_sleep_min'] as num).toDouble();
      final double swsMin = (res['sws_min'] as num).toDouble();
      final double remMin = (res['rem_min'] as num).toDouble();
      final double lightMin = (res['light_min'] as num).toDouble();
      final double wasoMin = (res['waso_min'] as num).toDouble();

      expect(swsMin, greaterThan(0));
      expect(remMin, greaterThan(0));
      expect(lightMin, greaterThan(0));
      expect(wasoMin, greaterThanOrEqualTo(0));
      expect(totalSleepMin, equals(swsMin + remMin + lightMin));
      expect(totalSleepMin, greaterThan(350.0));

      // Verifica Estrazione VFC (HRV) ed FCR (RHR) dall'ULTIMO Ciclo SWS
      final double finalRhr = (res['resting_hr_bpm'] as num).toDouble();
      final double finalHrv = (res['hrv_rmssd_ms'] as num).toDouble();

      expect(finalRhr, equals(47.0));
      expect(finalHrv, equals(86.0));

      // Verifica Recovery Score & Prestazione Sonno %
      final double recScore = (res['recovery_score'] as num).toDouble();
      final double sleepPerf = (res['sleep_performance_pct'] as num).toDouble();

      expect(recScore, greaterThanOrEqualTo(1.0));
      expect(recScore, lessThanOrEqualTo(99.0));
      expect(sleepPerf, greaterThan(70.0));

      // Verifica Persistenza su SQLite
      final sonnoMap = await dbHelper.getSonnoByDate(dateIso);
      expect(sonnoMap, isNotNull);
      expect(sonnoMap!['data_iso'], equals(dateIso));
      expect(sonnoMap['durata_tot_min'], equals(totalSleepMin.round()));
      expect(sonnoMap['sonno_profondo_min'], equals(swsMin.round()));
      expect(sonnoMap['sonno_rem_min'], equals(remMin.round()));

      final cicloMap = await dbHelper.getCicloByDate(dateIso);
      expect(cicloMap, isNotNull);
      expect(cicloMap!['recovery_score'], equals(recScore));
      expect(cicloMap['hrv_notte'], equals(finalHrv));
      expect(cicloMap['rhr_notte'], equals(finalRhr));

      await sub.cancel();
      autoSleepDetector.dispose();
    });

    test('Automatic Sleep Boundary Detection on Unsegmented Telemetry Stream', () {
      final engine = OvernightSleepEngine();
      final List<Map<String, dynamic>> records = [];

      // 45 min veglia serale (90 campioni)
      for (int i = 0; i < 90; i++) {
        records.add({
          'motion_var': 0.08,
          'hr': 82.0,
          'rmssd': 40.0,
        });
      }

      // 450 min sonno (900 campioni)
      for (int i = 0; i < 900; i++) {
        records.add({
          'motion_var': 0.002,
          'hr': 51.0,
          'rmssd': 75.0,
        });
      }

      // 45 min risveglio mattutino (90 campioni)
      for (int i = 0; i < 90; i++) {
        records.add({
          'motion_var': 0.11,
          'hr': 86.0,
          'rmssd': 38.0,
        });
      }

      final boundaries = engine.detectSleepBoundaries(records, rhrBaseline: 52.0, daytimeMeanHr: 76.0);
      expect(boundaries['hasSleep'], isTrue);
      expect(boundaries['startIndex'], greaterThanOrEqualTo(80));
      expect(boundaries['startIndex'], lessThanOrEqualTo(100));
      expect(boundaries['endIndex'], greaterThanOrEqualTo(970));
      expect(boundaries['endIndex'], lessThanOrEqualTo(1000));
    });

    test('WhoopViewModel Reactive State Update on Auto-Sleep Event', () async {
      final dbHelper = DatabaseHelper();
      final now = DateTime.now();
      final dateIso = now.toIso8601String().substring(0, 10);

      // Prepopolamento tabelle
      await dbHelper.insertOrUpdateSonno({
        'data_iso': dateIso,
        'ora_inizio': now.subtract(const Duration(hours: 8)).toIso8601String(),
        'ora_fine': now.toIso8601String(),
        'durata_tot_min': 460,
        'sonno_profondo_min': 110,
        'sonno_rem_min': 115,
        'efficienza_pct': 94.0,
        'sleep_performance_pct': 96.0,
      });

      await dbHelper.upsertCicloFisiologico({
        'data_iso': dateIso,
        'recovery_score': 88.0,
        'hrv_notte': 82.0,
        'rhr_notte': 49.0,
      });

      final viewModel = WhoopViewModel();
      await viewModel.loadData(triggerAutoSync: false);

      expect(viewModel.ultimoCiclo, isNotNull);
      expect(viewModel.ultimoCiclo!.punteggioRecuperoPct, equals(88.0));
      expect(viewModel.ultimoCiclo!.vfcMs, equals(82.0));
      expect(viewModel.ultimoCiclo!.fcrBpm, equals(49));

      expect(viewModel.sonnoList, isNotEmpty);
      expect(viewModel.sonnoList.first.durataTotMin, equals(460));
      expect(viewModel.sonnoList.first.sonnoProfondoMin, equals(110));

      viewModel.dispose();
    });
  });
}
