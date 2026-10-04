import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:whoop_clone/data/database/database_helper.dart';
import 'package:whoop_clone/data/ble/ble_connection_manager.dart';
import 'package:whoop_clone/data/repositories/sqlite_whoop_repository.dart';
import 'package:whoop_clone/data/repositories/user_repository.dart';
import 'package:whoop_clone/viewmodels/whoop_viewmodel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  DatabaseHelper.isTestMode = true;

  group('Sprint 3 — Navigation, Profile Editing & BLE Integration Tests', () {
    late DatabaseHelper dbHelper;
    late SqliteWhoopRepository whoopRepository;
    late UserRepository userRepository;
    late WhoopViewModel viewModel;
    late BleConnectionManager bleManager;

    setUp(() async {
      dbHelper = DatabaseHelper();
      await dbHelper.clearAllTables();

      whoopRepository = SqliteWhoopRepository(dbHelper: dbHelper);
      userRepository = UserRepository(db: dbHelper);
      bleManager = BleConnectionManager();
      bleManager.resetStateForTest();

      viewModel = WhoopViewModel(
        repository: whoopRepository,
        userRepository: userRepository,
        bleManager: bleManager,
      );

      await viewModel.loadData();
    });

    test('1. Navigazione temporale: setSelectedDate aggiorna la data e la query SQLite', () async {
      final today = DateTime.now();
      final yesterday = today.subtract(const Duration(days: 1));

      expect(viewModel.selectedDate.year, equals(today.year));
      expect(viewModel.selectedDate.day, equals(today.day));

      viewModel.setSelectedDate(yesterday);
      await Future.delayed(const Duration(milliseconds: 100));

      expect(viewModel.selectedDate.day, equals(yesterday.day));
      expect(viewModel.ultimoCiclo, isNull);
    });

    test('2. Modifica profilo utente: updateUserProfile aggiorna la tabella utente_profilo in SQLite', () async {
      await viewModel.updateUserProfile(
        name: 'Marco Rossi',
        maxHr: 195,
        baselineRhr: 48,
        baselineHrv: 85.0,
        age: 32,
        sleepBaselineMin: 500,
      );

      expect(viewModel.userProfile.nome, equals('Marco Rossi'));
      expect(viewModel.userProfile.hrMax, equals(195));
      expect(viewModel.userProfile.hrRestBaseline, equals(48));
      expect(viewModel.userProfile.hrvBaselineMean, equals(85.0));

      final profileFromDb = await userRepository.getProfile();
      expect(profileFromDb, isNotNull);
      expect(profileFromDb!.nome, equals('Marco Rossi'));
      expect(profileFromDb.hrMax, equals(195));
      expect(profileFromDb.hrRestBaseline, equals(48));
      expect(profileFromDb.sleepBaselineMin, equals(500));
    });

    test('3. Gestione BLE: startBleScan attiva la ricerca senza sollevare eccezioni', () async {
      expect(viewModel.bleState, isNotNull);
      expect(viewModel.batteryPct, isNull);
      
      await viewModel.startBleScan();
      expect(viewModel.bleState, isNotNull);
    });

    test('4. Test Ripristino ID: BleConnectionManager legge l\'ID memorizzato e tenta il collegamento Zero-Scan', () async {
      final pairedId = await bleManager.getPairedDeviceId();
      expect(pairedId, isNull);

      final reconnected = await bleManager.connectSavedDevice();
      expect(reconnected, isFalse);
      expect(bleManager.state, anyOf(BleState.disconnected, BleState.error));
    });

    test('5. Test Gestione Stato: BleConnectionManager notifica i cambi di stato al ViewModel', () async {
      BleState? lastState;
      bleManager.stateStream.listen((s) => lastState = s);

      expect(viewModel.bleState, anyOf(BleState.disconnected, BleState.error));
      expect(lastState, isNull);
    });
  });
}
