import 'dart:async';
import '../database/database_helper.dart';
import '../models/sonno.dart';
import '../models/ciclo_fisiologico.dart';
import '../models/utente_profilo.dart';
import '../engine/whoop_analytics_engine.dart';
import 'physiology_repository.dart';
import 'user_repository.dart';

/// Repository Sonno con ricalcolo a cascata del Recovery Score.
class SleepRepository {
  final DatabaseHelper _db;
  final PhysiologyRepository? _physiologyRepository;
  final UserRepository? _userRepository;

  final StreamController<MapEntry<String, Sonno?>> _sleepUpdateBus =
      StreamController<MapEntry<String, Sonno?>>.broadcast();
  final StreamController<Sonno?> _sleepStreamController =
      StreamController<Sonno?>.broadcast();

  SleepRepository({
    DatabaseHelper? db,
    PhysiologyRepository? physiologyRepository,
    UserRepository? userRepository,
  })  : _db = db ?? DatabaseHelper(),
        _physiologyRepository = physiologyRepository,
        _userRepository = userRepository;

  /// Osserva lo stato del sonno per una data specifica [dataIso], isolato per data.
  Stream<Sonno?> watchSleep(String dataIso) {
    late StreamController<Sonno?> controller;
    StreamSubscription? sub;

    controller = StreamController<Sonno?>.broadcast(
      onListen: () {
        getByDate(dataIso).then((sleep) {
          if (!controller.isClosed) {
            controller.add(sleep);
          }
        });
        sub = _sleepUpdateBus.stream
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

  void _notifySleepChange(String dateIso, Sonno? sleep) {
    _sleepUpdateBus.add(MapEntry(dateIso, sleep));
    if (!_sleepStreamController.isClosed) {
      _sleepStreamController.add(sleep);
    }
  }

  /// Ritorna tutti i log sonno ordinati per data discendente.
  Future<List<Sonno>> getAll() async {
    final maps = await _db.getAllSonno();
    return maps.map((m) => Sonno.fromMap(m)).toList();
  }

  /// Ritorna il sonno per una data specifica (YYYY-MM-DD).
  Future<Sonno?> getByDate(String dataIso) async {
    final map = await _db.getSonnoByDate(dataIso);
    if (map == null) return null;
    return Sonno.fromMap(map);
  }

  /// Inserisce o aggiorna una sessione di sonno e ricalcola a cascata:
  /// 1. Salva la riga in sonno.
  /// 2. Legge la baseline utente da utente_profilo.
  /// 3. Ricalcola il Recovery Score con WhoopAnalyticsEngine (solo se nightHrvMs e nightRhrBpm sono forniti).
  /// 4. Aggiorna la riga in cicli_fisiologici.
  Future<void> insertOrUpdateSleep(
    Sonno sleep, {
    double? nightHrvMs,
    double? nightRhrBpm,
  }) async {
    // a) Salva la riga nella tabella sonno
    await _db.insertOrUpdateSonno(sleep.toMap());

    final dateKey = sleep.dataIso;

    // IMPORTANTE: Non ricalcolare il recovery se non ci sono dati reali (sonno manuale senza BLE)
    // Se nightHrvMs e nightRhrBpm sono entrambi null, significa che il sonno è stato inserito
    // manualmente senza dati BLE. In questo caso, NON sovrascriviamo il ciclo fisiologico esistente.
    if (nightHrvMs == null && nightRhrBpm == null) {
      _notifySleepChange(dateKey, sleep);
      return;
    }

    // b) Leggi profilo utente per baseline
    UtenteProfilo profile = const UtenteProfilo(
      nome: 'Utente WHOOP',
      eta: 30,
      hrMax: 190,
      hrRestBaseline: 55,
      hrvBaselineMean: 65.0,
      hrvBaselineStd: 15.0,
      rhrBaselineMean: 55.0,
      rhrBaselineStd: 3.5,
      sleepBaselineMin: 480,
    );

    final userRepo = _userRepository;
    if (userRepo != null) {
      final p = await userRepo.getProfile();
      if (p != null) profile = p;
    }

    // Valori notturni (dati di input, NON usare baseline come fallback)
    final hrvVal = nightHrvMs;
    final rhrVal = nightRhrBpm;
    
    // Se mancano HRV o RHR, non possiamo calcolare il recovery
    if (hrvVal == null || rhrVal == null) {
      _notifySleepChange(dateKey, sleep);
      return;
    }
    
    final sleepPerfPct = sleep.sleepPerformancePct ??
        WhoopAnalyticsEngine.calculateSleepPerformancePct(
          actualDurationMin: sleep.durataTotMin.toDouble(),
          sleepNeedMin: profile.sleepBaselineMin.toDouble(),
        );

    // c) Ricalcola il Recovery Score incrociando HRV/RHR con le baseline
    final recoveryScore = WhoopAnalyticsEngine.calculateRecoveryScorePct(
      currentHrvMs: hrvVal,
      baselineHrvMean: profile.hrvBaselineMean,
      baselineHrvStd: profile.hrvBaselineStd,
      currentRhrBpm: rhrVal,
      baselineRhrMean: profile.rhrBaselineMean,
      baselineRhrStd: profile.rhrBaselineStd,
      sleepPerformancePct: sleepPerfPct,
    );

    // d) Aggiorna la riga in cicli_fisiologici
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
      recoveryScore: recoveryScore,
      hrvNotte: hrvVal,
      rhrNotte: rhrVal,
    );

    if (physioRepo != null) {
      await physioRepo.upsert(updatedCiclo);
    } else {
      await _db.upsertCicloFisiologico(updatedCiclo.toMap());
    }

    _notifySleepChange(dateKey, sleep);
  }

  /// Recupera i segmenti dell'ipnogramma persistiti per [dateIso] (STG-07, CHT-02)
  Future<List<Map<String, dynamic>>> getHypnogramSegments(String dateIso) async {
    return await _db.getHypnogramSegments(dateIso);
  }

  /// Recupera i bucket aggregati di frequenza cardiaca intraday (CHT-02)
  Future<List<Map<String, dynamic>?>> getIntradayHrBuckets(
    DateTime start,
    DateTime end, {
    int bucketMinutes = 1,
  }) async {
    return await _db.getIntradayHrBuckets(start, end, bucketMinutes: bucketMinutes);
  }

  /// Calcola la distribuzione del tempo nelle 5 zone cardiache (CHT-02)
  Future<Map<String, dynamic>> getHrZoneDistribution(
    DateTime start,
    DateTime end,
    double maxHr,
  ) async {
    return await _db.getHrZoneDistribution(start, end, maxHr);
  }

  void dispose() {
    _sleepUpdateBus.close();
    _sleepStreamController.close();
  }
}
