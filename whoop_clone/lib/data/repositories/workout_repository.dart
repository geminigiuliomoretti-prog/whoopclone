import 'dart:async';
import 'package:flutter/foundation.dart';
import '../database/database_helper.dart';
import '../models/allenamento.dart';
import '../models/ciclo_fisiologico.dart';
import '../engine/whoop_analytics_engine.dart';
import 'physiology_repository.dart';
import 'user_repository.dart';

/// Repository Allenamenti con ricalcolo a cascata dello Strain Giornaliero e Sleep Need.
class WorkoutRepository {
  final DatabaseHelper _db;
  final PhysiologyRepository? _physiologyRepository;
  final UserRepository? _userRepository;

  final StreamController<MapEntry<String, List<Allenamento>>> _workoutUpdateBus =
      StreamController<MapEntry<String, List<Allenamento>>>.broadcast();
  final StreamController<List<Allenamento>> _workoutsStreamController =
      StreamController<List<Allenamento>>.broadcast();

  WorkoutRepository({
    DatabaseHelper? db,
    PhysiologyRepository? physiologyRepository,
    UserRepository? userRepository,
  })  : _db = db ?? DatabaseHelper(),
        _physiologyRepository = physiologyRepository,
        _userRepository = userRepository;

  /// Osserva gli allenamenti per una data specifica [dataIso], isolato per data.
  Stream<List<Allenamento>> watchWorkouts(String dataIso) {
    late StreamController<List<Allenamento>> controller;
    StreamSubscription? sub;

    controller = StreamController<List<Allenamento>>.broadcast(
      onListen: () {
        getByDate(dataIso).then((list) {
          if (!controller.isClosed) {
            controller.add(list);
          }
        });
        sub = _workoutUpdateBus.stream
            .where((entry) => entry.key == dataIso)
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

  void _notifyWorkoutsChange(String dateIso, List<Allenamento> workouts) {
    _workoutUpdateBus.add(MapEntry(dateIso, workouts));
    if (!_workoutsStreamController.isClosed) {
      _workoutsStreamController.add(workouts);
    }
  }

  /// Ritorna tutti gli allenamenti ordinati per data discendente.
  Future<List<Allenamento>> getAll() async {
    final maps = await _db.getAllAllenamenti();
    return maps.map((m) => Allenamento.fromMap(m)).toList();
  }

  /// Ritorna gli allenamenti per una data specifica (formato YYYY-MM-DD).
  Future<List<Allenamento>> getByDate(String dataIso) async {
    final maps = await _db.getAllenamentiByDate(dataIso);
    return maps.map((m) => Allenamento.fromMap(m)).toList();
  }

  /// Inserisce un allenamento e ricalcola a cascata:
  /// 1. Salva riga in allenamenti.
  /// 2. Leggi tutti gli allenamenti del giorno.
  /// 3. Calcola Day Strain via WhoopAnalyticsEngine.calculateDayStrain.
  /// 4. Calcola Sleep Need per la notte via WhoopAnalyticsEngine.calculateSleepNeedMinutes.
  /// 5. Salva/aggiorna record in cicli_fisiologici.
  Future<void> insertWorkout(Allenamento allenamento) async {
    final startStr = allenamento.oraInizioAllenamento.toIso8601String();
    final endStr = allenamento.oraFineAllenamento.toIso8601String();

    try {
      final db = await _db.database;
      final existingMaps = await db.query(
        DatabaseHelper.tableAllenamenti,
        where: 'ora_inizio <= ? AND ora_fine >= ?',
        whereArgs: [endStr, startStr],
      );

      if (existingMaps.isNotEmpty) {
        final existingWorkout = Allenamento.fromMap(existingMaps.first);
        final newStart = allenamento.oraInizioAllenamento.isBefore(existingWorkout.oraInizioAllenamento)
            ? allenamento.oraInizioAllenamento
            : existingWorkout.oraInizioAllenamento;
        final newEnd = allenamento.oraFineAllenamento.isAfter(existingWorkout.oraFineAllenamento)
            ? allenamento.oraFineAllenamento
            : existingWorkout.oraFineAllenamento;
        final newDur = (newEnd.difference(newStart).inMinutes).clamp(1, 1440);

        final merged = existingWorkout.copyWith(
          oraInizioAllenamento: newStart,
          oraFineAllenamento: newEnd,
          durataMin: newDur,
          hrMax: (allenamento.hrMax ?? 0) > (existingWorkout.hrMax ?? 0) ? allenamento.hrMax : existingWorkout.hrMax,
          hrMedia: (((allenamento.hrMedia ?? 0) + (existingWorkout.hrMedia ?? 0)) / 2).round(),
          strainAttivita: (allenamento.strainAttivita ?? 0.0) > (existingWorkout.strainAttivita ?? 0.0)
              ? allenamento.strainAttivita
              : existingWorkout.strainAttivita,
          calorie: (allenamento.calorie ?? 0) > (existingWorkout.calorie ?? 0) ? allenamento.calorie : existingWorkout.calorie,
        );

        await db.update(
          DatabaseHelper.tableAllenamenti,
          merged.toMap(),
          where: 'id = ?',
          whereArgs: [existingWorkout.id],
        );
      } else {
        await _db.insertAllenamento(allenamento.toMap());
      }
    } catch (e, stack) {
      debugPrint('[WorkoutRepository] Deduplication update failed, falling back to insert: $e\n$stack');
      await _db.insertAllenamento(allenamento.toMap());
    }

    final dateKey = allenamento.dataIso;

    // b) Leggi tutti gli allenamenti del giorno
    final todayWorkouts = await getByDate(dateKey);

    // c) Calcola lo Strain Giornaliero via WhoopAnalyticsEngine
    final dayStrain = WhoopAnalyticsEngine.calculateDayStrain(todayWorkouts);

    // Recupera baseline sonno dell'utente se disponibile
    double baselineSleepMin = 480.0;
    final userRepo = _userRepository;
    if (userRepo != null) {
      final userProfile = await userRepo.getProfile();
      if (userProfile != null) {
        baselineSleepMin = userProfile.sleepBaselineMin.toDouble();
      }
    }

    // d) Calcola il nuovo Sleep Need per la notte
    final sleepNeedMin = WhoopAnalyticsEngine.calculateSleepNeedMinutes(
      baselineNeedMin: baselineSleepMin,
      dayStrain: dayStrain,
    );

    // Calcola calorie totali e max HR
    int totalCal = 0;
    for (final w in todayWorkouts) {
      totalCal += w.calorie ?? 0;
    }

    // e) Leggi ciclo fisiologico esistente o crea nuovo
    CicloFisiologico? existingCiclo;
    final physioRepo = _physiologyRepository;
    if (physioRepo != null) {
      existingCiclo = await physioRepo.getByDate(dateKey);
    } else {
      final map = await _db.getCicloByDate(dateKey);
      if (map != null) existingCiclo = CicloFisiologico.fromMap(map);
    }

    final updatedCiclo = (existingCiclo ?? CicloFisiologico(dataIso: dateKey)).copyWith(
      dataIso: dateKey,
      strainGiornaliero: dayStrain,
      sleepNeedMin: sleepNeedMin,
      calorieTot: totalCal > 0 ? totalCal : (existingCiclo?.calorieTot),
    );

    // Salva o aggiorna record in cicli_fisiologici
    if (physioRepo != null) {
      await physioRepo.upsert(updatedCiclo);
    } else {
      await _db.upsertCicloFisiologico(updatedCiclo.toMap());
    }

    _notifyWorkoutsChange(dateKey, todayWorkouts);
  }

  void dispose() {
    _workoutUpdateBus.close();
    _workoutsStreamController.close();
  }
}
