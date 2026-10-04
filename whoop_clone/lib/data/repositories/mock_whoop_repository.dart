import 'sqlite_whoop_repository.dart';

/// Legacy alias che reindirizza a SqliteWhoopRepository per retrocompatibilità.
/// Nessun dato mock viene seminato se il database è vuoto.
class MockWhoopRepository extends SqliteWhoopRepository {
  MockWhoopRepository({super.dbHelper});
}
