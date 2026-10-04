import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:whoop_clone/data/database/database_helper.dart';
import 'package:whoop_clone/data/models/allenamento.dart';
import 'package:whoop_clone/data/models/sonno.dart';
import 'package:whoop_clone/data/repositories/user_repository.dart';
import 'package:whoop_clone/data/repositories/physiology_repository.dart';
import 'package:whoop_clone/data/repositories/workout_repository.dart';
import 'package:whoop_clone/data/repositories/sleep_repository.dart';
import 'package:whoop_clone/data/repositories/journal_repository.dart';

void main() {
  // Inizializzazione sqflite_ffi per test su desktop/VM
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('Sprint 2 — Database SQLite & Repository Tests', () {
    late DatabaseHelper dbHelper;
    late UserRepository userRepo;
    late PhysiologyRepository physioRepo;
    late WorkoutRepository workoutRepo;
    late SleepRepository sleepRepo;
    late JournalRepository journalRepo;

    setUp(() async {
      dbHelper = DatabaseHelper();
      await dbHelper.clearAllTables();

      // Seed profilo di default per ciascun test
      await dbHelper.updateUserProfile({
        'id': 1,
        'nome': 'Utente WHOOP',
        'eta': 30,
        'hr_max': 190,
        'hr_rest_baseline': 55,
        'hrv_baseline_mean': 65.0,
        'hrv_baseline_std': 15.0,
        'rhr_baseline_mean': 55.0,
        'rhr_baseline_std': 3.5,
        'sleep_baseline_min': 480,
      });

      userRepo = UserRepository(db: dbHelper);
      physioRepo = PhysiologyRepository(db: dbHelper);
      workoutRepo = WorkoutRepository(
        db: dbHelper,
        physiologyRepository: physioRepo,
        userRepository: userRepo,
      );
      sleepRepo = SleepRepository(
        db: dbHelper,
        physiologyRepository: physioRepo,
        userRepository: userRepo,
      );
      journalRepo = JournalRepository(db: dbHelper);
    });

    test('1. DatabaseHelper ha profilo utente di default in utente_profilo', () async {
      final profile = await userRepo.getProfile();
      expect(profile, isNotNull);
      expect(profile!.nome, equals('Utente WHOOP'));
      expect(profile.eta, equals(30));
      expect(profile.hrMax, equals(190));
      expect(profile.hrRestBaseline, equals(55));
    });

    test('2. Aggiornamento profilo utente modifica i dati su utente_profilo', () async {
      final initial = await userRepo.getProfile();
      expect(initial, isNotNull);

      final updated = initial!.copyWith(
        nome: 'Mario Rossi',
        hrMax: 185,
        hrRestBaseline: 52,
      );

      await userRepo.updateProfile(updated);
      final fetched = await userRepo.getProfile();

      expect(fetched!.nome, equals('Mario Rossi'));
      expect(fetched.hrMax, equals(185));
      expect(fetched.hrRestBaseline, equals(52));
    });

    test('3. WorkoutRepository.insertWorkout ricalcola Day Strain e Sleep Need in cicli_fisiologici', () async {
      const dataIso = '2026-08-07';

      final workout1 = Allenamento(
        dataIso: dataIso,
        nomeAttivita: 'Corsa',
        oraInizio: '${dataIso}T08:00:00.000Z',
        oraFine: '${dataIso}T09:00:00.000Z',
        durataMin: 60,
        strainAttivita: 12.0,
        calorie: 500,
        hrMedia: 145,
        hrMax: 175,
      );

      await workoutRepo.insertWorkout(workout1);

      final workouts = await workoutRepo.getByDate(dataIso);
      expect(workouts.length, equals(1));
      expect(workouts.first.nomeAttivita, equals('Corsa'));

      // Verifica ricalcolo a cascata in cicli_fisiologici
      final ciclo = await physioRepo.getByDate(dataIso);
      expect(ciclo, isNotNull);
      expect(ciclo!.strainGiornaliero, greaterThan(0.0));
      expect(ciclo.sleepNeedMin, greaterThan(480));
      expect(ciclo.calorieTot, equals(500));
    });

    test('4. SleepRepository.insertOrUpdateSleep ricalcola Recovery Score in cicli_fisiologici', () async {
      const dataIso = '2026-08-07';

      final sonno = Sonno(
        dataIso: dataIso,
        oraInizio: '${dataIso}T22:00:00.000Z',
        oraFine: '${dataIso}T06:30:00.000Z',
        durataTotMin: 510,
        sonnoProfondoMin: 120,
        sonnoRemMin: 130,
        efficienzaPct: 92.0,
        sleepPerformancePct: 88.0,
      );

      await sleepRepo.insertOrUpdateSleep(sonno, nightHrvMs: 72.0, nightRhrBpm: 50.0);

      final fetchedSleep = await sleepRepo.getByDate(dataIso);
      expect(fetchedSleep, isNotNull);
      expect(fetchedSleep!.durataTotMin, equals(510));

      // Verifica ricalcolo a cascata del Recovery Score in cicli_fisiologici
      final ciclo = await physioRepo.getByDate(dataIso);
      expect(ciclo, isNotNull);
      expect(ciclo!.recoveryScore, greaterThan(0.0));
      expect(ciclo.hrvNotte, equals(72.0));
      expect(ciclo.rhrNotte, equals(50.0));
    });

    test('5. Query su data senza record restituisce lista vuota e null senza eccezioni', () async {
      const dateNoData = '2020-01-01';

      final ciclo = await physioRepo.getByDate(dateNoData);
      expect(ciclo, isNull);

      final workouts = await workoutRepo.getByDate(dateNoData);
      expect(workouts, isEmpty);

      final sleep = await sleepRepo.getByDate(dateNoData);
      expect(sleep, isNull);

      final diario = await journalRepo.getByDate(dateNoData);
      expect(diario, isEmpty);
    });
  });
}
