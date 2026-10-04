import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:whoop_clone/data/database/database_helper.dart';
import 'package:whoop_clone/data/models/allenamento.dart';
import 'package:whoop_clone/data/repositories/sqlite_whoop_repository.dart';
import 'package:whoop_clone/data/repositories/user_repository.dart';
import 'package:whoop_clone/data/repositories/workout_repository.dart';
import 'package:whoop_clone/viewmodels/whoop_viewmodel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  DatabaseHelper.isTestMode = true;

  group('Sprint 4 — Live Workout Tracker & Cascade Recalculation Tests', () {
    late DatabaseHelper dbHelper;
    late SqliteWhoopRepository whoopRepository;
    late UserRepository userRepository;
    late WorkoutRepository workoutRepository;
    late WhoopViewModel viewModel;

    setUp(() async {
      dbHelper = DatabaseHelper();
      await dbHelper.clearAllTables();

      whoopRepository = SqliteWhoopRepository(dbHelper: dbHelper);
      userRepository = UserRepository(db: dbHelper);
      workoutRepository = WorkoutRepository(db: dbHelper);
      viewModel = WhoopViewModel(
        repository: whoopRepository,
        userRepository: userRepository,
      );

      await viewModel.loadData();
    });

    test('1. Salvataggio Allenamento: insertWorkout scrive su SQLite e aggiorna le liste', () async {
      final now = DateTime.now();
      final startTime = now.subtract(const Duration(minutes: 45));

      final workout = Allenamento(
        oraInizioCiclo: now,
        oraInizioAllenamento: startTime,
        oraFineAllenamento: now,
        fusoOrario: 'UTC+01:00',
        nomeAttivita: 'Corsa Outdoor',
        sforzoRichiesto: 14.5,
        energiaBruciataCal: 420,
        fcMediaBpm: 152,
        fcMaxBpm: 178,
        durataMin: 45.0,
      );

      await viewModel.addWorkout(workout);

      expect(viewModel.allenamentiList, isNotEmpty);
      expect(viewModel.allenamentiList.first.nomeAttivita, equals('Corsa Outdoor'));
      expect(viewModel.allenamentiList.first.sforzoRichiesto, equals(14.5));
    });

    test('2. Ricalcolo a cascata: L\'inserimento dell\'allenamento aggiorna Day Strain e Sleep Need', () async {
      final now = DateTime.now();
      final dateKey = now.toIso8601String().substring(0, 10);

      final workout = Allenamento(
        oraInizioCiclo: now,
        oraInizioAllenamento: now.subtract(const Duration(minutes: 60)),
        oraFineAllenamento: now,
        fusoOrario: 'UTC+01:00',
        nomeAttivita: 'Tennis',
        sforzoRichiesto: 15.2,
        energiaBruciataCal: 650,
        fcMediaBpm: 148,
        fcMaxBpm: 175,
        durataMin: 60.0,
      );

      await workoutRepository.insertWorkout(workout);

      final cicli = await whoopRepository.getCicliFisiologici();
      final todayCiclo = cicli.firstWhere((c) => c.dataIso == dateKey);

      expect(todayCiclo.sforzoGiornaliero, isNotNull);
      expect(todayCiclo.sforzoGiornaliero, greaterThan(14.0));
      expect(todayCiclo.sonnoRichiestoMin, isNotNull);
      expect(todayCiclo.sonnoRichiestoMin, greaterThan(480));
    });
  });
}
