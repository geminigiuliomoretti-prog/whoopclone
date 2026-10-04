import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

/// DatabaseHelper Singleton — Schema v4 per Sprint 2.
/// Gestisce le 5 tabelle fondamentali + messaggi AI Coach:
/// 1. utente_profilo
/// 2. cicli_fisiologici
/// 3. allenamenti
/// 4. sonno
/// 5. voci_diario
/// 6. messaggi_coach_ai
class DatabaseHelper {
  static const String _dbName = 'whoop_clone.db';
  static const int _dbVersion = 14;

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
        bpm INTEGER NOT NULL,
        rr_ms REAL,
        rr_intervals_json TEXT,
        accel_enmo REAL DEFAULT 0.002,
        motion_var REAL DEFAULT 0.002,
        skin_temp_celsius REAL,
        skin_temp_raw INTEGER,
        spo2_pct REAL,
        spo2_ratio_r REAL,
        resp_rate REAL,
        resp_power REAL
      );
    ''');

    // Indici per velocizzare filtri temporali e prevenire Full Table Scan
    await db.execute('CREATE INDEX IF NOT EXISTS idx_stress_data_iso ON $tableMisurazioniStress (data_iso);');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_stress_timestamp ON $tableMisurazioniStress (timestamp);');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_telemetria_timestamp ON $tableTelemetriaGrezza (timestamp);');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_telemetria_utc ON $tableTelemetriaGrezza (timestamp_utc_ms);');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_attivita_tracce_workout ON $tableAttivitaTracce (workout_id);');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_cicli_data_iso ON $tableCicliFisiologici (data_iso);');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_sonno_data_iso ON $tableSonno (data_iso);');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_allenamenti_data_iso ON $tableAllenamenti (data_iso);');
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
      try { await db.execute('ALTER TABLE $tableCicliFisiologici ADD COLUMN frequenza_respiratoria_rpm REAL;'); } catch (_) {}
      try { await db.execute('ALTER TABLE $tableCicliFisiologici ADD COLUMN temp_cutanea_c REAL;'); } catch (_) {}
      try { await db.execute('ALTER TABLE $tableCicliFisiologici ADD COLUMN spo2_pct REAL;'); } catch (_) {}
      try { await db.execute('ALTER TABLE $tableCicliFisiologici ADD COLUMN fc_max_bpm INTEGER;'); } catch (_) {}
      try { await db.execute('ALTER TABLE $tableCicliFisiologici ADD COLUMN fc_media_bpm INTEGER;'); } catch (_) {}
      try { await db.execute('ALTER TABLE $tableTelemetriaGrezza ADD COLUMN timestamp_utc_ms INTEGER;'); } catch (_) {}
      try { await db.execute('ALTER TABLE $tableTelemetriaGrezza ADD COLUMN rr_intervals_json TEXT;'); } catch (_) {}
      try { await db.execute('ALTER TABLE $tableTelemetriaGrezza ADD COLUMN accel_enmo REAL DEFAULT 0.002;'); } catch (_) {}
      try { await db.execute('ALTER TABLE $tableTelemetriaGrezza ADD COLUMN skin_temp_celsius REAL;'); } catch (_) {}
      try { await db.execute('ALTER TABLE $tableTelemetriaGrezza ADD COLUMN spo2_pct REAL;'); } catch (_) {}
    }
    if (oldVersion < 11) {
      try { await db.execute('ALTER TABLE $tableTelemetriaGrezza ADD COLUMN skin_temp_raw INTEGER;'); } catch (_) {}
      try { await db.execute('ALTER TABLE $tableTelemetriaGrezza ADD COLUMN spo2_ratio_r REAL;'); } catch (_) {}
      try { await db.execute('ALTER TABLE $tableTelemetriaGrezza ADD COLUMN resp_rate REAL;'); } catch (_) {}
      try { await db.execute('ALTER TABLE $tableTelemetriaGrezza ADD COLUMN resp_power REAL;'); } catch (_) {}
    }
    if (oldVersion < 12) {
      try { await db.execute('ALTER TABLE $tableCicliFisiologici ADD COLUMN valore_stress_notte REAL;'); } catch (_) {}
    }
    if (oldVersion < 13) {
      try {
        await db.execute('CREATE INDEX IF NOT EXISTS idx_stress_data_iso ON $tableMisurazioniStress (data_iso);');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_stress_timestamp ON $tableMisurazioniStress (timestamp);');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_telemetria_timestamp ON $tableTelemetriaGrezza (timestamp);');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_telemetria_utc ON $tableTelemetriaGrezza (timestamp_utc_ms);');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_attivita_tracce_workout ON $tableAttivitaTracce (workout_id);');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_cicli_data_iso ON $tableCicliFisiologici (data_iso);');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_sonno_data_iso ON $tableSonno (data_iso);');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_allenamenti_data_iso ON $tableAllenamenti (data_iso);');
      } catch (_) {}
    }
    if (oldVersion < 14) {
      try { await db.execute('ALTER TABLE $tableUtenteProfilo ADD COLUMN is_bootstrap_completed INTEGER NOT NULL DEFAULT 0;'); } catch (_) {}
      try { await db.execute('ALTER TABLE $tableUtenteProfilo ADD COLUMN bootstrap_timestamp TEXT;'); } catch (_) {}
      try { await db.execute('ALTER TABLE $tableUtenteProfilo ADD COLUMN bootstrap_version TEXT;'); } catch (_) {}
      try { await db.execute('ALTER TABLE $tableUtenteProfilo ADD COLUMN baseline_source TEXT DEFAULT \'INITIAL_PROFILE\';'); } catch (_) {}
      try { await db.execute('ALTER TABLE $tableUtenteProfilo ADD COLUMN baseline_sample_count INTEGER DEFAULT 0;'); } catch (_) {}
      try { await db.execute('ALTER TABLE $tableUtenteProfilo ADD COLUMN baseline_calc_period TEXT;'); } catch (_) {}
      try { await db.execute('ALTER TABLE $tableUtenteProfilo ADD COLUMN paired_device_mac TEXT;'); } catch (_) {}
      try { await db.execute('ALTER TABLE $tableUtenteProfilo ADD COLUMN paired_device_name TEXT;'); } catch (_) {}
      try { await db.execute('ALTER TABLE $tableCicliFisiologici ADD COLUMN provenance TEXT DEFAULT \'REAL\';'); } catch (_) {}
      try { await db.execute('ALTER TABLE $tableSonno ADD COLUMN regolarita_sonno_pct REAL;'); } catch (_) {}
      try { await db.execute('ALTER TABLE $tableSonno ADD COLUMN provenance TEXT DEFAULT \'REAL\';'); } catch (_) {}
    }
  }

  // ─────────────────────────────────────────────────────────────
  // Misurazioni Stress CRUD
  // ─────────────────────────────────────────────────────────────

  Future<int> insertMisurazioneStress(String dataIso, double valoreStress, double hrvMs, int bpm, {String? timestamp}) async {
    final db = await database;
    return await db.insert(tableMisurazioniStress, {
      'data_iso': dataIso,
      'timestamp': timestamp ?? DateTime.now().toIso8601String(),
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
    required int bpm,
    double? rrMs,
    double motionVar = 0.002,
    double? accelEnmo,
    double? skinTempCelsius,
    int? skinTempRaw,
    double? spo2Pct,
    double? spo2RatioR,
    double? respRate,
    double? respPower,
    DateTime? timestamp,
    int? timestampUtcMs,
  }) async {
    final db = await database;
    final ts = (timestamp ?? DateTime.now()).toUtc();
    final ms = timestampUtcMs ?? ts.millisecondsSinceEpoch;
    return await db.insert(tableTelemetriaGrezza, {
      'timestamp': ts.toIso8601String(),
      'timestamp_utc_ms': ms,
      'bpm': bpm,
      'rr_ms': rrMs,
      'accel_enmo': accelEnmo ?? motionVar,
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
  // Utilità
  // ─────────────────────────────────────────────────────────────

  Future<void> clearAllTables() async {
    final db = await database;
    try { await db.execute('DELETE FROM $tablePreferenzeDashboard'); } catch (_) {}
    try { await db.execute('DELETE FROM $tableAbitudiniCustom'); } catch (_) {}
    try { await db.execute('DELETE FROM $tableMessaggiCoachAi'); } catch (_) {}
    try { await db.execute('DELETE FROM $tableVociDiario'); } catch (_) {}
    try { await db.execute('DELETE FROM $tableSonno'); } catch (_) {}
    try { await db.execute('DELETE FROM $tableAllenamenti'); } catch (_) {}
    try { await db.execute('DELETE FROM $tableCicliFisiologici'); } catch (_) {}
    try { await db.execute('DELETE FROM $tableMisurazioniStress'); } catch (_) {}
    try { await db.execute('DELETE FROM $tableImpostazioniSveglia'); } catch (_) {}
    try { await db.execute('DELETE FROM $tableAttivitaTracce'); } catch (_) {}
    try { await db.execute('DELETE FROM $tableTelemetriaGrezza'); } catch (_) {}
    try {
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
    } catch (_) {}
  }
}
