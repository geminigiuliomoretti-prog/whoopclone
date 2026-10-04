import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:whoop_clone/data/database/database_helper.dart';
import 'package:whoop_clone/data/repositories/dashboard_preferences_repository.dart';
import 'package:whoop_clone/data/repositories/sqlite_whoop_repository.dart';
import 'package:whoop_clone/data/repositories/user_repository.dart';
import 'package:whoop_clone/viewmodels/whoop_viewmodel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  DatabaseHelper.isTestMode = true;

  group('Sprint 5 — Trends, Dashboard Persistence, Custom Journal & Coach Tests', () {
    late DatabaseHelper dbHelper;
    late SqliteWhoopRepository whoopRepository;
    late UserRepository userRepository;
    late DashboardPreferencesRepository dashboardPreferencesRepository;
    late WhoopViewModel viewModel;

    setUp(() async {
      dbHelper = DatabaseHelper();
      await dbHelper.clearAllTables();

      whoopRepository = SqliteWhoopRepository(dbHelper: dbHelper);
      userRepository = UserRepository(db: dbHelper);
      dashboardPreferencesRepository = DashboardPreferencesRepository(dbHelper: dbHelper);

      viewModel = WhoopViewModel(
        repository: whoopRepository,
        userRepository: userRepository,
        dashboardPreferencesRepository: dashboardPreferencesRepository,
      );

      await viewModel.loadData();
    });

    test('1. Persistenza Dashboard: saveDashboardTiles salva su SQLite e ricarica all\'avvio', () async {
      final customTiles = ['vfc', 'fcr', 'deep_sleep', 'skin_temp'];
      await viewModel.saveDashboardTiles(customTiles);

      expect(viewModel.enabledTileKeys, equals(customTiles));

      final loadedTiles = await dashboardPreferencesRepository.getEnabledTiles();
      expect(loadedTiles, equals(customTiles));

      final newViewModel = WhoopViewModel(
        repository: whoopRepository,
        userRepository: userRepository,
        dashboardPreferencesRepository: dashboardPreferencesRepository,
      );
      await newViewModel.loadData();

      expect(newViewModel.enabledTileKeys, equals(customTiles));
    });

    test('2. Abitudini Custom Diario: insertAbitudineCustom salva nella tabella SQLite', () async {
      final habitId = await dbHelper.insertAbitudineCustom('Caffè dopo le 14:00', 'boolean');
      expect(habitId, greaterThan(0));

      final habits = await dbHelper.getAbitudiniCustom();
      expect(habits, isNotEmpty);
      expect(habits.any((h) => h['nome'] == 'Caffè dopo le 14:00'), isTrue);

      final dateKey = DateTime.now().toIso8601String().substring(0, 10);
      await dbHelper.insertVoceDiario({
        'data_iso': dateKey,
        'chiave_domanda': 'Caffè dopo le 14:00',
        'risposta_bool': 1,
      });

      final diarioList = await whoopRepository.getVociDiario();
      expect(diarioList.any((v) => v.testoDomanda == 'Caffè dopo le 14:00'), isTrue);
    });

    test('3. Messaggi WHOOP Coach AI: insertCoachMessage e getCoachMessages in SQLite', () async {
      await dbHelper.insertCoachMessage('user', 'Come posso aumentare la VFC?');
      final msgs = await dbHelper.getCoachMessages();

      expect(msgs, isNotEmpty);
      expect(msgs.last['testo_messaggio'], equals('Come posso aumentare la VFC?'));
    });
  });
}
