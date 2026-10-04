import '../database/database_helper.dart';

/// Repository per la gestione della persistenza delle preferenze tessere della Dashboard
class DashboardPreferencesRepository {
  final DatabaseHelper _dbHelper;

  DashboardPreferencesRepository({DatabaseHelper? dbHelper})
      : _dbHelper = dbHelper ?? DatabaseHelper();

  Future<List<String>> getEnabledTiles() async {
    final tiles = await _dbHelper.getEnabledDashboardTiles();
    if (tiles.isEmpty) {
      // Default initial tiles
      return ['vfc', 'fcr', 'steps', 'zone_fc_low', 'vo2max', 'calories'];
    }
    return tiles;
  }

  Future<void> saveEnabledTiles(List<String> enabledKeys) async {
    await _dbHelper.saveDashboardTiles(enabledKeys);
  }
}
