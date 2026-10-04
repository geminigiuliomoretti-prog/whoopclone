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

  tearDown(() async {
    await DatabaseHelper().clearAllTables();
  });

  test('SWS-Windowed HRV & RHR Extraction Test', () async {
    final engine = OvernightSleepEngine();
    final List<Map<String, dynamic>> records = [];

    // 1. Inserisci 30 minuti di Veglia / Sonno Leggero rumoroso (HR = 85 bpm, rMSSD = 35 ms)
    for (int i = 0; i < 60; i++) {
      records.add({
        'motion_var': 0.06,
        'hr': 85.0,
        'rmssd': 35.0,
        'resp_power': 0.3,
        'resp_rate': 18.0,
        'rmssd_var': 0.4,
        'hr_fluc': 12,
      });
    }

    // 2. Inserisci 60 minuti di SWS (Sonno Profondo) puro (HR = 50 bpm, rMSSD = 76 ms)
    for (int i = 0; i < 120; i++) {
      records.add({
        'motion_var': 0.001,
        'hr': 50.0,
        'rmssd': 76.0,
        'resp_power': 0.8,
        'resp_rate': 14.0,
        'rmssd_var': 0.05,
        'hr_fluc': 1,
      });
    }

    // 3. Inserisci altri 30 minuti di Sonno Leggero (HR = 68 bpm, rMSSD = 48 ms)
    for (int i = 0; i < 60; i++) {
      records.add({
        'motion_var': 0.004,
        'hr': 68.0,
        'rmssd': 48.0,
        'resp_power': 0.4,
        'resp_rate': 15.5,
        'rmssd_var': 0.2,
        'hr_fluc': 4,
      });
    }

    // Esegui la pipeline biometrica
    final result = await engine.processNightlyTelemetry(
      rawTelemetryRecords: records,
      userBaseline30d: {
        'rhr_mean': 55.0,
        'rmssd_mean': 65.0,
        'rmssd_std': 10.0,
        'baseline_temp_celsius': 36.5,
      },
    );

    // Assert: FCR deve corrispondere a 50 bpm e VFC a 76 ms dall'intervallo SWS
    final double extractedRhr = (result['resting_hr_bpm'] as num).toDouble();
    final double extractedHrv = (result['hrv_rmssd_ms'] as num).toDouble();
    final double totalSleepMin = (result['total_sleep_min'] as num).toDouble();
    final double swsMin = (result['sws_min'] as num).toDouble();
    final double remMin = (result['rem_min'] as num).toDouble();
    final double lightMin = (result['light_min'] as num).toDouble();

    expect(extractedRhr, equals(50.0));
    expect(extractedHrv, equals(76.0));
    expect(totalSleepMin, equals(swsMin + remMin + lightMin));
  });
}
