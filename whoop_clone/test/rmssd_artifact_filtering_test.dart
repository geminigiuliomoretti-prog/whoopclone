import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:whoop_clone/data/database/database_helper.dart';
import 'package:whoop_clone/data/services/overnight_sleep_engine.dart';
import 'package:whoop_clone/data/services/insight_engine.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    DatabaseHelper.isTestMode = true;
  });

  tearDown(() async {
    await DatabaseHelper().clearAllTables();
  });

  group('RMSSD Artifact Filtering & Recovery Normalization Tests', () {
    test('Spike anomali a 250ms ed ectopici vengono scartati e non generano Recovery al 99%', () async {
      final engine = OvernightSleepEngine();
      final List<Map<String, dynamic>> records = [];

      // 1. Inserisci 30 minuti di Veglia rumorosa
      for (int i = 0; i < 60; i++) {
        records.add({
          'motion_var': 0.05,
          'hr': 80.0,
          'rmssd': 35.0,
          'resp_power': 0.3,
          'resp_rate': 18.0,
        });
      }

      // 2. Inserisci 60 minuti di SWS contenente artefatti da movimento con salti a 250ms (>200ms jump)
      for (int i = 0; i < 120; i++) {
        // Intervalli normali a 1000ms (~60bpm) con spike anomalo a 250ms e salti ectopici
        final ppWithArtifacts = [1.00, 1.05, 0.25, 1.55, 1.02, 1.04, 1.01];

        records.add({
          'motion_var': 0.002, // Quiete SWS
          'hr': 55.0,
          'rmssd': 250.0, // Spike raw anomalo inserito erroneamente
          'resp_power': 0.85,
          'resp_rate': 14.0,
          'pp_intervals': ppWithArtifacts,
        });
      }

      // 3. Esegui la pipeline con baseline 65 ms
      final result = await engine.processNightlyTelemetry(
        rawTelemetryRecords: records,
        userBaseline30d: {
          'rhr_mean': 55.0,
          'rmssd_mean': 65.0,
          'rmssd_std': 12.0,
          'baseline_temp_celsius': 36.5,
          'sleep_need_min': 480,
        },
      );

      final double? extractedHrv = result['hrv_rmssd_ms'];
      final double? recovery = result['recovery_score'];

      expect(extractedHrv, isNotNull);
      // Il valore deve essere rigorosamente clampato/filtrato entro il range fisiologico [20.0, 140.0]
      expect(extractedHrv!, lessThanOrEqualTo(140.0));
      expect(extractedHrv, isNot(equals(250.0)));

      // Il recovery score NON deve essere al 99% a causa di un falso spike HRV
      expect(recovery, isNotNull);
      expect(recovery!, lessThan(95.0));
    });

    test('Se il sonno è assente o 0 min, sleepPerformancePct è null', () async {
      final engine = OvernightSleepEngine();
      final result = await engine.processNightlyTelemetry(
        rawTelemetryRecords: [],
        userBaseline30d: {
          'rhr_mean': 55.0,
          'rmssd_mean': 65.0,
          'rmssd_std': 12.0,
          'baseline_temp_celsius': 36.5,
          'sleep_need_min': 480,
        },
      );

      expect(result['has_data'], isFalse);
      expect(result['recovery_score'], isNull);
      expect(result['sleep_performance_pct'], isNull);
      expect(result['total_sleep_min'], isNull);
    });

    test('InsightEngine calcola la percentuale reale di scostamento VFC', () {
      final insightPlus = InsightEngine.generateHrvInsight(
        hrvSws: 76.0,
        hrvBaseline: 72.0,
      );
      expect(insightPlus, contains('6%'));
      expect(insightPlus, contains('superiore'));

      final insightMinus = InsightEngine.generateHrvInsight(
        hrvSws: 60.0,
        hrvBaseline: 75.0,
      );
      expect(insightMinus, contains('20%'));
      expect(insightMinus, contains('inferiore'));

      final insightNull = InsightEngine.generateHrvInsight(
        hrvSws: null,
        hrvBaseline: 72.0,
      );
      expect(insightNull, contains('insufficienti'));
    });
  });
}
