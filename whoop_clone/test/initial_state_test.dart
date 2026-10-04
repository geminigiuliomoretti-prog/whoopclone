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

  group('WhoopViewModel Initial Startup & Null State Tests', () {
    test('All\'avvio senza dati SQLite, recoveryScore e sleepPerformance sono null', () async {
      // 1. Assicura DB vuoto
      final dbHelper = DatabaseHelper();
      await dbHelper.clearAllTables();

      // 2. Istanzia repository e ViewModel
      final repo = SqliteWhoopRepository(dbHelper: dbHelper);
      final viewModel = WhoopViewModel(repository: repo);

      // 3. Esegui caricamento iniziale
      await viewModel.loadInitialData();

      // 4. Verifiche rigorose dello stato iniziale nullo/senza mock
      expect(viewModel.recoveryScore, isNull, reason: 'Il recoveryScore non deve contenere default fittizi come 99');
      expect(viewModel.sleepPerformance, isNull, reason: 'La sleepPerformance non deve contenere default come 96 o 94');
      expect(viewModel.hrv, isNull, reason: 'La VFC non deve contenere valori mock come 250');
      expect(viewModel.restingHr, isNull);
      expect(viewModel.respiratoryRate, isNull);
      expect(viewModel.ultimoCiclo, isNull);
      expect(viewModel.sonnoList, isEmpty);
      expect(viewModel.cicliList, isEmpty);
    });

    test('Se il sonno non è stato ancora registrato per la data, nessun recovery o HRV è presente', () async {
      final dbHelper = DatabaseHelper();
      await dbHelper.clearAllTables();

      final repo = SqliteWhoopRepository(dbHelper: dbHelper);
      final viewModel = WhoopViewModel(repository: repo);
      await viewModel.loadData();

      expect(viewModel.ultimoCiclo, isNull);
      expect(viewModel.recoveryScore, isNull);
      expect(viewModel.sleepPerformance, isNull);
      expect(viewModel.hrv, isNull);
    });
  });
}
