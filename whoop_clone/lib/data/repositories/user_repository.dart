import 'dart:async';
import '../database/database_helper.dart';
import '../models/utente_profilo.dart';

/// Repository per la gestione del profilo utente (`utente_profilo`).
class UserRepository {
  final DatabaseHelper _db;
  final StreamController<UtenteProfilo?> _profileController =
      StreamController<UtenteProfilo?>.broadcast();

  UserRepository({DatabaseHelper? db}) : _db = db ?? DatabaseHelper();

  Stream<UtenteProfilo?> watchProfile() => _profileController.stream;

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

  void dispose() {
    _profileController.close();
  }
}
