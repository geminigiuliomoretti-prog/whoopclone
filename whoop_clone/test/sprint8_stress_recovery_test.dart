import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:whoop_clone/data/database/database_helper.dart';
import 'package:whoop_clone/data/biometrics/stress_monitor_engine.dart';
import 'package:whoop_clone/data/biometrics/recovery_engine.dart';
import 'package:whoop_clone/data/engine/whoop_analytics_engine.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    DatabaseHelper.isTestMode = true;
  });

  group('Sprint 8 — On-Demand Stress Spot-Check & Integrated Recovery Tests', () {
    test('1. Spot-Check 60s: Calcolo Baevsky SI & Scrittura su SQLite misurazioni_stress', () async {
      final db = DatabaseHelper();
      final dataIso = '2026-08-09';

      // Calcolo Baevsky SI per battito a riposo (BPM = 60, Mo = 1.0s, AMo = 40%, MxDM = 0.20s)
      final rawSi = StressMonitorEngine.calculateBaevskyStressIndex(
        aMoPct: 40.0,
        moSec: 1.0,
        mxDmSec: 0.20,
      );

      expect(rawSi, greaterThanOrEqualTo(0.0));
      expect(rawSi, lessThanOrEqualTo(3.0));

      final id = await db.insertMisurazioneStress(dataIso, rawSi, 65.0, 60);
      expect(id, greaterThan(0));

      final rows = await db.getMisurazioniStressByDate(dataIso);
      expect(rows.length, greaterThanOrEqualTo(1));
      expect(rows.last['valore_stress'], equals(rawSi));
      expect(rows.last['hrv_ms'], equals(65.0));
    });

    test('2. Equazione Recovery Integrata: Stress Notturno elevato (2.2) riduce il Recovery rispetto a Stress basso (0.4)', () {
      final lowStressRecovery = WhoopAnalyticsEngine.calculateRecoveryScorePct(
        currentHrvMs: 65.0,
        baselineHrvMean: 65.0,
        baselineHrvStd: 15.0,
        currentRhrBpm: 55.0,
        baselineRhrMean: 55.0,
        baselineRhrStd: 3.5,
        sleepPerformancePct: 85.0,
        nightlyStress: 0.4, // Stress notturno basso
      );

      final highStressRecovery = WhoopAnalyticsEngine.calculateRecoveryScorePct(
        currentHrvMs: 65.0,
        baselineHrvMean: 65.0,
        baselineHrvStd: 15.0,
        currentRhrBpm: 55.0,
        baselineRhrMean: 55.0,
        baselineRhrStd: 3.5,
        sleepPerformancePct: 85.0,
        nightlyStress: 2.2, // Stress notturno elevato
      );

      expect(highStressRecovery, lessThan(lowStressRecovery));
      expect(lowStressRecovery - highStressRecovery, greaterThanOrEqualTo(15.0));
    });

    test('3. Recovery Engine Direct: Penalità Vitals Fuori Norma (-5%) per Temperatura Cutanea alterata (+1.5°C)', () {
      final normalRecovery = RecoveryEngine.calculateRecoveryScore(
        currentRmssdMs: 65.0,
        historicalLnRmssd: [4.17, 4.17, 4.17, 4.17],
        currentFcrBpm: 55.0,
        historicalRhr: [55.0, 55.0, 55.0, 55.0],
        skinTempDeltaC: 0.0,
      );

      final feverRecovery = RecoveryEngine.calculateRecoveryScore(
        currentRmssdMs: 65.0,
        historicalLnRmssd: [4.17, 4.17, 4.17, 4.17],
        currentFcrBpm: 55.0,
        historicalRhr: [55.0, 55.0, 55.0, 55.0],
        skinTempDeltaC: 1.5, // Alterazione > +-1.2 °C
      );

      expect(feverRecovery, equals(normalRecovery! - 5.0));
    });
  });
}
