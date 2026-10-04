import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:whoop_clone/data/biometrics/health_vitals_engine.dart';
import 'package:whoop_clone/data/database/database_helper.dart';
import 'package:whoop_clone/data/models/ciclo_fisiologico.dart';
import 'package:whoop_clone/data/repositories/sqlite_whoop_repository.dart';
import 'package:whoop_clone/data/repositories/user_repository.dart';
import 'package:whoop_clone/viewmodels/whoop_viewmodel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('Sprint 6 — Zero-Mock Policy, Baseline Engine & Real BLE Tests', () {
    late DatabaseHelper dbHelper;
    late SqliteWhoopRepository repository;
    late UserRepository userRepository;
    late WhoopViewModel viewModel;

    setUp(() async {
      DatabaseHelper.isTestMode = true;
      dbHelper = DatabaseHelper();
      await dbHelper.clearAllTables();

      repository = SqliteWhoopRepository(dbHelper: dbHelper);
      userRepository = UserRepository(db: dbHelper);

      viewModel = WhoopViewModel(
        repository: repository,
        userRepository: userRepository,
      );

      await viewModel.loadData();
    });

    test('1. Zero-Mock Policy: DB vuoto restituisce 0 streak, battery null e vitals in attesa', () async {
      expect(viewModel.streakDays, equals(0));
      expect(viewModel.batteryPct, isNull);
      expect(viewModel.ultimoCiclo, isNull);
      expect(viewModel.liveBpm, equals(0));

      final vitals = viewModel.vitalEvaluations;
      expect(vitals, hasLength(5));
      expect(vitals.every((v) => v.status == VitalStatus.noData), isTrue);
    });

    test('2. Health Vitals Baseline Engine: Calibrazione (<7d), In Range e Out of Range (>=7d)', () {
      // 2a. < 7 giorni -> Calibrazione
      final calibEval = HealthVitalsEngine.evaluateVital(
        key: 'vfc',
        title: 'Variabilità FC',
        currentValue: 75.0,
        historical30dValues: [70.0, 72.0, 74.0, 73.0, 75.0], // 5 samples (<7)
        unit: 'ms',
      );
      expect(calibEval.status, equals(VitalStatus.calibration));
      expect(calibEval.badgeText, contains('Calibrazione in corso (5/7 giorni)'));

      // 2b. >= 7 giorni e valore nella norma (mu=70, std=2, min=67, max=73 -> val=71)
      final inRangeEval = HealthVitalsEngine.evaluateVital(
        key: 'vfc',
        title: 'Variabilità FC',
        currentValue: 71.0,
        historical30dValues: [70.0, 70.0, 70.0, 70.0, 70.0, 70.0, 70.0, 70.0],
        unit: 'ms',
      );
      expect(inRangeEval.status, equals(VitalStatus.inRange));
      expect(inRangeEval.badgeText, contains('Nella norma'));

      // 2c. >= 7 giorni e valore fuori norma (val=95 >> max=73)
      final outRangeEval = HealthVitalsEngine.evaluateVital(
        key: 'vfc',
        title: 'Variabilità FC',
        currentValue: 95.0,
        historical30dValues: [70.0, 70.0, 70.0, 70.0, 70.0, 70.0, 70.0, 70.0],
        unit: 'ms',
      );
      expect(outRangeEval.status, equals(VitalStatus.outOfRange));
      expect(outRangeEval.badgeText, contains('Fuori norma'));
    });

    test('3. Registrazione Ciclo Notturno reale popola le evaluazioni dinamiche in SQLite', () async {
      final now = DateTime.now();
      for (int i = 0; i < 7; i++) {
        final dateKey = now.subtract(Duration(days: i)).toIso8601String().substring(0, 10);
        await repository.insertCicloFisiologico(CicloFisiologico(
          dataIso: dateKey,
          rhrNotte: (52 + (i % 2)).toDouble(),
          hrvNotte: 75.0 + (i % 3),
          recoveryScore: 84.0,
        ));
      }

      await viewModel.loadData();
      expect(viewModel.streakDays, equals(7));

      final vitals = viewModel.vitalEvaluations;
      final fcrEval = vitals.firstWhere((v) => v.key == 'fcr');
      expect(fcrEval.sampleCount, equals(7));
      expect(fcrEval.status, equals(VitalStatus.inRange));
    });
  });
}
