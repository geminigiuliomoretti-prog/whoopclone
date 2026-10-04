import 'dart:async';
import '../database/database_helper.dart';
import '../models/ciclo_fisiologico.dart';
import '../models/allenamento.dart';
import '../models/voce_diario.dart';
import '../models/sonno.dart';
import 'whoop_repository.dart';
import 'user_repository.dart';
import 'physiology_repository.dart';
import 'workout_repository.dart';
import 'sleep_repository.dart';
import 'journal_repository.dart';

/// Implementazione concreta SQLite del WhoopRepository.
/// Sostituisce fisicamente il MockRepository e si interfaccia esclusivamente con il DB SQLite.
class SqliteWhoopRepository implements WhoopRepository {
  final DatabaseHelper _dbHelper;

  late final UserRepository userRepository;
  late final PhysiologyRepository physiologyRepository;
  late final WorkoutRepository workoutRepository;
  late final SleepRepository sleepRepository;
  late final JournalRepository journalRepository;

  SqliteWhoopRepository({DatabaseHelper? dbHelper})
      : _dbHelper = dbHelper ?? DatabaseHelper() {
    userRepository = UserRepository(db: _dbHelper);
    physiologyRepository = PhysiologyRepository(db: _dbHelper);
    workoutRepository = WorkoutRepository(
      db: _dbHelper,
      physiologyRepository: physiologyRepository,
      userRepository: userRepository,
    );
    sleepRepository = SleepRepository(
      db: _dbHelper,
      physiologyRepository: physiologyRepository,
      userRepository: userRepository,
    );
    journalRepository = JournalRepository(db: _dbHelper);
  }

  @override
  Future<void> initializeAndSeedDatabase() async {
    // Inizializza il DB. Il profilo di default è creato in _onCreate di DatabaseHelper.
    // Nessun dato fittizio / mock viene inserito se il DB è vuoto.
    await _dbHelper.database;
  }

  // --- Cicli Fisiologici ---

  @override
  Future<List<CicloFisiologico>> getCicliFisiologici() async {
    return await physiologyRepository.getAll();
  }

  @override
  Future<CicloFisiologico?> getUltimoCicloFisiologico() async {
    final list = await getCicliFisiologici();
    return list.isNotEmpty ? list.first : null;
  }

  Future<CicloFisiologico?> getCicloPerData(String dataIso) async {
    return await physiologyRepository.getByDate(dataIso);
  }

  @override
  Future<void> insertCicloFisiologico(CicloFisiologico ciclo) async {
    await physiologyRepository.upsert(ciclo);
  }

  // --- Allenamenti ---

  @override
  Future<List<Allenamento>> getAllenamenti() async {
    return await workoutRepository.getAll();
  }

  @override
  Future<List<Allenamento>> getAllenamentiPerCiclo(String oraInizioCiclo) async {
    final dataIso = oraInizioCiclo.length >= 10 ? oraInizioCiclo.substring(0, 10) : oraInizioCiclo;
    return await workoutRepository.getByDate(dataIso);
  }

  @override
  Future<void> insertAllenamento(Allenamento allenamento) async {
    await workoutRepository.insertWorkout(allenamento);
  }

  // --- Voci Diario ---

  @override
  Future<List<VoceDiario>> getVociDiario() async {
    return await journalRepository.getAll();
  }

  @override
  Future<List<VoceDiario>> getVociDiarioPerCiclo(String oraInizioCiclo) async {
    final dataIso = oraInizioCiclo.length >= 10 ? oraInizioCiclo.substring(0, 10) : oraInizioCiclo;
    return await journalRepository.getByDate(dataIso);
  }

  @override
  Future<void> insertVoceDiario(VoceDiario voce) async {
    await journalRepository.insertVoceDiario(voce);
  }

  // --- Sonno ---

  @override
  Future<List<Sonno>> getSonnoLogs() async {
    return await sleepRepository.getAll();
  }

  @override
  Future<Sonno?> getSonnoPerCiclo(String oraInizioCiclo) async {
    final dataIso = oraInizioCiclo.length >= 10 ? oraInizioCiclo.substring(0, 10) : oraInizioCiclo;
    return await sleepRepository.getByDate(dataIso);
  }

  @override
  Future<void> insertSonno(Sonno sonno) async {
    await sleepRepository.insertOrUpdateSleep(sonno);
  }

  Future<int> getStreakDays() async {
    final cicli = await getCicliFisiologici();
    return calculateStreakDays(cicli);
  }

  /// Calcola i giorni di striscia (streak) consecutivi attivi terminanti oggi o ieri
  static int calculateStreakDays(List<CicloFisiologico> cicli) {
    if (cicli.isEmpty) return 0;

    final Set<String> activeDates = {};
    for (final c in cicli) {
      final hasData = (c.strainGiornaliero != null && c.strainGiornaliero! > 0) ||
          c.recoveryScore != null ||
          c.hrvNotte != null ||
          c.rhrNotte != null;
      if (hasData) {
        activeDates.add(c.dataIso);
      }
    }

    if (activeDates.isEmpty) return 0;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    String formatIso(DateTime d) =>
        '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

    final todayStr = formatIso(today);
    final yesterdayStr = formatIso(yesterday);

    DateTime checkDate;
    if (activeDates.contains(todayStr)) {
      checkDate = today;
    } else if (activeDates.contains(yesterdayStr)) {
      checkDate = yesterday;
    } else {
      return 0;
    }

    int streak = 0;
    while (activeDates.contains(formatIso(checkDate))) {
      streak++;
      checkDate = checkDate.subtract(const Duration(days: 1));
    }

    return streak;
  }

  Future<Map<String, List<double>>> getHistoricalVitals30d() async {
    final cicli = await getCicliFisiologici();
    final Map<String, List<double>> vitals = {
      'hrv': [],
      'rhr': [],
      'resp_rate': [],
      'spo2': [],
      'temp': [],
    };

    for (var c in cicli.reversed) {
      if (c.vfcMs != null) vitals['hrv']!.add(c.vfcMs!);
      if (c.fcrBpm != null) vitals['rhr']!.add(c.fcrBpm!.toDouble());
      if (c.frequenzaRespiratoriaRpm != null && c.frequenzaRespiratoriaRpm! >= 7.0 && c.frequenzaRespiratoriaRpm! <= 24.0) {
        vitals['resp_rate']!.add(c.frequenzaRespiratoriaRpm!);
      }
      if (c.spo2Pct != null && c.spo2Pct! >= 80.0 && c.spo2Pct! <= 100.0) {
        vitals['spo2']!.add(c.spo2Pct!);
      }
      if (c.tempCutaneaC != null && c.tempCutaneaC!.abs() <= 3.0) {
        vitals['temp']!.add(c.tempCutaneaC!);
      }
    }
    return vitals;
  }
}
