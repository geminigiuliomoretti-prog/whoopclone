import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:whoop_clone/data/database/database_helper.dart';
import 'package:whoop_clone/data/repositories/sqlite_whoop_repository.dart';
import 'package:whoop_clone/viewmodels/whoop_viewmodel.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    DatabaseHelper.isTestMode = true;
  });

  tearDown(() async {
    await DatabaseHelper().clearAllTables();
  });

  group('Past Sleep Window & Pure Telemetry Processing Tests', () {
    test('1. Inserimento Sonno Passato (23:50 - 08:10) con dati BLE reali calcola 500 min, fasi e recovery', () async {
      final dbHelper = DatabaseHelper();
      await dbHelper.clearAllTables();

      final repo = SqliteWhoopRepository(dbHelper: dbHelper);
      final viewModel = WhoopViewModel(repository: repo);

      final startDateTime = DateTime(2026, 8, 13, 23, 50);
      final endDateTime = DateTime(2026, 8, 14, 8, 10);
      final dateIso = '2026-08-14';

      // Popola la telemetria grezza con campioni reali nell'intervallo 23:50 - 08:10 (500 minuti = 1000 epoche da 30s)
      for (int i = 0; i < 1000; i++) {
        final sampleTs = startDateTime.add(Duration(seconds: i * 30));
        // Cicli SWS nei primi 2/3 della notte (epoche 200..450 e 600..750)
        final isSws = (i >= 200 && i < 450) || (i >= 600 && i < 750);
        final hrVal = isSws ? 52 : 62;
        final rrVal = isSws ? 82.0 : 45.0;
        final motion = isSws ? 0.001 : 0.008;

        await dbHelper.insertTelemetriaPoint(
          bpm: hrVal,
          rrMs: rrVal,
          motionVar: motion,
          timestamp: sampleTs,
        );
      }

      // Esegui elaborazione sonno passato
      final result = await viewModel.processAndAddManualSleep(
        startTime: startDateTime,
        endTime: endDateTime,
        dateIso: dateIso,
      );

      expect(result['success'], isTrue);
      expect(result['hasRealBleData'], isTrue);

      final totalSleepMin = result['totalSleepMin'] as num?;
      expect(totalSleepMin, isNotNull);
      expect(totalSleepMin!.round(), equals(500)); // Esattamente 8h 20m!

      expect(result['recoveryScore'], isNotNull);
      expect(viewModel.recoveryScore, isNotNull);
      expect(viewModel.sleepPerformance, isNotNull);
      expect(viewModel.sleepPerformance, greaterThan(90)); // 500 min / 480 min > 100%

      // Verifica dati persistiti a DB
      final sonnoList = await repo.getSonnoLogs();
      expect(sonnoList.length, equals(1));
      expect(sonnoList.first.durataTotMin, equals(500));
      expect(sonnoList.first.sonnoProfondoMin, greaterThan(0));
    });

    test('2. Inserimento Sonno Passato (23:50 - 08:10) SENZA dati BLE salva 500 min e lascia vitali a null (--)', () async {
      final dbHelper = DatabaseHelper();
      await dbHelper.clearAllTables();

      final repo = SqliteWhoopRepository(dbHelper: dbHelper);
      final viewModel = WhoopViewModel(repository: repo);

      final startDateTime = DateTime(2026, 8, 13, 23, 50);
      final endDateTime = DateTime(2026, 8, 14, 8, 10);
      final dateIso = '2026-08-14';

      // Nessun dato inserito in telemetria_grezza
      final result = await viewModel.processAndAddManualSleep(
        startTime: startDateTime,
        endTime: endDateTime,
        dateIso: dateIso,
      );

      expect(result['success'], isTrue);
      expect(result['hasRealBleData'], isFalse);

      final totalSleepMin = result['totalSleepMin'] as num?;
      expect(totalSleepMin, isNotNull);
      expect(totalSleepMin!.round(), equals(500)); // Registra esattamente 500 minuti (8h 20m)
      expect(result['recoveryScore'], isNull); // Vitali a null

      // Verifica che la durata salvata su SQLite sia 500 min e non 46 min
      final sonnoList = await repo.getSonnoLogs();
      expect(sonnoList.length, equals(1));
      expect(sonnoList.first.durataTotMin, equals(500));
      expect(sonnoList.first.sleepPerformancePct, greaterThan(90));

      final cicliList = await repo.getCicliFisiologici();
      expect(cicliList.first.recoveryScore, isNull);
    });

    test('3. Test Anti-Sovrastima: 5160 campioni a 1Hz (86 min) NON generano 43 ore di sonno', () async {
      final dbHelper = DatabaseHelper();
      await dbHelper.clearAllTables();

      final repo = SqliteWhoopRepository(dbHelper: dbHelper);
      final viewModel = WhoopViewModel(repository: repo);

      final startDateTime = DateTime(2026, 8, 14, 8, 0);
      final endDateTime = DateTime(2026, 8, 14, 9, 26); // 86 minuti esatti (5160 secondi)
      final dateIso = '2026-08-14';

      // Inserisce 5160 record a 1Hz (1 al secondo)
      for (int i = 0; i < 5160; i += 2) { // 2580 insert a 2s
        final sampleTs = startDateTime.add(Duration(seconds: i));
        await dbHelper.insertTelemetriaPoint(
          bpm: 58,
          rrMs: 65.0,
          motionVar: 0.002,
          timestamp: sampleTs,
        );
      }

      final result = await viewModel.processAndAddManualSleep(
        startTime: startDateTime,
        endTime: endDateTime,
        dateIso: dateIso,
      );

      expect(result['success'], isTrue);
      final totalSleepMin = result['totalSleepMin'] as num?;
      expect(totalSleepMin, isNotNull);
      // La durata deve essere vicina a 86 min, MAI 43 ore (2580 min)!
      expect(totalSleepMin!.round(), lessThanOrEqualTo(87));
      expect(totalSleepMin.round(), greaterThanOrEqualTo(80));

      final sonnoList = await repo.getSonnoLogs();
      expect(sonnoList.first.durataTotMin, lessThanOrEqualTo(87));
    });
  });
}
