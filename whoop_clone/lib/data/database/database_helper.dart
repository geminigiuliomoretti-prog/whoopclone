import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../../core/utils/clock.dart';

/// DatabaseHelper Singleton — Schema v4 per Sprint 2.
/// Gestisce le tabelle fondamentali + telemetria e segmenti sonno
class DatabaseHelper {
  static const String _dbName = 'whoop_clone.db';
  static const int _dbVersion = 19;

  // Nomi Tabelle
  static const String tableUtenteProfilo = 'utente_profilo';
  static const String tableCicliFisiologici = 'cicli_fisiologici';
  static const String tableAllenamenti = 'allenamenti';
  static const String tableSonno = 'sonno';
  static const String tableVociDiario = 'voci_diario';
  static const String tableMessaggiCoachAi = 'messaggi_coach_ai';
  static const String tablePreferenzeDashboard = 'preferenze_dashboard';
  static const String tableAbitudiniCustom = 'abitudini_custom';
  static const String tableMisurazioniStress = 'misurazioni_stress';
  static const String tableImpostazioniSveglia = 'impostazioni_sveglia';
  static const String tableAttivitaTracce = 'attivita_tracce';
  static const String tableTelemetriaGrezza = 'telemetria_grezza';
  static const String tableSleepStageSegments = 'sleep_stage_segments';
  static const String tableTelemetryEpoch30s = 'telemetry_epoch_30s';

  static DatabaseHelper? _instance;
  static Database? _database;
  static Completer<Database>? _initCompleter;

  DatabaseHelper._internal();

  factory DatabaseHelper() {
    _instance ??= DatabaseHelper._internal();
    return _instance!;
  }

  Future<Database> get database async {
    if (_database != null && _database!.isOpen) return _database!;
    if (_initCompleter != null) {
      return _initCompleter!.future;
    }
    final completer = Completer<Database>();
    completer.future.ignore();
    _initCompleter = completer;
    try {
      _database = await _initDatabase();
      completer.complete(_database);
      return _database!;
    } catch (e, st) {
      _initCompleter = null;
      if (!completer.isCompleted) {
        completer.completeError(e, st);
      }
      rethrow;
    } finally {
      _initCompleter = null;
    }
  }

  Future<void> closeDatabase() async {
    if (_database != null && _database!.isOpen) {
      await _database!.close();
      _database = null;
    }
    _initCompleter = null;
  }

  static bool isTestMode = false;

  Future<Database> _initDatabase() async {
    final String path;
    if (isTestMode) {
      path = inMemoryDatabasePath;
    } else {
      final dbPath = await getDatabasesPath();
      path = join(dbPath, _dbName);
    }

    return await openDatabase(
      path,
      version: _dbVersion,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON;');
      },
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // 1. utente_profilo
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableUtenteProfilo (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nome TEXT NOT NULL DEFAULT 'Utente WHOOP',
        eta INTEGER NOT NULL DEFAULT 30,
        hr_max INTEGER NOT NULL DEFAULT 190,
        hr_rest_baseline INTEGER NOT NULL DEFAULT 55,
        hrv_baseline_mean REAL NOT NULL DEFAULT 65.0,
        hrv_baseline_std REAL NOT NULL DEFAULT 15.0,
        rhr_baseline_mean REAL NOT NULL DEFAULT 55.0,
        rhr_baseline_std REAL NOT NULL DEFAULT 3.5,
        sleep_baseline_min INTEGER NOT NULL DEFAULT 480,
        is_bootstrap_completed INTEGER NOT NULL DEFAULT 0,
        bootstrap_timestamp TEXT,
        bootstrap_version TEXT,
        baseline_source TEXT NOT NULL DEFAULT 'INITIAL_PROFILE',
        baseline_sample_count INTEGER NOT NULL DEFAULT 0,
        baseline_calc_period TEXT,
        paired_device_mac TEXT,
        paired_device_name TEXT
      );
    ''');

    // Seed profilo utente iniziale di default (Sprint 2 Spec 4.1)
    await db.insert(tableUtenteProfilo, {
      'id': 1,
      'nome': 'Utente WHOOP',
      'eta': 30,
      'hr_max': 190,
      'hr_rest_baseline': 55,
      'hrv_baseline_mean': 65.0,
      'hrv_baseline_std': 15.0,
      'rhr_baseline_mean': 55.0,
      'rhr_baseline_std': 3.5,
      'sleep_baseline_min': 480,
      'is_bootstrap_completed': 0,
      'baseline_source': 'INITIAL_PROFILE',
      'baseline_sample_count': 0,
    });

    // 2. cicli_fisiologici
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableCicliFisiologici (
        data_iso TEXT PRIMARY KEY,
        strain_giornaliero REAL,
        recovery_score REAL,
        sleep_need_min INTEGER,
        hrv_notte REAL,
        rhr_notte REAL,
        frequenza_respiratoria_rpm REAL,
        temp_cutanea_c REAL,
        spo2_pct REAL,
        fc_max_bpm INTEGER,
        fc_media_bpm INTEGER,
        calorie_tot INTEGER,
        valore_stress_notte REAL,
        provenance TEXT NOT NULL DEFAULT 'REAL'
      );
    ''');

    // 3. allenamenti
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableAllenamenti (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        data_iso TEXT NOT NULL,
        nome_attivita TEXT NOT NULL,
        ora_inizio TEXT NOT NULL,
        ora_fine TEXT NOT NULL,
        durata_min INTEGER NOT NULL,
        hr_media INTEGER,
        hr_max INTEGER,
        strain_attivita REAL,
        calorie INTEGER,
        zone_z1_pct REAL,
        zone_z2_pct REAL,
        zone_z3_pct REAL,
        zone_z4_pct REAL,
        zone_z5_pct REAL
      );
    ''');

    // 4. sonno
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableSonno (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        data_iso TEXT NOT NULL,
        ora_inizio TEXT NOT NULL,
        ora_fine TEXT NOT NULL,
        durata_tot_min INTEGER NOT NULL,
        sonno_profondo_min INTEGER NOT NULL,
        sonno_rem_min INTEGER NOT NULL,
        efficienza_pct REAL,
        sleep_performance_pct REAL,
        regolarita_sonno_pct REAL,
        provenance TEXT NOT NULL DEFAULT 'REAL'
      );
    ''');

    // 5. voci_diario
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableVociDiario (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        data_iso TEXT NOT NULL,
        chiave_domanda TEXT NOT NULL,
        risposta_bool INTEGER NOT NULL DEFAULT 0,
        note TEXT
      );
    ''');

    // 6. messaggi_coach_ai
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableMessaggiCoachAi (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        timestamp TEXT NOT NULL,
        mittente TEXT NOT NULL,
        testo_messaggio TEXT NOT NULL
      );
    ''');

    // 7. preferenze_dashboard
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tablePreferenzeDashboard (
        key TEXT PRIMARY KEY,
        position INTEGER NOT NULL,
        enabled INTEGER NOT NULL DEFAULT 1
      );
    ''');

    // 8. abitudini_custom
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableAbitudiniCustom (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nome TEXT NOT NULL,
        tipo_risposta TEXT NOT NULL DEFAULT 'boolean'
      );
    ''');

    // 9. misurazioni_stress
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableMisurazioniStress (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        data_iso TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        timestamp_utc_ms INTEGER,
        valore_stress REAL NOT NULL,
        hrv_ms REAL,
        bpm INTEGER
      );
    ''');

    // 10. impostazioni_sveglia
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableImpostazioniSveglia (
        id INTEGER PRIMARY KEY,
        is_enabled INTEGER NOT NULL DEFAULT 0,
        alarm_hour INTEGER NOT NULL DEFAULT 7,
        alarm_minute INTEGER NOT NULL DEFAULT 0,
        selected_mode INTEGER NOT NULL DEFAULT 1,
        target_goal_idx INTEGER NOT NULL DEFAULT 1,
        haptic_intensity INTEGER NOT NULL DEFAULT 1
      );
    ''');
    await db.insert(tableImpostazioniSveglia, {
      'id': 1,
      'is_enabled': 0,
      'alarm_hour': 7,
      'alarm_minute': 0,
      'selected_mode': 1,
      'target_goal_idx': 1,
      'haptic_intensity': 1,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);

    // 11. attivita_tracce
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableAttivitaTracce (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        workout_id INTEGER NOT NULL,
        timestamp TEXT NOT NULL,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        altitude REAL NOT NULL,
        speed_kmh REAL NOT NULL
      );
    ''');

    // 12. telemetria_grezza
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableTelemetriaGrezza (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        timestamp TEXT NOT NULL,
        timestamp_utc_ms INTEGER,
        device_id TEXT,
        session_id TEXT,
        sequence_number INTEGER,
        packet_type TEXT,
        raw_payload BLOB,
        decoder_version TEXT,
        crc_valid INTEGER DEFAULT 1,
        is_valid INTEGER DEFAULT 1,
        received_at TEXT,
        device_timestamp TEXT,
        ingest_latency_ms INTEGER,
        duplicate INTEGER DEFAULT 0,
        source TEXT DEFAULT 'REAL_STREAM',
        quality TEXT DEFAULT 'VALID',
        bpm INTEGER,
        rmssd_ms REAL,
        rr_ms REAL,
        rr_intervals_json TEXT,
        accel_enmo REAL,
        motion_var REAL,
        skin_temp_celsius REAL,
        skin_temp_raw INTEGER,
        spo2_pct REAL,
        spo2_ratio_r REAL,
        resp_rate REAL,
        resp_power REAL
      );
    ''');

    // 13. sleep_stage_segments (STG-07)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableSleepStageSegments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sonno_id INTEGER,
        start_utc_ms INTEGER,
        end_utc_ms INTEGER,
        stage TEXT,
        confidence REAL
      );
    ''');

    // 14. telemetry_epoch_30s (Fase 3: DAT-05)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableTelemetryEpoch30s (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        start_utc_ms INTEGER NOT NULL,
        end_utc_ms INTEGER NOT NULL,
        hr_mean REAL,
        hr_min INTEGER,
        hr_max INTEGER,
        enmo_mean REAL,
        sample_count INTEGER NOT NULL,
        valid_rr_count INTEGER NOT NULL DEFAULT 0,
        rmssd REAL,
        coverage_pct REAL NOT NULL DEFAULT 100.0
      );
    ''');

    // Indici per velocizzare filtri temporali e prevenire Full Table Scan
    await db.execute('CREATE INDEX IF NOT EXISTS idx_stress_data_iso ON $tableMisurazioniStress (data_iso);');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_stress_timestamp ON $tableMisurazioniStress (timestamp);');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_stress_utc ON $tableMisurazioniStress (timestamp_utc_ms);');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_telemetria_timestamp ON $tableTelemetriaGrezza (timestamp);');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_telemetria_utc ON $tableTelemetriaGrezza (timestamp_utc_ms);');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_telemetria_seq ON $tableTelemetriaGrezza (sequence_number);');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_telemetria_session ON $tableTelemetriaGrezza (session_id);');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_attivita_tracce_workout ON $tableAttivitaTracce (workout_id);');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_cicli_data_iso ON $tableCicliFisiologici (data_iso);');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_sonno_data_iso ON $tableSonno (data_iso);');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_allenamenti_data_iso ON $tableAllenamenti (data_iso);');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_sleep_stage_segments_sonno ON $tableSleepStageSegments (sonno_id);');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_sleep_stage_segments_time ON $tableSleepStageSegments (start_utc_ms, end_utc_ms);');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_telemetry_epoch_time ON $tableTelemetryEpoch30s (start_utc_ms, end_utc_ms);');
  }

  Future<void> _safeExecuteAlter(Database db, String sql) async {
    try {
      await db.execute(sql);
    } catch (e) {
      debugPrint('[DatabaseHelper] Upgrade step notice (may already exist): $e');
    }
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 4) {
      await db.execute('DROP TABLE IF EXISTS $tableUtenteProfilo;');
      await db.execute('DROP TABLE IF EXISTS $tableCicliFisiologici;');
      await db.execute('DROP TABLE IF EXISTS $tableAllenamenti;');
      await db.execute('DROP TABLE IF EXISTS $tableSonno;');
      await db.execute('DROP TABLE IF EXISTS $tableVociDiario;');
      await db.execute('DROP TABLE IF EXISTS $tableMessaggiCoachAi;');
      await _onCreate(db, newVersion);
    }
    if (oldVersion < 5) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS $tablePreferenzeDashboard (
          key TEXT PRIMARY KEY,
          position INTEGER NOT NULL,
          enabled INTEGER NOT NULL DEFAULT 1
        );
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS $tableAbitudiniCustom (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          nome TEXT NOT NULL,
          tipo_risposta TEXT NOT NULL DEFAULT 'boolean'
        );
      ''');
    }
    if (oldVersion < 6) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS $tableMisurazioniStress (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          data_iso TEXT NOT NULL,
          timestamp TEXT NOT NULL,
          valore_stress REAL NOT NULL,
          hrv_ms REAL,
          bpm INTEGER
        );
      ''');
    }
    if (oldVersion < 7) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS $tableImpostazioniSveglia (
          id INTEGER PRIMARY KEY,
          is_enabled INTEGER NOT NULL DEFAULT 0,
          alarm_hour INTEGER NOT NULL DEFAULT 7,
          alarm_minute INTEGER NOT NULL DEFAULT 0,
          selected_mode INTEGER NOT NULL DEFAULT 1,
          target_goal_idx INTEGER NOT NULL DEFAULT 1,
          haptic_intensity INTEGER NOT NULL DEFAULT 1
        );
      ''');
      await db.insert(tableImpostazioniSveglia, {
        'id': 1,
        'is_enabled': 0,
        'alarm_hour': 7,
        'alarm_minute': 0,
        'selected_mode': 1,
        'target_goal_idx': 1,
        'haptic_intensity': 1,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    if (oldVersion < 8) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS $tableAttivitaTracce (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          workout_id INTEGER NOT NULL,
          timestamp TEXT NOT NULL,
          latitude REAL NOT NULL,
          longitude REAL NOT NULL,
          altitude REAL NOT NULL,
          speed_kmh REAL NOT NULL
        );
      ''');
    }
    if (oldVersion < 9) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS $tableTelemetriaGrezza (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          timestamp TEXT NOT NULL,
          bpm INTEGER NOT NULL,
          rr_ms REAL,
          motion_var REAL DEFAULT 0.002
        );
      ''');
    }
    if (oldVersion < 10) {
      await _safeExecuteAlter(db, 'ALTER TABLE $tableCicliFisiologici ADD COLUMN frequenza_respiratoria_rpm REAL;');
      await _safeExecuteAlter(db, 'ALTER TABLE $tableCicliFisiologici ADD COLUMN temp_cutanea_c REAL;');
      await _safeExecuteAlter(db, 'ALTER TABLE $tableCicliFisiologici ADD COLUMN spo2_pct REAL;');
      await _safeExecuteAlter(db, 'ALTER TABLE $tableCicliFisiologici ADD COLUMN fc_max_bpm INTEGER;');
      await _safeExecuteAlter(db, 'ALTER TABLE $tableCicliFisiologici ADD COLUMN fc_media_bpm INTEGER;');
      await _safeExecuteAlter(db, 'ALTER TABLE $tableTelemetriaGrezza ADD COLUMN timestamp_utc_ms INTEGER;');
      await _safeExecuteAlter(db, 'ALTER TABLE $tableTelemetriaGrezza ADD COLUMN rr_intervals_json TEXT;');
      await _safeExecuteAlter(db, 'ALTER TABLE $tableTelemetriaGrezza ADD COLUMN accel_enmo REAL DEFAULT 0.002;');
      await _safeExecuteAlter(db, 'ALTER TABLE $tableTelemetriaGrezza ADD COLUMN skin_temp_celsius REAL;');
      await _safeExecuteAlter(db, 'ALTER TABLE $tableTelemetriaGrezza ADD COLUMN spo2_pct REAL;');
    }
    if (oldVersion < 11) {
      await _safeExecuteAlter(db, 'ALTER TABLE $tableTelemetriaGrezza ADD COLUMN skin_temp_raw INTEGER;');
      await _safeExecuteAlter(db, 'ALTER TABLE $tableTelemetriaGrezza ADD COLUMN spo2_ratio_r REAL;');
      await _safeExecuteAlter(db, 'ALTER TABLE $tableTelemetriaGrezza ADD COLUMN resp_rate REAL;');
      await _safeExecuteAlter(db, 'ALTER TABLE $tableTelemetriaGrezza ADD COLUMN resp_power REAL;');
    }
    if (oldVersion < 12) {
      await _safeExecuteAlter(db, 'ALTER TABLE $tableCicliFisiologici ADD COLUMN valore_stress_notte REAL;');
    }
    if (oldVersion < 13) {
      await _safeExecuteAlter(db, 'CREATE INDEX IF NOT EXISTS idx_stress_data_iso ON $tableMisurazioniStress (data_iso);');
      await _safeExecuteAlter(db, 'CREATE INDEX IF NOT EXISTS idx_stress_timestamp ON $tableMisurazioniStress (timestamp);');
      await _safeExecuteAlter(db, 'CREATE INDEX IF NOT EXISTS idx_telemetria_timestamp ON $tableTelemetriaGrezza (timestamp);');
      await _safeExecuteAlter(db, 'CREATE INDEX IF NOT EXISTS idx_telemetria_utc ON $tableTelemetriaGrezza (timestamp_utc_ms);');
      await _safeExecuteAlter(db, 'CREATE INDEX IF NOT EXISTS idx_attivita_tracce_workout ON $tableAttivitaTracce (workout_id);');
      await _safeExecuteAlter(db, 'CREATE INDEX IF NOT EXISTS idx_cicli_data_iso ON $tableCicliFisiologici (data_iso);');
      await _safeExecuteAlter(db, 'CREATE INDEX IF NOT EXISTS idx_sonno_data_iso ON $tableSonno (data_iso);');
      await _safeExecuteAlter(db, 'CREATE INDEX IF NOT EXISTS idx_allenamenti_data_iso ON $tableAllenamenti (data_iso);');
    }
    if (oldVersion < 14) {
      await _safeExecuteAlter(db, 'ALTER TABLE $tableUtenteProfilo ADD COLUMN is_bootstrap_completed INTEGER NOT NULL DEFAULT 0;');
      await _safeExecuteAlter(db, 'ALTER TABLE $tableUtenteProfilo ADD COLUMN bootstrap_timestamp TEXT;');
      await _safeExecuteAlter(db, 'ALTER TABLE $tableUtenteProfilo ADD COLUMN bootstrap_version TEXT;');
      await _safeExecuteAlter(db, 'ALTER TABLE $tableUtenteProfilo ADD COLUMN baseline_source TEXT DEFAULT \'INITIAL_PROFILE\';');
      await _safeExecuteAlter(db, 'ALTER TABLE $tableUtenteProfilo ADD COLUMN baseline_sample_count INTEGER DEFAULT 0;');
      await _safeExecuteAlter(db, 'ALTER TABLE $tableUtenteProfilo ADD COLUMN baseline_calc_period TEXT;');
      await _safeExecuteAlter(db, 'ALTER TABLE $tableUtenteProfilo ADD COLUMN paired_device_mac TEXT;');
      await _safeExecuteAlter(db, 'ALTER TABLE $tableUtenteProfilo ADD COLUMN paired_device_name TEXT;');
      await _safeExecuteAlter(db, 'ALTER TABLE $tableCicliFisiologici ADD COLUMN provenance TEXT DEFAULT \'REAL\';');
      await _safeExecuteAlter(db, 'ALTER TABLE $tableSonno ADD COLUMN regolarita_sonno_pct REAL;');
      await _safeExecuteAlter(db, 'ALTER TABLE $tableSonno ADD COLUMN provenance TEXT DEFAULT \'REAL\';');
    }
    if (oldVersion < 15) {
      await _safeExecuteAlter(db, 'ALTER TABLE $tableTelemetriaGrezza ADD COLUMN device_id TEXT;');
      await _safeExecuteAlter(db, 'ALTER TABLE $tableTelemetriaGrezza ADD COLUMN session_id TEXT;');
      await _safeExecuteAlter(db, 'ALTER TABLE $tableTelemetriaGrezza ADD COLUMN sequence_number INTEGER;');
      await _safeExecuteAlter(db, 'ALTER TABLE $tableTelemetriaGrezza ADD COLUMN packet_type TEXT;');
      await _safeExecuteAlter(db, 'ALTER TABLE $tableTelemetriaGrezza ADD COLUMN raw_payload BLOB;');
      await _safeExecuteAlter(db, 'ALTER TABLE $tableTelemetriaGrezza ADD COLUMN decoder_version TEXT;');
      await _safeExecuteAlter(db, 'ALTER TABLE $tableTelemetriaGrezza ADD COLUMN crc_valid INTEGER DEFAULT 1;');
      await _safeExecuteAlter(db, 'ALTER TABLE $tableTelemetriaGrezza ADD COLUMN is_valid INTEGER DEFAULT 1;');
      await _safeExecuteAlter(db, 'ALTER TABLE $tableTelemetriaGrezza ADD COLUMN received_at TEXT;');
      await _safeExecuteAlter(db, 'ALTER TABLE $tableTelemetriaGrezza ADD COLUMN device_timestamp TEXT;');
      await _safeExecuteAlter(db, 'ALTER TABLE $tableTelemetriaGrezza ADD COLUMN ingest_latency_ms INTEGER;');
      await _safeExecuteAlter(db, 'ALTER TABLE $tableTelemetriaGrezza ADD COLUMN duplicate INTEGER DEFAULT 0;');
      await _safeExecuteAlter(db, 'ALTER TABLE $tableTelemetriaGrezza ADD COLUMN source TEXT DEFAULT \'REAL_STREAM\';');
      await _safeExecuteAlter(db, 'ALTER TABLE $tableTelemetriaGrezza ADD COLUMN quality TEXT DEFAULT \'VALID\';');
      await _safeExecuteAlter(db, 'ALTER TABLE $tableTelemetriaGrezza ADD COLUMN rmssd_ms REAL;');
      await _safeExecuteAlter(db, 'CREATE INDEX IF NOT EXISTS idx_telemetria_seq ON $tableTelemetriaGrezza (sequence_number);');
      await _safeExecuteAlter(db, 'CREATE INDEX IF NOT EXISTS idx_telemetria_session ON $tableTelemetriaGrezza (session_id);');
    }
    if (oldVersion < 16) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS $tableSleepStageSegments (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          sonno_id INTEGER,
          start_utc_ms INTEGER,
          end_utc_ms INTEGER,
          stage TEXT,
          confidence REAL
        );
      ''');
      await _safeExecuteAlter(db, 'CREATE INDEX IF NOT EXISTS idx_sleep_stage_segments_sonno ON $tableSleepStageSegments (sonno_id);');
      await _safeExecuteAlter(db, 'CREATE INDEX IF NOT EXISTS idx_sleep_stage_segments_time ON $tableSleepStageSegments (start_utc_ms, end_utc_ms);');
    }
    if (oldVersion < 18) {
      await _safeExecuteAlter(db, 'ALTER TABLE $tableMisurazioniStress ADD COLUMN timestamp_utc_ms INTEGER;');
      await _safeExecuteAlter(db, 'CREATE INDEX IF NOT EXISTS idx_stress_utc ON $tableMisurazioniStress (timestamp_utc_ms);');
    }
    if (oldVersion < 19) {
      await _safeExecuteAlter(db, '''
        CREATE TABLE IF NOT EXISTS $tableTelemetryEpoch30s (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          start_utc_ms INTEGER NOT NULL,
          end_utc_ms INTEGER NOT NULL,
          hr_mean REAL,
          hr_min INTEGER,
          hr_max INTEGER,
          enmo_mean REAL,
          sample_count INTEGER NOT NULL,
          valid_rr_count INTEGER NOT NULL DEFAULT 0,
          rmssd REAL,
          coverage_pct REAL NOT NULL DEFAULT 100.0
        );
      ''');
      await _safeExecuteAlter(db, 'CREATE INDEX IF NOT EXISTS idx_telemetry_epoch_time ON $tableTelemetryEpoch30s (start_utc_ms, end_utc_ms);');
    }
  }

  // ─────────────────────────────────────────────────────────────
  // Misurazioni Stress CRUD
  // ─────────────────────────────────────────────────────────────

  Future<int> insertMisurazioneStress(
    String dataIso,
    double valoreStress,
    double hrvMs,
    int bpm, {
    String? timestamp,
    int? timestampUtcMs,
  }) async {
    final db = await database;
    final ts = timestamp != null
        ? (DateTime.tryParse(timestamp)?.toUtc() ?? Clock.current.now().toUtc())
        : Clock.current.now().toUtc();
    final ms = timestampUtcMs ?? ts.millisecondsSinceEpoch;
    return await db.insert(tableMisurazioniStress, {
      'data_iso': dataIso,
      'timestamp': ts.toIso8601String(),
      'timestamp_utc_ms': ms,
      'valore_stress': valoreStress,
      'hrv_ms': hrvMs,
      'bpm': bpm,
    });
  }

  Future<List<Map<String, dynamic>>> getMisurazioniStressByDate(String dataIso) async {
    final db = await database;
    return await db.query(
      tableMisurazioniStress,
      where: 'data_iso = ?',
      whereArgs: [dataIso],
      orderBy: 'id ASC',
    );
  }

  // ─────────────────────────────────────────────────────────────
  // 1. Utente Profilo CRUD
  // ─────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>?> getUserProfile() async {
    final db = await database;
    final rows = await db.query(tableUtenteProfilo, limit: 1);
    return rows.isNotEmpty ? rows.first : null;
  }

  Future<void> updateUserProfile(Map<String, dynamic> data) async {
    final db = await database;
    final count = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM $tableUtenteProfilo'),
    );
    if (count == null || count == 0) {
      await db.insert(tableUtenteProfilo, data);
    } else {
      await db.update(
        tableUtenteProfilo,
        data,
        where: 'id = ?',
        whereArgs: [data['id'] ?? 1],
      );
    }
  }

  // ─────────────────────────────────────────────────────────────
  // 2. Cicli Fisiologici CRUD
  // ─────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>?> getCicloByDate(String dataIso) async {
    final db = await database;
    final rows = await db.query(
      tableCicliFisiologici,
      where: 'data_iso = ?',
      whereArgs: [dataIso],
      limit: 1,
    );
    return rows.isNotEmpty ? rows.first : null;
  }

  Future<List<Map<String, dynamic>>> getAllCicli() async {
    final db = await database;
    return await db.query(tableCicliFisiologici, orderBy: 'data_iso DESC');
  }

  Future<void> upsertCicloFisiologico(Map<String, dynamic> data) async {
    final db = await database;
    await db.insert(
      tableCicliFisiologici,
      data,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // ─────────────────────────────────────────────────────────────
  // 3. Allenamenti CRUD
  // ─────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getAllenamentiByDate(String dataIso) async {
    final db = await database;
    return await db.query(
      tableAllenamenti,
      where: 'data_iso = ?',
      whereArgs: [dataIso],
      orderBy: 'ora_inizio ASC',
    );
  }

  Future<List<Map<String, dynamic>>> getAllAllenamenti() async {
    final db = await database;
    return await db.query(tableAllenamenti, orderBy: 'ora_inizio DESC');
  }

  Future<int> insertAllenamento(Map<String, dynamic> data) async {
    final db = await database;
    return await db.insert(
      tableAllenamenti,
      data,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // ─────────────────────────────────────────────────────────────
  // 4. Sonno CRUD
  // ─────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>?> getSonnoByDate(String dataIso) async {
    final db = await database;
    final rows = await db.query(
      tableSonno,
      where: 'data_iso = ?',
      whereArgs: [dataIso],
      orderBy: 'ora_inizio DESC',
      limit: 1,
    );
    return rows.isNotEmpty ? rows.first : null;
  }

  Future<List<Map<String, dynamic>>> getAllSonno() async {
    final db = await database;
    return await db.query(tableSonno, orderBy: 'ora_inizio DESC');
  }

  Future<int> insertOrUpdateSonno(Map<String, dynamic> data) async {
    final db = await database;
    return await db.transaction<int>((txn) async {
      final dateIso = data['data_iso'];
      if (dateIso != null) {
        await txn.delete(
          tableSonno,
          where: 'data_iso = ?',
          whereArgs: [dateIso],
        );
      }
      return await txn.insert(
        tableSonno,
        data,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }

  // ─────────────────────────────────────────────────────────────
  // 4b. Segmenti Ipnogramma CRUD (STG-07 & CHT-02)
  // ─────────────────────────────────────────────────────────────

  Future<int> insertSleepStageSegment(Map<String, dynamic> data) async {
    final db = await database;
    return await db.insert(tableSleepStageSegments, data);
  }

  Future<void> insertSleepStageSegments(int sonnoId, List<Map<String, dynamic>> segments) async {
    final db = await database;
    final batch = db.batch();
    for (final s in segments) {
      batch.insert(tableSleepStageSegments, {
        'sonno_id': sonnoId,
        'start_utc_ms': s['start_utc_ms'],
        'end_utc_ms': s['end_utc_ms'],
        'stage': s['stage'],
        'confidence': s['confidence'] ?? 1.0,
      });
    }
    await batch.commit(noResult: true);
  }

  Future<List<Map<String, dynamic>>> getHypnogramSegments(String dateIso) async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT 
        s.id,
        s.sonno_id,
        s.start_utc_ms,
        s.end_utc_ms,
        s.stage,
        s.confidence
      FROM $tableSleepStageSegments s
      INNER JOIN $tableSonno sn ON sn.id = s.sonno_id
      WHERE sn.data_iso = ?
      ORDER BY s.start_utc_ms ASC
    ''', [dateIso]);

    if (rows.isNotEmpty) return rows;

    // Fallback: se i segmenti sono stati salvati senza un record sonno associato o con data diretta
    final dayStart = DateTime.tryParse(dateIso)?.toUtc();
    if (dayStart != null) {
      final startMs = DateTime.utc(dayStart.year, dayStart.month, dayStart.day).millisecondsSinceEpoch;
      final endMs = startMs + 86400000;
      return await db.query(
        tableSleepStageSegments,
        where: 'start_utc_ms >= ? AND start_utc_ms < ?',
        whereArgs: [startMs, endMs],
        orderBy: 'start_utc_ms ASC',
      );
    }

    return [];
  }

  Future<List<Map<String, dynamic>>> getHypnogramSegmentsBySonnoId(int sonnoId) async {
    final db = await database;
    return await db.query(
      tableSleepStageSegments,
      where: 'sonno_id = ?',
      whereArgs: [sonnoId],
      orderBy: 'start_utc_ms ASC',
    );
  }

  // ─────────────────────────────────────────────────────────────
  // 5. Voci Diario CRUD
  // ─────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getVociDiarioByDate(String dataIso) async {
    final db = await database;
    return await db.query(
      tableVociDiario,
      where: 'data_iso = ?',
      whereArgs: [dataIso],
    );
  }

  Future<List<Map<String, dynamic>>> getAllVociDiario() async {
    final db = await database;
    return await db.query(tableVociDiario, orderBy: 'id ASC');
  }

  Future<int> insertVoceDiario(Map<String, dynamic> data) async {
    final db = await database;
    return await db.insert(
      tableVociDiario,
      data,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // ─────────────────────────────────────────────────────────────
  // 6. Coach AI Messages CRUD
  // ─────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getCoachMessages() async {
    final db = await database;
    return await db.query(
      tableMessaggiCoachAi,
      orderBy: 'id ASC',
    );
  }

  Future<void> insertCoachMessage(String mittente, String testo) async {
    final db = await database;
    await db.insert(
      tableMessaggiCoachAi,
      {
        'timestamp': DateTime.now().toIso8601String(),
        'mittente': mittente,
        'testo_messaggio': testo,
      },
    );
  }

  // ─────────────────────────────────────────────────────────────
  // 7. Preferenze Dashboard & Abitudini Custom CRUD
  // ─────────────────────────────────────────────────────────────

  Future<List<String>> getEnabledDashboardTiles() async {
    final db = await database;
    final res = await db.query(
      tablePreferenzeDashboard,
      where: 'enabled = 1',
      orderBy: 'position ASC',
    );
    if (res.isEmpty) return [];
    return res.map((r) => r['key'] as String).toList();
  }

  Future<void> saveDashboardTiles(List<String> enabledKeys) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete(tablePreferenzeDashboard);
      for (int i = 0; i < enabledKeys.length; i++) {
        await txn.insert(tablePreferenzeDashboard, {
          'key': enabledKeys[i],
          'position': i,
          'enabled': 1,
        });
      }
    });
  }

  Future<List<Map<String, dynamic>>> getAbitudiniCustom() async {
    final db = await database;
    return await db.query(tableAbitudiniCustom, orderBy: 'id ASC');
  }

  Future<int> insertAbitudineCustom(String nome, String tipoRisposta) async {
    final db = await database;
    return await db.insert(tableAbitudiniCustom, {
      'nome': nome,
      'tipo_risposta': tipoRisposta,
    });
  }

  // ─────────────────────────────────────────────────────────────
  // 9. Impostazioni Sveglia CRUD
  // ─────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getImpostazioniSveglia() async {
    final db = await database;
    final rows = await db.query(tableImpostazioniSveglia, where: 'id = 1');
    if (rows.isNotEmpty) {
      return rows.first;
    }
    return {
      'id': 1,
      'is_enabled': 0,
      'alarm_hour': 7,
      'alarm_minute': 0,
      'selected_mode': 1,
      'target_goal_idx': 1,
      'haptic_intensity': 1,
    };
  }

  Future<void> saveImpostazioniSveglia({
    required bool isEnabled,
    required int hour,
    required int minute,
    required int mode,
    required int goalIdx,
    required int intensity,
  }) async {
    final db = await database;
    await db.insert(
      tableImpostazioniSveglia,
      {
        'id': 1,
        'is_enabled': isEnabled ? 1 : 0,
        'alarm_hour': hour,
        'alarm_minute': minute,
        'selected_mode': mode,
        'target_goal_idx': goalIdx,
        'haptic_intensity': intensity,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // ─────────────────────────────────────────────────────────────
  // 10. Tracce GPS Attività CRUD
  // ─────────────────────────────────────────────────────────────

  Future<int> insertTracciaPoint({
    required int workoutId,
    required double latitude,
    required double longitude,
    required double altitude,
    required double speedKmh,
  }) async {
    final db = await database;
    return await db.insert(tableAttivitaTracce, {
      'workout_id': workoutId,
      'timestamp': DateTime.now().toIso8601String(),
      'latitude': latitude,
      'longitude': longitude,
      'altitude': altitude,
      'speed_kmh': speedKmh,
    });
  }

  Future<List<Map<String, dynamic>>> getTracciaPoints(int workoutId) async {
    final db = await database;
    return await db.query(
      tableAttivitaTracce,
      where: 'workout_id = ?',
      whereArgs: [workoutId],
      orderBy: 'id ASC',
    );
  }

  // ─────────────────────────────────────────────────────────────
  // 11. Telemetria Grezza CRUD (BPM & HRV R-R Reali)
  // ─────────────────────────────────────────────────────────────

  Future<int> insertTelemetriaPoint({
    int? bpm,
    double? rmssdMs,
    double? rrMs,
    String? rrIntervalsJson,
    double? motionVar = 0.0,
    double? accelEnmo,
    double? skinTempCelsius,
    int? skinTempRaw,
    double? spo2Pct,
    double? spo2RatioR,
    double? respRate,
    double? respPower,
    DateTime? timestamp,
    int? timestampUtcMs,
    String? deviceId,
    String? sessionId,
    int? sequenceNumber,
    String? packetType,
    List<int>? rawPayload,
    String? decoderVersion,
    bool crcValid = true,
    bool isValid = true,
    DateTime? receivedAt,
    DateTime? deviceTimestamp,
    int? ingestLatencyMs,
    bool duplicate = false,
    String source = 'REAL_STREAM',
    String quality = 'VALID',
  }) async {
    final db = await database;
    final ts = (timestamp ?? Clock.current.now()).toUtc();
    final ms = timestampUtcMs ?? ts.millisecondsSinceEpoch;
    final rxAt = (receivedAt ?? Clock.current.now()).toUtc();
    return await db.insert(tableTelemetriaGrezza, {
      'timestamp': ts.toIso8601String(),
      'timestamp_utc_ms': ms,
      'device_id': deviceId,
      'session_id': sessionId,
      'sequence_number': sequenceNumber,
      'packet_type': packetType,
      'raw_payload': rawPayload != null ? Uint8List.fromList(rawPayload) : null,
      'decoder_version': decoderVersion,
      'crc_valid': crcValid ? 1 : 0,
      'is_valid': isValid ? 1 : 0,
      'received_at': rxAt.toIso8601String(),
      'device_timestamp': deviceTimestamp?.toUtc().toIso8601String(),
      'ingest_latency_ms': ingestLatencyMs,
      'duplicate': duplicate ? 1 : 0,
      'source': source,
      'quality': quality,
      'bpm': bpm,
      'rmssd_ms': rmssdMs ?? (rrMs != null && rrMs < 300 ? rrMs : null),
      'rr_ms': rrMs,
      'rr_intervals_json': rrIntervalsJson,
      'accel_enmo': accelEnmo,
      'motion_var': motionVar,
      'skin_temp_celsius': skinTempCelsius,
      'skin_temp_raw': skinTempRaw,
      'spo2_pct': spo2Pct,
      'spo2_ratio_r': spo2RatioR,
      'resp_rate': respRate,
      'resp_power': respPower,
    });
  }

  Future<List<Map<String, dynamic>>> getTelemetriaInTimeRange(DateTime start, DateTime end) async {
    final db = await database;
    final startMs = start.toUtc().millisecondsSinceEpoch;
    final endMs = end.toUtc().millisecondsSinceEpoch;

    final List<Map<String, dynamic>> maps = await db.query(
      tableTelemetriaGrezza,
      where: 'timestamp_utc_ms >= ? AND timestamp_utc_ms <= ?',
      whereArgs: [startMs, endMs],
      orderBy: 'timestamp_utc_ms ASC, id ASC',
    );

    return maps;
  }

  // ─────────────────────────────────────────────────────────────
  // 11b. Query SQL di Aggregazione Intraday (CHT-02)
  // ─────────────────────────────────────────────────────────────

  /// Raggruppa i dati di telemetria cardiaca grezza in bucket temporali di [bucketMinutes] minuti
  /// per evitare di caricare decine di migliaia di punti grezzi in RAM.
  /// Se un bucket non ha dati, restituisce esplicitamente `null` (gap reale).
  Future<List<Map<String, dynamic>?>> getIntradayHrBuckets(
    DateTime start,
    DateTime end, {
    int bucketMinutes = 1,
  }) async {
    final db = await database;
    final startMs = start.toUtc().millisecondsSinceEpoch;
    final endMs = end.toUtc().millisecondsSinceEpoch;
    final bucketMs = bucketMinutes * 60 * 1000;

    if (endMs <= startMs || bucketMs <= 0) return [];

    final rows = await db.rawQuery('''
      SELECT
        CAST(COALESCE(timestamp_utc_ms, strftime('%s', timestamp) * 1000) / ? AS INTEGER) AS bucket_idx,
        MIN(bpm) AS min_bpm,
        ROUND(AVG(bpm)) AS avg_bpm,
        MAX(bpm) AS max_bpm,
        COUNT(bpm) AS count_samples
      FROM $tableTelemetriaGrezza
      WHERE COALESCE(timestamp_utc_ms, strftime('%s', timestamp) * 1000) >= ?
        AND COALESCE(timestamp_utc_ms, strftime('%s', timestamp) * 1000) <= ?
        AND bpm IS NOT NULL AND bpm > 0
      GROUP BY bucket_idx
      ORDER BY bucket_idx ASC
    ''', [bucketMs, startMs, endMs]);

    final Map<int, Map<String, dynamic>> mapped = {};
    for (final r in rows) {
      final idx = (r['bucket_idx'] as num?)?.toInt();
      if (idx != null) {
        mapped[idx] = r;
      }
    }

    final startBucket = startMs ~/ bucketMs;
    final endBucket = endMs ~/ bucketMs;
    final List<Map<String, dynamic>?> result = [];

    for (int b = startBucket; b <= endBucket; b++) {
      final row = mapped[b];
      if (row != null && (row['count_samples'] as num? ?? 0) > 0) {
        result.add({
          'bucket_idx': b,
          'timestamp': DateTime.fromMillisecondsSinceEpoch(b * bucketMs, isUtc: true),
          'timestamp_utc_ms': b * bucketMs,
          'min': (row['min_bpm'] as num?)?.toInt(),
          'avg': (row['avg_bpm'] as num?)?.toInt(),
          'max': (row['max_bpm'] as num?)?.toInt(),
          'count': (row['count_samples'] as num?)?.toInt() ?? 0,
        });
      } else {
        result.add(null);
      }
    }

    return result;
  }

  /// Calcola il tempo e la distribuzione percentuale nelle 5 zone cardiache WHOOP nel range [start, end].
  Future<Map<String, dynamic>> getHrZoneDistribution(
    DateTime start,
    DateTime end,
    double maxHr,
  ) async {
    final db = await database;
    final startMs = start.toUtc().millisecondsSinceEpoch;
    final endMs = end.toUtc().millisecondsSinceEpoch;

    if (endMs <= startMs || maxHr <= 0) {
      return {
        'total_samples': 0,
        'total_seconds': 0,
        'z1_seconds': 0,
        'z2_seconds': 0,
        'z3_seconds': 0,
        'z4_seconds': 0,
        'z5_seconds': 0,
        'below_z1_seconds': 0,
        'z1_pct': 0.0,
        'z2_pct': 0.0,
        'z3_pct': 0.0,
        'z4_pct': 0.0,
        'z5_pct': 0.0,
      };
    }

    final z1Min = maxHr * 0.50;
    final z2Min = maxHr * 0.60;
    final z3Min = maxHr * 0.70;
    final z4Min = maxHr * 0.80;
    final z5Min = maxHr * 0.90;

    final rows = await db.rawQuery('''
      SELECT
        COUNT(CASE WHEN bpm >= ? AND bpm < ? THEN 1 END) AS count_z1,
        COUNT(CASE WHEN bpm >= ? AND bpm < ? THEN 1 END) AS count_z2,
        COUNT(CASE WHEN bpm >= ? AND bpm < ? THEN 1 END) AS count_z3,
        COUNT(CASE WHEN bpm >= ? AND bpm < ? THEN 1 END) AS count_z4,
        COUNT(CASE WHEN bpm >= ? THEN 1 END) AS count_z5,
        COUNT(CASE WHEN bpm < ? THEN 1 END) AS count_below_z1,
        COUNT(bpm) AS total_count
      FROM $tableTelemetriaGrezza
      WHERE COALESCE(timestamp_utc_ms, strftime('%s', timestamp) * 1000) >= ?
        AND COALESCE(timestamp_utc_ms, strftime('%s', timestamp) * 1000) <= ?
        AND bpm IS NOT NULL AND bpm > 0
    ''', [
      z1Min, z2Min,
      z2Min, z3Min,
      z3Min, z4Min,
      z4Min, z5Min,
      z5Min,
      z1Min,
      startMs, endMs,
    ]);

    if (rows.isEmpty) {
      return {
        'total_samples': 0,
        'total_seconds': 0,
        'z1_seconds': 0,
        'z2_seconds': 0,
        'z3_seconds': 0,
        'z4_seconds': 0,
        'z5_seconds': 0,
        'below_z1_seconds': 0,
        'z1_pct': 0.0,
        'z2_pct': 0.0,
        'z3_pct': 0.0,
        'z4_pct': 0.0,
        'z5_pct': 0.0,
      };
    }

    final r = rows.first;
    final totalCount = (r['total_count'] as num?)?.toInt() ?? 0;
    final countZ1 = (r['count_z1'] as num?)?.toInt() ?? 0;
    final countZ2 = (r['count_z2'] as num?)?.toInt() ?? 0;
    final countZ3 = (r['count_z3'] as num?)?.toInt() ?? 0;
    final countZ4 = (r['count_z4'] as num?)?.toInt() ?? 0;
    final countZ5 = (r['count_z5'] as num?)?.toInt() ?? 0;
    final countBelowZ1 = (r['count_below_z1'] as num?)?.toInt() ?? 0;

    final double z1Pct = totalCount > 0 ? (countZ1 / totalCount) * 100.0 : 0.0;
    final double z2Pct = totalCount > 0 ? (countZ2 / totalCount) * 100.0 : 0.0;
    final double z3Pct = totalCount > 0 ? (countZ3 / totalCount) * 100.0 : 0.0;
    final double z4Pct = totalCount > 0 ? (countZ4 / totalCount) * 100.0 : 0.0;
    final double z5Pct = totalCount > 0 ? (countZ5 / totalCount) * 100.0 : 0.0;

    return {
      'total_samples': totalCount,
      'total_seconds': totalCount,
      'z1_seconds': countZ1,
      'z2_seconds': countZ2,
      'z3_seconds': countZ3,
      'z4_seconds': countZ4,
      'z5_seconds': countZ5,
      'below_z1_seconds': countBelowZ1,
      'z1_pct': double.parse(z1Pct.toStringAsFixed(1)),
      'z2_pct': double.parse(z2Pct.toStringAsFixed(1)),
      'z3_pct': double.parse(z3Pct.toStringAsFixed(1)),
      'z4_pct': double.parse(z4Pct.toStringAsFixed(1)),
      'z5_pct': double.parse(z5Pct.toStringAsFixed(1)),
    };
  }

  /// Pruning di manutenzione: elimina i record obsoleti da telemetria_grezza
  /// più vecchi di [daysToKeep] giorni per prevenire la crescita incontrollata del file SQLite.
  Future<int> pruneOldTelemetry({int daysToKeep = 7}) async {
    final db = await database;
    final cutoff = DateTime.now().toUtc().subtract(Duration(days: daysToKeep));
    final cutoffMs = cutoff.millisecondsSinceEpoch;
    final cutoffIso = cutoff.toIso8601String();

    return await db.delete(
      tableTelemetriaGrezza,
      where: 'timestamp_utc_ms < ? OR (timestamp_utc_ms IS NULL AND timestamp < ?)',
      whereArgs: [cutoffMs, cutoffIso],
    );
  }

  // ─────────────────────────────────────────────────────────────
  // 11c. Epoche Telemetriche 30s CRUD (Fase 3: DAT-05)
  // ─────────────────────────────────────────────────────────────

  Future<int> insertTelemetryEpoch({
    required int startUtcMs,
    required int endUtcMs,
    double? hrMean,
    int? hrMin,
    int? hrMax,
    double? enmoMean,
    required int sampleCount,
    int validRrCount = 0,
    double? rmssd,
    double coveragePct = 100.0,
  }) async {
    final db = await database;
    return await db.insert(tableTelemetryEpoch30s, {
      'start_utc_ms': startUtcMs,
      'end_utc_ms': endUtcMs,
      'hr_mean': hrMean,
      'hr_min': hrMin,
      'hr_max': hrMax,
      'enmo_mean': enmoMean,
      'sample_count': sampleCount,
      'valid_rr_count': validRrCount,
      'rmssd': rmssd,
      'coverage_pct': coveragePct,
    });
  }

  Future<List<Map<String, dynamic>>> getTelemetryEpochs({
    required int startUtcMs,
    required int endUtcMs,
  }) async {
    final db = await database;
    return await db.query(
      tableTelemetryEpoch30s,
      where: 'start_utc_ms >= ? AND end_utc_ms <= ?',
      whereArgs: [startUtcMs, endUtcMs],
      orderBy: 'start_utc_ms ASC',
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Utilità
  // ─────────────────────────────────────────────────────────────

  Future<void> clearAllTables() async {
    final db = await database;
    try {
      await db.execute('DELETE FROM $tableTelemetryEpoch30s');
      await db.execute('DELETE FROM $tableSleepStageSegments');
      await db.execute('DELETE FROM $tablePreferenzeDashboard');
      await db.execute('DELETE FROM $tableAbitudiniCustom');
      await db.execute('DELETE FROM $tableMessaggiCoachAi');
      await db.execute('DELETE FROM $tableVociDiario');
      await db.execute('DELETE FROM $tableSonno');
      await db.execute('DELETE FROM $tableAllenamenti');
      await db.execute('DELETE FROM $tableCicliFisiologici');
      await db.execute('DELETE FROM $tableMisurazioniStress');
      await db.execute('DELETE FROM $tableImpostazioniSveglia');
      await db.execute('DELETE FROM $tableAttivitaTracce');
      await db.execute('DELETE FROM $tableTelemetriaGrezza');
      await db.execute('DELETE FROM $tableUtenteProfilo');
      await db.insert(tableUtenteProfilo, {
        'id': 1,
        'nome': 'Utente WHOOP',
        'eta': 30,
        'hr_max': 190,
        'hr_rest_baseline': 55,
        'hrv_baseline_mean': 65.0,
        'hrv_baseline_std': 15.0,
        'rhr_baseline_mean': 55.0,
        'rhr_baseline_std': 3.5,
        'sleep_baseline_min': 480,
        'is_bootstrap_completed': 0,
        'baseline_source': 'INITIAL_PROFILE',
        'baseline_sample_count': 0,
      });
    } catch (e, stack) {
      debugPrint('[DatabaseHelper] Error clearing database tables: $e\n$stack');
      rethrow;
    }
  }
}
