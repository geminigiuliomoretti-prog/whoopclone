import 'dart:async';
import '../database/database_helper.dart';
import '../models/ciclo_fisiologico.dart';

/// Repository per la gestione dei cicli fisiologici (`cicli_fisiologici`).
class PhysiologyRepository {
  final DatabaseHelper _db;
  final StreamController<MapEntry<String, CicloFisiologico?>> _physioUpdateBus =
      StreamController<MapEntry<String, CicloFisiologico?>>.broadcast();
  final StreamController<CicloFisiologico?> _todayStreamController =
      StreamController<CicloFisiologico?>.broadcast();

  PhysiologyRepository({DatabaseHelper? db}) : _db = db ?? DatabaseHelper();

  /// Metodo reattivo per osservare i cicli fisiologici della giornata corrente o specifica, isolato per data.
  Stream<CicloFisiologico?> watchTodayPhysiology({String? dataIso}) {
    final key = dataIso ?? DateTime.now().toIso8601String().substring(0, 10);
    late StreamController<CicloFisiologico?> controller;
    StreamSubscription? sub;

    controller = StreamController<CicloFisiologico?>.broadcast(
      onListen: () {
        getByDate(key).then((ciclo) {
          if (!controller.isClosed) {
            controller.add(ciclo);
          }
        });
        sub = _physioUpdateBus.stream
            .where((entry) => entry.key == key)
            .listen((entry) {
          if (!controller.isClosed) {
            controller.add(entry.value);
          }
        });
      },
      onCancel: () {
        sub?.cancel();
      },
    );
    return controller.stream;
  }

  /// Recupera il ciclo fisiologico per una specifica data (YYYY-MM-DD).
  Future<CicloFisiologico?> getByDate(String dataIso) async {
    final map = await _db.getCicloByDate(dataIso);
    if (map == null) return null;
    return CicloFisiologico.fromMap(map);
  }

  /// Recupera tutti i cicli fisiologici ordinati per data discendente.
  Future<List<CicloFisiologico>> getAll() async {
    final maps = await _db.getAllCicli();
    return maps.map((m) => CicloFisiologico.fromMap(m)).toList();
  }

  /// Inserisce o aggiorna un ciclo fisiologico e notifica la UI via Stream.
  Future<void> upsert(CicloFisiologico ciclo) async {
    await _db.upsertCicloFisiologico(ciclo.toMap());
    _physioUpdateBus.add(MapEntry(ciclo.dataIso, ciclo));
    final todayKey = DateTime.now().toIso8601String().substring(0, 10);
    if (ciclo.dataIso == todayKey && !_todayStreamController.isClosed) {
      _todayStreamController.add(ciclo);
    }
  }

  void notifyChange(CicloFisiologico ciclo) {
    _physioUpdateBus.add(MapEntry(ciclo.dataIso, ciclo));
    final todayKey = DateTime.now().toIso8601String().substring(0, 10);
    if (ciclo.dataIso == todayKey && !_todayStreamController.isClosed) {
      _todayStreamController.add(ciclo);
    }
  }

  void dispose() {
    _physioUpdateBus.close();
    _todayStreamController.close();
  }
}
