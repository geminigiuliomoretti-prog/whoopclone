import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:whoop_clone/data/database/database_helper.dart';
import 'package:whoop_clone/data/services/overnight_sleep_engine.dart';
import 'package:whoop_clone/domain/analytics/whoop_analytics_engine.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    DatabaseHelper.isTestMode = true;
  });

  group('Stress Engine Verification (Daytime & Sleep Stress)', () {
    test('1. Live Stress Motion Gating: Accelerazione attenua lo stress durante attività motoria', () {
      const double hrElevated = 125.0; // Battiti elevati
      const double hrvLive = 30.0;     // HRV ridotta dallo sforzo
      const double hrRest = 55.0;

      // Scenario A: Persona immobile sul divano con tachicardia da panico/ansia (Acc = 1.0g)
      final stressResting = WhoopAnalyticsEngine.calculateStressScore(
        hrLive: hrElevated,
        hrRest: hrRest,
        hrvLiveMs: hrvLive,
        baselineHrvMean: 65.0,
        accMagnitude: 1.0, // Immobile
      );

      // Scenario B: Persona che cammina a passo svelto o corre (Acc = 1.8g)
      final stressMoving = WhoopAnalyticsEngine.calculateStressScore(
        hrLive: hrElevated,
        hrRest: hrRest,
        hrvLiveMs: hrvLive,
        baselineHrvMean: 65.0,
        accMagnitude: 1.8, // In movimento
      );

      // Lo stress con movimento DEVE essere significativamente inferiore a causa del motion gating
      expect(stressMoving, lessThan(stressResting));
      expect(stressResting, greaterThanOrEqualTo(2.0)); // Stress psichico elevato
      expect(stressMoving, lessThan(2.0)); // Attenuato per sforzo fisico
    });

    test('2. Fisiologia dello Stress Notturno: SWS profondo è calmo, WASO/Risveglio ha stress alto', () {
      const double rhrBaseline = 55.0;
      const double hrvBaseline = 70.0;

      // Epoca SWS (Frequenza cardiaca bassa, tono vagale alto)
      final swsStress = WhoopAnalyticsEngine.calculateStressScore(
        hrLive: 50.0,
        hrvLiveMs: 85.0,
        hrRest: rhrBaseline,
        baselineHrvMean: hrvBaseline,
        accMagnitude: 1.0,
      );

      // Epoca REM (Frequenza cardiaca variabile, lieve attivazione simpatica)
      final remStress = WhoopAnalyticsEngine.calculateStressScore(
        hrLive: 60.0,
        hrvLiveMs: 65.0,
        hrRest: rhrBaseline,
        baselineHrvMean: hrvBaseline,
        accMagnitude: 1.01,
      );

      // Epoca WASO / Risveglio notturno agitato (Frequenza elevata, HRV crollata, movimento)
      final wasoStress = WhoopAnalyticsEngine.calculateStressScore(
        hrLive: 85.0,
        hrvLiveMs: 25.0,
        hrRest: rhrBaseline,
        baselineHrvMean: hrvBaseline,
        accMagnitude: 1.05,
      );

      expect(swsStress, lessThan(1.0)); // Basso (< 1.0)
      expect(remStress, greaterThan(swsStress));
      expect(wasoStress, greaterThan(1.5)); // Moderato o Elevato
    });

    test('3. OvernightSleepEngine calcola e persiste sleep_stress e punti notturni su SQLite', () async {
      final db = DatabaseHelper();
      final engine = OvernightSleepEngine();
      const String dateIso = '2026-09-21';

      final startTs = DateTime.parse('${dateIso}T23:00:00Z');
      final endTs = DateTime.parse('2026-09-22T07:00:00Z');

      // Genera record sintetici di sonno (8 ore = 480 minuti = 960 epoche da 30s)
      final List<Map<String, dynamic>> syntheticRecords = [];
      for (int i = 0; i < 960; i++) {
        final epTime = startTs.add(Duration(seconds: i * 30));
        // Alternanza: prime 700 epoche calme (SWS/Light), ultime 260 con un po' di REM
        final isCalm = i < 700;
        syntheticRecords.add({
          'timestamp': epTime.toIso8601String(),
          'timestamp_utc_ms': epTime.millisecondsSinceEpoch,
          'bpm': isCalm ? 48 : 53,
          'rmssd': isCalm ? 92.0 : 72.0,
          'rr_ms': isCalm ? 92.0 : 72.0,
          'motion_var': 0.001,
          'skin_temp_celsius': 34.5,
          'spo2_pct': 97.5,
          'resp_rate': 14.2,
          'resp_power': 0.85,
        });
      }

      final result = await engine.processNightlyTelemetry(
        rawTelemetryRecords: syntheticRecords,
        windowStart: startTs,
        windowEnd: endTs,
        userBaseline30d: {
          'rhr_mean': 54.0,
          'rmssd_mean': 70.0,
          'sleep_need_min': 480,
        },
        targetDateIso: dateIso,
      );

      expect(result['has_data'], isTrue);
      expect(result['sleep_stress'], isNotNull);
      final double sleepStress = result['sleep_stress'] as double;
      expect(sleepStress, greaterThan(0.0));
      expect(sleepStress, lessThan(1.0)); // Sonno prevalentemente calmo/basso stress

      expect(result['sleep_stress_basso_min'], isNotNull);
      expect(result['sleep_stress_basso_min'], greaterThan(300.0)); // Almeno 5 ore in stress basso

      // Verifica scrittura su SQLite cicli_fisiologici
      final ciclo = await db.getCicloByDate(dateIso);
      expect(ciclo, isNotNull);
      expect(ciclo!['valore_stress_notte'], isNotNull);
      expect(ciclo['valore_stress_notte'], equals(sleepStress));

      // Verifica persistenza punti orari/periodici su misurazioni_stress
      final stressRows = await db.getMisurazioniStressByDate(dateIso);
      expect(stressRows, isNotEmpty);
      expect(stressRows.length, greaterThanOrEqualTo(50));
    });

    test('4. Zero-Mock Policy: Se mancano i dati biometrici, sleep_stress è rigorosamente null', () async {
      final engine = OvernightSleepEngine();
      const String dateIso = '2026-09-20';

      final startTs = DateTime.parse('${dateIso}T23:00:00Z');
      final endTs = DateTime.parse('2026-09-21T07:00:00Z');

      // Nessun record di telemetria (solo orario manuale)
      final result = await engine.processNightlyTelemetry(
        rawTelemetryRecords: [],
        windowStart: startTs,
        windowEnd: endTs,
        userBaseline30d: {
          'rhr_mean': 55.0,
          'rmssd_mean': 65.0,
          'sleep_need_min': 480,
        },
        targetDateIso: dateIso,
      );

      expect(result['has_data'], isTrue);
      expect(result['manual_no_ble'], isTrue);
      expect(result['sleep_stress'], isNull);
      expect(result['sleep_stress_basso_min'], isNull);
      expect(result['recovery_score'], isNull);
    });
  });
}
