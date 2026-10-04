import 'dart:async';
import '../database/database_helper.dart';
import '../models/voce_diario.dart';

/// Repository per le voci del diario (`voci_diario`).
class JournalRepository {
  final DatabaseHelper _db;
  final StreamController<List<VoceDiario>> _journalStreamController =
      StreamController<List<VoceDiario>>.broadcast();

  JournalRepository({DatabaseHelper? db}) : _db = db ?? DatabaseHelper();

  Stream<List<VoceDiario>> watchVociDiario(String dataIso) {
    getByDate(dataIso).then((list) {
      _journalStreamController.add(list);
    });
    return _journalStreamController.stream;
  }

  Future<List<VoceDiario>> getByDate(String dataIso) async {
    final maps = await _db.getVociDiarioByDate(dataIso);
    return maps.map((m) => VoceDiario.fromMap(m)).toList();
  }

  Future<List<VoceDiario>> getAll() async {
    final maps = await _db.getAllVociDiario();
    return maps.map((m) => VoceDiario.fromMap(m)).toList();
  }

  Future<void> insertVoceDiario(VoceDiario voce) async {
    await _db.insertVoceDiario(voce.toMap());
    final list = await getByDate(voce.dataIso);
    _journalStreamController.add(list);
  }

  void dispose() {
    _journalStreamController.close();
  }
}
