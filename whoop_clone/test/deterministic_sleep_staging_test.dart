import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:whoop_clone/data/database/database_helper.dart';
import 'package:whoop_clone/data/services/overnight_sleep_engine.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    DatabaseHelper.isTestMode = true;
  });

  group('Multi-Feature Deterministic Sleep Staging Engine & Temporal Smoothing Tests', () {
    test('1. Classificazione Deterministica Epoca (classifyEpoch)', () {
      const int totalEpochs = 960; // 8 ore

      // 1.1 Regola VEGLIA (WASO): ENMO > 0.040 o hrRatio > 1.25
      final wake1 = classifyEpoch(
        enmo: 0.055,
        hrRatio: 1.0,
        hrvNorm: 1.0,
        respVar: 0.10,
        epochIndex: 200,
        totalEpochs: totalEpochs,
      );
      expect(wake1, equals(SleepStage.wake));

      final wake2 = classifyEpoch(
        enmo: 0.005,
        hrRatio: 1.30,
        hrvNorm: 1.0,
        respVar: 0.10,
        epochIndex: 200,
        totalEpochs: totalEpochs,
      );
      expect(wake2, equals(SleepStage.wake));

      // 1.2 Regola SONNO PROFONDO (SWS): ENMO < 0.008, hrRatio <= 1.05, respVar < 0.35, prima del 70% della notte
      final deepSws = classifyEpoch(
        enmo: 0.003,
        hrRatio: 0.95,
        hrvNorm: 1.0,
        respVar: 0.12,
        epochIndex: 200, // < 960 * 0.70 = 672
        totalEpochs: totalEpochs,
      );
      expect(deepSws, equals(SleepStage.deepSws));

      // SWS candidato nella parte finale della notte (>70%) diventa Light Sleep
      final lateDeep = classifyEpoch(
        enmo: 0.003,
        hrRatio: 0.95,
        hrvNorm: 1.0,
        respVar: 0.12,
        epochIndex: 800, // > 672
        totalEpochs: totalEpochs,
      );
      expect(lateDeep, equals(SleepStage.light));

      // 1.3 Regola SONNO REM: ENMO < 0.010, hrvNorm > 1.20, hrRatio > 0.95, dopo i primi 60 min (120 epoche)
      final rem = classifyEpoch(
        enmo: 0.004,
        hrRatio: 1.02,
        hrvNorm: 1.35,
        respVar: 0.25,
        epochIndex: 300, // > 120
        totalEpochs: totalEpochs,
      );
      expect(rem, equals(SleepStage.rem));

      // REM candidato nei primi 60 minuti (<120 epoche) è inibito e diventa Light Sleep
      final earlyRem = classifyEpoch(
        enmo: 0.004,
        hrRatio: 1.02,
        hrvNorm: 1.35,
        respVar: 0.25,
        epochIndex: 50, // < 120
        totalEpochs: totalEpochs,
      );
      expect(earlyRem, equals(SleepStage.light));

      // 1.4 Stato Base: Sonno Leggero (Light Sleep)
      final light = classifyEpoch(
        enmo: 0.015,
        hrRatio: 1.08,
        hrvNorm: 0.95,
        respVar: 0.30,
        epochIndex: 200,
        totalEpochs: totalEpochs,
      );
      expect(light, equals(SleepStage.light));
    });

    test('2. Filtro di Smoothing Temporale rimuove flickering isolato a singola epoca', () async {
      final engine = OvernightSleepEngine();
      final now = DateTime.now();

      // Crea sequenza con un'epoca anomala isolata: LIGHT, LIGHT, SWS (isolata), LIGHT, LIGHT
      final List<Map<String, dynamic>> records = [];
      for (int i = 0; i < 5; i++) {
        final isIsolated = (i == 2);
        records.add({
          'timestamp': now.add(Duration(seconds: i * 30)),
          'hr': isIsolated ? 48.0 : 60.0,
          'bpm': isIsolated ? 48 : 60,
          'motion_var': isIsolated ? 0.002 : 0.015,
          'enmo': isIsolated ? 0.002 : 0.015,
          'rmssd': 65.0,
          'resp_power': isIsolated ? 0.85 : 0.40,
        });
      }

      final result = await engine.processNightlyTelemetry(
        rawTelemetryRecords: records,
        userBaseline30d: {
          'rhr_mean': 55.0,
          'rmssd_mean': 65.0,
          'sleep_need_min': 480.0,
        },
        windowStart: now,
        windowEnd: now.add(const Duration(seconds: 150)),
      );

      final hypnogram = List<String>.from(result['hypnogram']);
      expect(hypnogram.length, equals(5));
      // L'epoca isolata al centro deve essere stata uniformata a LIGHT grazie allo smoothing
      expect(hypnogram[2], equals('LIGHT'));
    });
  });
}
