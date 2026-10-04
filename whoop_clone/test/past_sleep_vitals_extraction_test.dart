import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:whoop_clone/data/database/database_helper.dart';
import 'package:whoop_clone/data/repositories/sqlite_whoop_repository.dart';
import 'package:whoop_clone/data/repositories/user_repository.dart';
import 'package:whoop_clone/viewmodels/whoop_viewmodel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  DatabaseHelper.isTestMode = true;

  tearDown(() async {
    await DatabaseHelper().clearAllTables();
  });

  group('Past Sleep Biometric Vitals Extraction Tests', () {
    test('1. Sonno Passato SENZA dati telemetrici: strictly null (display --) per tutti i parametri vitali', () async {
      final dbHelper = DatabaseHelper();
      await dbHelper.clearAllTables();

      final repository = SqliteWhoopRepository(dbHelper: dbHelper);
      final userRepository = UserRepository(db: dbHelper);
      final viewModel = WhoopViewModel(
        repository: repository,
        userRepository: userRepository,
      );
      await viewModel.loadData();

      final start = DateTime(2026, 9, 21, 23, 0);
      final end = DateTime(2026, 9, 22, 7, 0);
      const dateIso = '2026-09-22';

      final res = await viewModel.processAndAddManualSleep(
        startTime: start,
        endTime: end,
        dateIso: dateIso,
        allowFallback: true,
      );

      expect(res['success'], isTrue);
      expect(res['hasRealBleData'], isFalse);
      expect(res['respiratoryRate'], isNull);
      expect(res['skinTempDelta'], isNull);
      expect(res['spo2Pct'], isNull);
      expect(res['recoveryScore'], isNull);
      expect(res['hrv'], isNull);

      expect(viewModel.respiratoryRate, isNull);
      expect(viewModel.skinTempDelta, isNull);
      expect(viewModel.bloodOxygenSpo2, isNull);
      expect(viewModel.recoveryScore, isNull);
      expect(viewModel.hrv, isNull);

      final vitals = viewModel.vitalEvaluations;
      expect(vitals, hasLength(5));
      expect(vitals.map((v) => v.key).toList(), equals(['resp_rate', 'spo2', 'fcr', 'vfc', 'temp']));
      for (final v in vitals) {
        expect(v.currentVal, isNull);
      }
    });

    test('2. Sonno Passato CON dati telemetrici scaricati/grezzi: estrazione accurata di Temp Cutanea, Frequenza Respiratoria e SpO2', () async {
      final dbHelper = DatabaseHelper();
      await dbHelper.clearAllTables();

      final repository = SqliteWhoopRepository(dbHelper: dbHelper);
      final userRepository = UserRepository(db: dbHelper);
      final viewModel = WhoopViewModel(
        repository: repository,
        userRepository: userRepository,
      );
      await viewModel.loadData();

      final start = DateTime(2026, 9, 21, 23, 0);
      final end = DateTime(2026, 9, 22, 7, 0);
      const dateIso = '2026-09-22';

      final durationMinutes = end.difference(start).inMinutes;
      for (int m = 0; m < durationMinutes; m += 2) {
        final timestamp = start.add(Duration(minutes: m));
        final isSws = (m >= 60 && m <= 180) || (m >= 360 && m <= 450);
        await dbHelper.insertTelemetriaPoint(
          bpm: isSws ? 52 : 62,
          rrMs: isSws ? 1150.0 : 967.0,
          motionVar: isSws ? 0.002 : 0.04,
          timestamp: timestamp,
          respRate: 14.8,
          respPower: 0.85,
          skinTempCelsius: 36.7,
          skinTempRaw: (36.7 * 128).round(),
          spo2Pct: 98.0,
          spo2RatioR: 0.48,
        );
      }

      final res = await viewModel.processAndAddManualSleep(
        startTime: start,
        endTime: end,
        dateIso: dateIso,
      );

      expect(res['success'], isTrue);
      expect(res['hasRealBleData'], isTrue);
      expect(res['noTelemetryFound'], isFalse);

      expect(res['respiratoryRate'], isNotNull);
      final respRate = res['respiratoryRate'] as double;
      expect(respRate, inInclusiveRange(14.0, 16.0));

      expect(res['skinTempDelta'], isNotNull);
      final skinTempDelta = res['skinTempDelta'] as double;
      expect(skinTempDelta, closeTo(0.2, 0.05));

      expect(res['spo2Pct'], isNotNull);
      final spo2Pct = res['spo2Pct'] as double;
      expect(spo2Pct, closeTo(98.0, 1.0));

      expect(res['recoveryScore'], isNotNull);

      expect(viewModel.respiratoryRate, closeTo(14.8, 1.0));
      expect(viewModel.skinTempDelta, closeTo(0.2, 0.05));
      expect(viewModel.bloodOxygenSpo2, closeTo(98.0, 1.0));
      expect(viewModel.recoveryScore, isNotNull);

      final vitals = viewModel.vitalEvaluations;
      expect(vitals, hasLength(5));

      final respEval = vitals.firstWhere((v) => v.key == 'resp_rate');
      expect(respEval.currentVal, isNotNull);
      expect(respEval.currentVal, closeTo(14.8, 1.0));

      final spo2Eval = vitals.firstWhere((v) => v.key == 'spo2');
      expect(spo2Eval.currentVal, isNotNull);
      expect(spo2Eval.currentVal, closeTo(98.0, 1.0));

      final tempEval = vitals.firstWhere((v) => v.key == 'temp');
      expect(tempEval.currentVal, isNotNull);
      expect(tempEval.currentVal, closeTo(0.2, 0.05));
    });
  });
}
