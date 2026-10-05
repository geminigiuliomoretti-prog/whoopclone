import 'package:whoop_clone/data/repositories/sqlite_whoop_repository.dart';

/// Legacy alias che reindirizza a SqliteWhoopRepository per test.
class MockWhoopRepository extends SqliteWhoopRepository {
  MockWhoopRepository({super.dbHelper});
}
