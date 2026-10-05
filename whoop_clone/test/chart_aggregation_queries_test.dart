import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:whoop_clone/data/database/database_helper.dart';
import 'package:whoop_clone/data/services/overnight_sleep_engine.dart';
import 'package:whoop_clone/views/widgets/charts/hypnogram_chart.dart';
import 'package:whoop_clone/views/widgets/charts/intraday_hr_chart.dart';
import 'package:whoop_clone/views/widgets/charts/heart_rate_zones_chart.dart';
import 'package:whoop_clone/views/widgets/charts/sparkline_14d.dart';

void main() {
  late DatabaseHelper dbHelper;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    DatabaseHelper.isTestMode = true;
    dbHelper = DatabaseHelper();
  });

  setUp(() async {
    await dbHelper.clearAllTables();
  });

  group('CHT-02: SQL Aggregation Queries Tests', () {
    test('1. Aggregazione SQL a bucket di 1 minuto (getIntradayHrBuckets)', () async {
      // Inizio finestra temporale a ore tonde
      final start = DateTime.utc(2026, 10, 5, 10, 0, 0);
      final end = DateTime.utc(2026, 10, 5, 10, 2, 0); // 2 minuti: bucket 0 e bucket 1

      // Minuto 0: 3 campioni (60, 70, 80 bpm) -> min: 60, avg: 70, max: 80, count: 3
      await dbHelper.insertTelemetriaPoint(
        bpm: 60,
        timestamp: start.add(const Duration(seconds: 10)),
      );
      await dbHelper.insertTelemetriaPoint(
        bpm: 70,
        timestamp: start.add(const Duration(seconds: 25)),
      );
      await dbHelper.insertTelemetriaPoint(
        bpm: 80,
        timestamp: start.add(const Duration(seconds: 50)),
      );

      // Minuto 1: 3 campioni (90, 100, 110 bpm) -> min: 90, avg: 100, max: 110, count: 3
      await dbHelper.insertTelemetriaPoint(
        bpm: 90,
        timestamp: start.add(const Duration(seconds: 70)),
      );
      await dbHelper.insertTelemetriaPoint(
        bpm: 100,
        timestamp: start.add(const Duration(seconds: 85)),
      );
      await dbHelper.insertTelemetriaPoint(
        bpm: 110,
        timestamp: start.add(const Duration(seconds: 110)),
      );

      final buckets = await dbHelper.getIntradayHrBuckets(start, end, bucketMinutes: 1);

      expect(buckets.length, greaterThanOrEqualTo(2));

      // Bucket minuto 0
      final b0 = buckets[0];
      expect(b0, isNotNull);
      expect(b0!['min'], equals(60));
      expect(b0['avg'], equals(70));
      expect(b0['max'], equals(80));
      expect(b0['count'], equals(3));

      // Bucket minuto 1
      final b1 = buckets[1];
      expect(b1, isNotNull);
      expect(b1!['min'], equals(90));
      expect(b1['avg'], equals(100));
      expect(b1['max'], equals(110));
      expect(b1['count'], equals(3));
    });

    test('2. Rilevamento buchi nei bucket (restituisce esplicitamente null per gap reali)', () async {
      final start = DateTime.utc(2026, 10, 5, 12, 0, 0);
      final end = DateTime.utc(2026, 10, 5, 12, 5, 0); // 5 minuti (indici 0, 1, 2, 3, 4, 5)

      // Dati presenti solo al minuto 0 e al minuto 4
      await dbHelper.insertTelemetriaPoint(
        bpm: 65,
        timestamp: start.add(const Duration(seconds: 15)),
      );
      await dbHelper.insertTelemetriaPoint(
        bpm: 130,
        timestamp: start.add(const Duration(minutes: 4, seconds: 20)),
      );

      final buckets = await dbHelper.getIntradayHrBuckets(start, end, bucketMinutes: 1);

      expect(buckets.length, equals(6));

      // Minuto 0 ha dati
      expect(buckets[0], isNotNull);
      expect(buckets[0]!['avg'], equals(65));

      // Minuti 1, 2, 3 sono buchi reali -> devono essere null
      expect(buckets[1], isNull);
      expect(buckets[2], isNull);
      expect(buckets[3], isNull);

      // Minuto 4 ha dati
      expect(buckets[4], isNotNull);
      expect(buckets[4]!['avg'], equals(130));

      // Minuto 5 non ha dati -> null
      expect(buckets[5], isNull);
    });

    test('3. Calcolo Distribuzione 5 Zone Cardiache SQL (getHrZoneDistribution)', () async {
      final start = DateTime.utc(2026, 10, 5, 8, 0, 0);
      final end = DateTime.utc(2026, 10, 5, 9, 0, 0);
      const double maxHr = 200.0;
      // Z1: 100-119, Z2: 120-139, Z3: 140-159, Z4: 160-179, Z5: >=180

      // Inserimento 10 campioni distribuiti
      await dbHelper.insertTelemetriaPoint(bpm: 105, timestamp: start.add(const Duration(minutes: 1))); // Z1
      await dbHelper.insertTelemetriaPoint(bpm: 125, timestamp: start.add(const Duration(minutes: 2))); // Z2
      await dbHelper.insertTelemetriaPoint(bpm: 130, timestamp: start.add(const Duration(minutes: 3))); // Z2
      await dbHelper.insertTelemetriaPoint(bpm: 145, timestamp: start.add(const Duration(minutes: 4))); // Z3
      await dbHelper.insertTelemetriaPoint(bpm: 150, timestamp: start.add(const Duration(minutes: 5))); // Z3
      await dbHelper.insertTelemetriaPoint(bpm: 155, timestamp: start.add(const Duration(minutes: 6))); // Z3
      await dbHelper.insertTelemetriaPoint(bpm: 165, timestamp: start.add(const Duration(minutes: 7))); // Z4
      await dbHelper.insertTelemetriaPoint(bpm: 170, timestamp: start.add(const Duration(minutes: 8))); // Z4
      await dbHelper.insertTelemetriaPoint(bpm: 185, timestamp: start.add(const Duration(minutes: 9))); // Z5
      await dbHelper.insertTelemetriaPoint(bpm: 190, timestamp: start.add(const Duration(minutes: 10))); // Z5

      final dist = await dbHelper.getHrZoneDistribution(start, end, maxHr);

      expect(dist['total_samples'], equals(10));
      expect(dist['z1_seconds'], equals(1));
      expect(dist['z2_seconds'], equals(2));
      expect(dist['z3_seconds'], equals(3));
      expect(dist['z4_seconds'], equals(2));
      expect(dist['z5_seconds'], equals(2));

      expect(dist['z1_pct'], equals(10.0));
      expect(dist['z2_pct'], equals(20.0));
      expect(dist['z3_pct'], equals(30.0));
      expect(dist['z4_pct'], equals(20.0));
      expect(dist['z5_pct'], equals(20.0));
    });
  });

  group('STG-07: Hypnogram Persistence and Recovery Tests', () {
    test('1. Raggruppamento Epoche 30s in Segmenti (buildSegmentsFromEpochs)', () {
      final now = DateTime.utc(2026, 10, 5, 23, 0, 0);

      // Creazione di 10 epoche: 4 SWS, 2 MISSING, 4 REM
      final epochs = <Epoch30s>[
        Epoch30s(index: 0, timestamp: now, motionVar: 0, hr: 50, rmssd: 80, respPower: 0, respRate: 14, rmssdVarInWindow: 0, hrFluctuations: 0, ppIntervals: [], stage: 'SWS'),
        Epoch30s(index: 1, timestamp: now.add(const Duration(seconds: 30)), motionVar: 0, hr: 50, rmssd: 80, respPower: 0, respRate: 14, rmssdVarInWindow: 0, hrFluctuations: 0, ppIntervals: [], stage: 'SWS'),
        Epoch30s(index: 2, timestamp: now.add(const Duration(seconds: 60)), motionVar: 0, hr: 50, rmssd: 80, respPower: 0, respRate: 14, rmssdVarInWindow: 0, hrFluctuations: 0, ppIntervals: [], stage: 'SWS'),
        Epoch30s(index: 3, timestamp: now.add(const Duration(seconds: 90)), motionVar: 0, hr: 50, rmssd: 80, respPower: 0, respRate: 14, rmssdVarInWindow: 0, hrFluctuations: 0, ppIntervals: [], stage: 'SWS'),
        // Gap MISSING
        Epoch30s(index: 4, timestamp: now.add(const Duration(seconds: 120)), motionVar: 0, hr: 50, rmssd: 80, respPower: 0, respRate: 14, rmssdVarInWindow: 0, hrFluctuations: 0, ppIntervals: [], stage: 'MISSING', quality: EpochQuality.missing),
        Epoch30s(index: 5, timestamp: now.add(const Duration(seconds: 150)), motionVar: 0, hr: 50, rmssd: 80, respPower: 0, respRate: 14, rmssdVarInWindow: 0, hrFluctuations: 0, ppIntervals: [], stage: 'MISSING', quality: EpochQuality.missing),
        // REM
        Epoch30s(index: 6, timestamp: now.add(const Duration(seconds: 180)), motionVar: 0, hr: 65, rmssd: 90, respPower: 0, respRate: 16, rmssdVarInWindow: 0, hrFluctuations: 0, ppIntervals: [], stage: 'REM'),
        Epoch30s(index: 7, timestamp: now.add(const Duration(seconds: 210)), motionVar: 0, hr: 65, rmssd: 90, respPower: 0, respRate: 16, rmssdVarInWindow: 0, hrFluctuations: 0, ppIntervals: [], stage: 'REM'),
        Epoch30s(index: 8, timestamp: now.add(const Duration(seconds: 240)), motionVar: 0, hr: 65, rmssd: 90, respPower: 0, respRate: 16, rmssdVarInWindow: 0, hrFluctuations: 0, ppIntervals: [], stage: 'REM'),
        Epoch30s(index: 9, timestamp: now.add(const Duration(seconds: 270)), motionVar: 0, hr: 65, rmssd: 90, respPower: 0, respRate: 16, rmssdVarInWindow: 0, hrFluctuations: 0, ppIntervals: [], stage: 'REM'),
      ];

      final segments = OvernightSleepEngine.buildSegmentsFromEpochs(epochs);

      expect(segments.length, equals(3));

      // Segmento 1: SWS (4 epoche x 30s = 120s)
      expect(segments[0]['stage'], equals('SWS'));
      expect(segments[0]['end_utc_ms'] - segments[0]['start_utc_ms'], equals(120000));
      expect(segments[0]['confidence'], equals(1.0));

      // Segmento 2: MISSING (2 epoche x 30s = 60s)
      expect(segments[1]['stage'], equals('MISSING'));
      expect(segments[1]['end_utc_ms'] - segments[1]['start_utc_ms'], equals(60000));
      expect(segments[1]['confidence'], equals(0.0));

      // Segmento 3: REM (4 epoche x 30s = 120s)
      expect(segments[2]['stage'], equals('REM'));
      expect(segments[2]['end_utc_ms'] - segments[2]['start_utc_ms'], equals(120000));
      expect(segments[2]['confidence'], equals(1.0));
    });

    test('2. Persistenza e Recupero dei Segmenti Ipnogramma su SQLite', () async {
      const dateIso = '2026-10-05';
      final sonnoId = await dbHelper.insertOrUpdateSonno({
        'data_iso': dateIso,
        'ora_inizio': '2026-10-05T23:00:00Z',
        'ora_fine': '2026-10-06T07:00:00Z',
        'durata_tot_min': 480,
        'sonno_profondo_min': 90,
        'sonno_rem_min': 90,
        'efficienza_pct': 92.5,
        'sleep_performance_pct': 95.0,
      });

      final startMs = DateTime.utc(2026, 10, 5, 23, 0).millisecondsSinceEpoch;
      final segmentsToInsert = [
        {
          'start_utc_ms': startMs,
          'end_utc_ms': startMs + 3600000,
          'stage': 'LIGHT',
          'confidence': 1.0,
        },
        {
          'start_utc_ms': startMs + 3600000,
          'end_utc_ms': startMs + 7200000,
          'stage': 'SWS',
          'confidence': 1.0,
        },
        {
          'start_utc_ms': startMs + 7200000,
          'end_utc_ms': startMs + 7800000,
          'stage': 'MISSING',
          'confidence': 0.0,
        },
        {
          'start_utc_ms': startMs + 7800000,
          'end_utc_ms': startMs + 10800000,
          'stage': 'REM',
          'confidence': 0.95,
        },
        {
          'start_utc_ms': startMs + 10800000,
          'end_utc_ms': startMs + 12000000,
          'stage': 'WAKE',
          'confidence': 1.0,
        },
      ];

      await dbHelper.insertSleepStageSegments(sonnoId, segmentsToInsert);

      final loaded = await dbHelper.getHypnogramSegments(dateIso);

      expect(loaded.length, equals(5));
      expect(loaded[0]['stage'], equals('LIGHT'));
      expect(loaded[1]['stage'], equals('SWS'));
      expect(loaded[2]['stage'], equals('MISSING'));
      expect(loaded[3]['stage'], equals('REM'));
      expect(loaded[4]['stage'], equals('WAKE'));
      expect(loaded[2]['confidence'], equals(0.0));
    });

    test('3. OvernightSleepEngine salva automaticamente i segmenti al termine del calcolo', () async {
      final engine = OvernightSleepEngine();
      final now = DateTime.utc(2026, 10, 5, 22, 0, 0);

      // Crea campioni sintetici per generare una notte valida
      final records = <Map<String, dynamic>>[];
      for (int i = 0; i < 400; i++) {
        records.add({
          'timestamp': now.add(Duration(seconds: i * 30)).toIso8601String(),
          'timestamp_utc_ms': now.add(Duration(seconds: i * 30)).millisecondsSinceEpoch,
          'bpm': 55,
          'hr': 55.0,
          'enmo': 0.003,
          'motion_var': 0.003,
          'rmssd': 65.0,
          'hrv_ms': 65.0,
          'resp_rate': 14.0,
          'resp_power': 0.25,
        });
      }

      final result = await engine.processNightlyTelemetry(
        rawTelemetryRecords: records,
        targetDateIso: '2026-10-05',
        userBaseline30d: {
          'rhr_mean': 55.0,
          'rmssd_mean': 65.0,
          'rmssd_std': 15.0,
          'baseline_temp_celsius': 36.5,
        },
      );

      expect(result['has_data'], isTrue);

      final segments = await dbHelper.getHypnogramSegments('2026-10-05');
      expect(segments, isNotEmpty);
      expect(segments.first['stage'], isNotNull);
      expect(segments.first['start_utc_ms'], isNotNull);
    });
  });

  group('CHT-03: Explicit Chart States Tests', () {
    testWidgets('1. HypnogramChart - 4 Stati (Loading, Empty, Partial, Complete)', (WidgetTester tester) async {
      // 1.1 Loading state
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: HypnogramChart(blocks: [], isLoading: true),
          ),
        ),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // 1.2 Empty state
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: HypnogramChart(blocks: [], isLoading: false),
          ),
        ),
      );
      expect(find.text('Nessun dato registrato per questa finestra temporale'), findsOneWidget);

      // 1.3 Partial state (contiene segmenti MISSING)
      final t0 = DateTime(2026, 10, 5, 23, 0);
      final partialBlocks = [
        HypnogramBlock(startTime: t0, endTime: t0.add(const Duration(minutes: 60)), stage: 'light', durationMinutes: 60),
        HypnogramBlock(startTime: t0.add(const Duration(minutes: 60)), endTime: t0.add(const Duration(minutes: 75)), stage: 'missing', durationMinutes: 15),
        HypnogramBlock(startTime: t0.add(const Duration(minutes: 75)), endTime: t0.add(const Duration(minutes: 180)), stage: 'sws', durationMinutes: 105),
      ];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HypnogramChart(blocks: partialBlocks, isLoading: false),
          ),
        ),
      );
      expect(find.text('Dati parziali: rilevate interruzioni nel tracciato notturno'), findsOneWidget);
      expect(find.text('Interruzione'), findsOneWidget);

      // 1.4 Complete state
      final completeBlocks = [
        HypnogramBlock(startTime: t0, endTime: t0.add(const Duration(minutes: 60)), stage: 'light', durationMinutes: 60),
        HypnogramBlock(startTime: t0.add(const Duration(minutes: 60)), endTime: t0.add(const Duration(minutes: 180)), stage: 'sws', durationMinutes: 120),
      ];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HypnogramChart(blocks: completeBlocks, isLoading: false),
          ),
        ),
      );
      expect(find.text('Dati parziali: rilevate interruzioni nel tracciato notturno'), findsNothing);
      expect(find.text('VEGLIA'), findsOneWidget);
    });

    testWidgets('2. IntradayHrChart - 4 Stati e spezzamento linee buchi > 5 min', (WidgetTester tester) async {
      // 2.1 Loading state
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: IntradayHrChart(points: [], isLoading: true),
          ),
        ),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // 2.2 Empty state
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: IntradayHrChart(points: [], isLoading: false),
          ),
        ),
      );
      expect(find.text('Nessun dato registrato per questa finestra temporale'), findsOneWidget);

      // 2.3 Partial state con buco > 5 minuti
      final t0 = DateTime(2026, 10, 5, 10, 0);
      final gapPoints = [
        HrDataPoint(timestamp: t0, bpm: 60),
        HrDataPoint(timestamp: t0.add(const Duration(minutes: 1)), bpm: 65),
        // Gap di 15 minuti!
        HrDataPoint(timestamp: t0.add(const Duration(minutes: 16)), bpm: 75),
        HrDataPoint(timestamp: t0.add(const Duration(minutes: 17)), bpm: 80),
      ];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: IntradayHrChart(points: gapPoints, isLoading: false),
          ),
        ),
      );
      expect(find.text('Dati parziali: rilevate interruzioni nel segnale (> 5 min)'), findsOneWidget);
      expect(find.text('MIN: '), findsOneWidget);
      expect(find.text('60 BPM'), findsOneWidget);
      expect(find.text('MAX: '), findsOneWidget);
      expect(find.text('80 BPM'), findsOneWidget);

      // 2.4 Complete state (senza buchi > 5 min)
      final continuousPoints = [
        HrDataPoint(timestamp: t0, bpm: 60),
        HrDataPoint(timestamp: t0.add(const Duration(minutes: 1)), bpm: 65),
        HrDataPoint(timestamp: t0.add(const Duration(minutes: 2)), bpm: 70),
      ];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: IntradayHrChart(points: continuousPoints, isLoading: false),
          ),
        ),
      );
      expect(find.text('Dati parziali: rilevate interruzioni nel segnale (> 5 min)'), findsNothing);
    });

    testWidgets('3. HeartRateZonesChart - Loading ed Empty state', (WidgetTester tester) async {
      // 3.1 Loading
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: HeartRateZonesChart(zones: [], totalDurationSeconds: 0, isLoading: true),
          ),
        ),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // 3.2 Empty
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: HeartRateZonesChart(zones: [], totalDurationSeconds: 0, isLoading: false),
          ),
        ),
      );
      expect(find.text('Nessun dato registrato per questa finestra temporale'), findsOneWidget);
    });

    testWidgets('4. Sparkline14d - Loading ed Empty state', (WidgetTester tester) async {
      // 4.1 Loading
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Sparkline14d(dataPoints: [], isLoading: true),
          ),
        ),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // 4.2 Empty
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Sparkline14d(dataPoints: [null, null, null], isLoading: false),
          ),
        ),
      );
      expect(find.text('--'), findsOneWidget);
    });
  });
}
