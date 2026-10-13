import 'dart:async';
import '../database/database_helper.dart';
import '../models/utente_profilo.dart';
import '../models/personal_baseline.dart';

/// Repository per la gestione del profilo utente (`utente_profilo`) e delle baseline personali.
class UserRepository {
  final DatabaseHelper _db;
  final StreamController<UtenteProfilo?> _profileController =
      StreamController<UtenteProfilo?>.broadcast();
  final StreamController<List<PersonalBaseline>> _baselinesController =
      StreamController<List<PersonalBaseline>>.broadcast();

  UserRepository({DatabaseHelper? db}) : _db = db ?? DatabaseHelper();

  Stream<UtenteProfilo?> watchProfile() => _profileController.stream;
  Stream<List<PersonalBaseline>> watchBaselines() => _baselinesController.stream;

  Future<UtenteProfilo?> getProfile() async {
    final map = await _db.getUserProfile();
    if (map == null) return null;
    final profile = UtenteProfilo.fromMap(map);
    _profileController.add(profile);
    return profile;
  }

  Future<void> updateProfile(UtenteProfilo profile) async {
    await _db.updateUserProfile(profile.toMap());
    _profileController.add(profile);
  }

  // --- Baseline Personali ---

  Future<List<PersonalBaseline>> getPersonalBaselines() async {
    final maps = await _db.getAllPersonalBaselines();
    final list = maps.map((m) => PersonalBaseline.fromMap(m)).toList();
    _baselinesController.add(list);
    return list;
  }

  Future<PersonalBaseline?> getPersonalBaseline(String metricKey) async {
    final map = await _db.getPersonalBaseline(metricKey);
    if (map == null) return null;
    return PersonalBaseline.fromMap(map);
  }

  Future<void> savePersonalBaselines(List<PersonalBaseline> baselines) async {
    final maps = baselines.map((b) => b.toMap()).toList();
    await _db.savePersonalBaselinesBatch(maps);
    _baselinesController.add(baselines);
  }

  void dispose() {
    _profileController.close();
    _baselinesController.close();
  }
}
