import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:whoop_clone/data/database/database_helper.dart';
import 'package:whoop_clone/data/models/allenamento.dart';
import 'package:whoop_clone/data/repositories/workout_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  DatabaseHelper.isTestMode = true;

  group('WHOOP Temporal Session Deduplication Tests', () {
    late DatabaseHelper dbHelper;
    late WorkoutRepository repo;

    setUp(() async {
      dbHelper = DatabaseHelper();
      repo = WorkoutRepository(db: dbHelper);
    });

    test('Inserimento di due sessioni sovrapposte crea una singola voce unificata nel DB', () async {
      final now = DateTime.now();

      // Sessione 1: 10:00 - 10:45
      final start1 = DateTime(now.year, now.month, now.day, 10, 0);
      final end1 = DateTime(now.year, now.month, now.day, 10, 45);
      final w1 = Allenamento(
        dataIso: start1.toIso8601String().substring(0, 10),
        nomeAttivita: 'Corsa Mattutina',
        oraInizioAllenamento: start1,
        oraFineAllenamento: end1,
        durataMin: 45,
        hrMedia: 145,
        hrMax: 172,
        strainAttivita: 12.5,
        calorie: 450,
      );

      // Sessione 2 sovrapposta: 10:30 - 11:15
      final start2 = DateTime(now.year, now.month, now.day, 10, 30);
      final end2 = DateTime(now.year, now.month, now.day, 11, 15);
      final w2 = Allenamento(
        dataIso: start2.toIso8601String().substring(0, 10),
        nomeAttivita: 'Corsa Intensa',
        oraInizioAllenamento: start2,
        oraFineAllenamento: end2,
        durataMin: 45,
        hrMedia: 155,
        hrMax: 180,
        strainAttivita: 14.0,
        calorie: 500,
      );

      await repo.insertWorkout(w1);
      await repo.insertWorkout(w2);

      final allWorkouts = await repo.getAll();

      // Deve esistere una sola voce unificata
      expect(allWorkouts.length, equals(1));

      final merged = allWorkouts.first;
      // Orario di inizio deve corrispondere al minimo (10:00) ed orario di fine al massimo (11:15)
      expect(merged.oraInizioAllenamento, equals(start1));
      expect(merged.oraFineAllenamento, equals(end2));
      expect(merged.durataMin, equals(75)); // 1h 15m = 75 min
      expect(merged.hrMax, equals(180));
    });
  });
}
