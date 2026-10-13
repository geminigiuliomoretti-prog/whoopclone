import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:whoop_clone/data/database/database_helper.dart';
import 'package:whoop_clone/data/models/ciclo_fisiologico.dart';
import 'package:whoop_clone/data/models/sonno.dart';
import 'package:whoop_clone/data/services/overnight_sleep_engine.dart';
import 'package:whoop_clone/data/services/posterior_sleep_detector.dart';
import 'package:whoop_clone/data/services/baseline_calculator.dart';
import 'package:whoop_clone/data/services/telemetry_ingestion_service.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    DatabaseHelper.isTestMode = true;
  });

  tearDown(() async {
    await DatabaseHelper().clearAllTables();
  });

  group('Forensic Sleep, HRV & Baselines Fixes Verification', () {
    // 1. Inattività serale sul divano vs sonno effettivo (21:15 cena, 21:30-22:30 divano, 22:45 letto)
    test('1. Distingue inattività serale sul divano (21:30-22:30) dal sonno reale a letto (22:45-07:00)', () {
      final detector = PosteriorSleepDetector();
      final engine = OvernightSleepEngine();
      final records = <Map<String, dynamic>>[];

      // 21:15 - 21:30: Cena (movimento attivo, HR = 85 bpm)
      final dtCena = DateTime.utc(2026, 10, 8, 21, 15);
      for (int m = 0; m < 15; m++) {
        records.add({
          'timestamp_utc_ms': dtCena.add(Duration(minutes: m)).millisecondsSinceEpoch,
          'bpm': 85.0,
          'hr': 85.0,
          'accel_enmo': 0.080,
          'motion_var': 0.080,
        });
      }

      // 21:30 - 22:30: Sul divano guardando la TV (bassa accelerazione, ma HR da sveglio = 70 bpm, non al nadir)
      final dtDivano = DateTime.utc(2026, 10, 8, 21, 30);
      for (int m = 0; m < 60; m++) {
        records.add({
          'timestamp_utc_ms': dtDivano.add(Duration(minutes: m)).millisecondsSinceEpoch,
          'bpm': 70.0,
          'hr': 70.0,
          'accel_enmo': 0.008, // Immobile sul divano
          'motion_var': 0.008,
        });
      }

      // 22:30 - 22:45: Movimento per andare a letto (lavarsi i denti, coricarsi, HR = 80 bpm, moto)
      final dtPreLetto = DateTime.utc(2026, 10, 8, 22, 30);
      for (int m = 0; m < 15; m++) {
        records.add({
          'timestamp_utc_ms': dtPreLetto.add(Duration(minutes: m)).millisecondsSinceEpoch,
          'bpm': 80.0,
          'hr': 80.0,
          'accel_enmo': 0.060,
          'motion_var': 0.060,
        });
      }

      // 22:45 - 07:00: Sonno effettivo a letto (HR scende a 52 bpm vicino alla baseline 50 bpm, moto < 0.005)
      final dtLetto = DateTime.utc(2026, 10, 8, 22, 45);
      final totalSleepMin = 495; // 8h 15m fino alle 07:00
      for (int m = 0; m < totalSleepMin; m++) {
        records.add({
          'timestamp_utc_ms': dtLetto.add(Duration(minutes: m)).millisecondsSinceEpoch,
          'bpm': 52.0,
          'hr': 52.0,
          'accel_enmo': 0.003,
          'motion_var': 0.003,
        });
      }

      // 07:00 - 07:30: Risveglio attivo del mattino
      final dtSveglia = DateTime.utc(2026, 10, 9, 7, 0);
      for (int m = 0; m < 30; m++) {
        records.add({
          'timestamp_utc_ms': dtSveglia.add(Duration(minutes: m)).millisecondsSinceEpoch,
          'bpm': 88.0,
          'hr': 88.0,
          'accel_enmo': 0.120,
          'motion_var': 0.120,
        });
      }

      // PosteriorSleepDetector analysis
      final sessions = detector.analyzeTelemetryRecords(records, rhrBaseline: 52.0);
      expect(sessions.isNotEmpty, isTrue);
      final detected = sessions.first;

      // Verifica che il sonno NON parta alle 21:15 o 21:30, ma attorno alle 22:45
      expect(detected.startTime.isAfter(DateTime.utc(2026, 10, 8, 22, 30)), isTrue);

      // OvernightSleepEngine boundary detection
      final boundaries = engine.detectSleepBoundaries(records, rhrBaseline: 52.0, daytimeMeanHr: 75.0);
      expect(boundaries['hasSleep'], isTrue);
      final startIdx = boundaries['startIndex'] as int;
      final startRecordTime = DateTime.fromMillisecondsSinceEpoch(records[startIdx]['timestamp_utc_ms'] as int, isUtc: true);
      expect(startRecordTime.isAfter(DateTime.utc(2026, 10, 8, 22, 30)), isTrue);
    });

    // 2. VFC (HRV): Nessuna sovrastima quadratica a 72ms su valori pre-calcolati a 66ms
    test('2. Calcolo VFC su campioni SWS pre-calcolati a 66ms produce esattamente 66ms (nessun salto a 72ms)', () async {
      final engine = OvernightSleepEngine();
      final List<Map<String, dynamic>> records = [];

      final baseTime = DateTime.utc(2026, 10, 8, 23, 0);

      // 60 minuti di SWS con RMSSD del sensore variabile fisiologicamente attorno a 66.0 ms (es. 62, 66, 70)
      // La cui media aritmetica è esattamente 66.0 ms
      final List<double> sampleRmssd = [62.0, 66.0, 70.0, 66.0, 62.0, 70.0];
      for (int i = 0; i < 120; i++) {
        final val = sampleRmssd[i % sampleRmssd.length];
        records.add({
          'timestamp': baseTime.add(Duration(seconds: i * 30)).toIso8601String(),
          'timestamp_utc_ms': baseTime.add(Duration(seconds: i * 30)).millisecondsSinceEpoch,
          'motion_var': 0.001,
          'hr': 50.0,
          'bpm': 50.0,
          'rmssd': val,
          'rmssd_ms': val,
          'resp_power': 0.85,
          'resp_rate': 14.0,
        });
      }

      final result = await engine.processNightlyTelemetry(
        rawTelemetryRecords: records,
        userBaseline30d: {
          'rhr_mean': 50.0,
          'rmssd_mean': 66.0,
          'rmssd_std': 8.0,
          'baseline_temp_celsius': 36.5,
        },
      );

      final extractedHrv = (result['hrv_rmssd_ms'] as num?)?.toDouble();
      expect(extractedHrv, isNotNull);
      // Il valore deve essere esattamente la media aritmetica 66.0 ms, non il valore quadratico sovrastimato ~72 ms
      expect(extractedHrv, equals(66.0));
    });

    // 3. Acquisizione e validazione Temperatura Cutanea (AS6221)
    test('3. Decodifica e validazione temperatura cutanea sensore AS6221', () async {
      final dbHelper = DatabaseHelper();
      final ingestion = TelemetryIngestionService(dbHelper: dbHelper);

      // Crea payload 96-byte simulando raw temp 4672 (4672 * 0.0078125 = 36.5 °C)
      final raw = List<int>.filled(96, 0);
      raw[0] = 0xAA; // sync
      raw[8] = 60;   // HR 60
      raw[28] = 4672 & 0xFF;        // raw LSB
      raw[29] = (4672 >> 8) & 0xFF; // raw MSB

      final result = await ingestion.ingestRawPacket(
        raw,
        customTimestamp: DateTime.now(),
      );

      expect(result.accepted, isTrue);
      expect(result.telemetry, isNotNull);
      expect(result.telemetry!.skinTempCelsius, equals(36.5));

      // Verifica persistenza su SQLite
      final rows = await (await dbHelper.database).query(
        DatabaseHelper.tableTelemetriaGrezza,
        where: 'id = ?',
        whereArgs: [result.telemetry!.id],
      );
      expect(rows.isNotEmpty, isTrue);
      expect(rows.first['skin_temp_raw'], equals(4672));
      expect((rows.first['skin_temp_celsius'] as num).toDouble(), equals(36.5));
    });

    // 4. Baseline Sleep Performance: baseline iniziale 74%, finestra 30 giorni e deduplicazione per notte
    test('4. Baseline Sleep Performance iniziale a 74%, finestra rolling 30 giorni e deduplicazione notti', () {
      // Test A: Nessun dato storico -> Baseline iniziale a 74.0%
      final emptyBaselines = BaselineCalculator.calculateAllBaselines(cycles: [], sleeps: []);
      expect(emptyBaselines.containsKey('sleep_performance'), isTrue);
      final initialBase = emptyBaselines['sleep_performance']!;
      expect(initialBase.mean, equals(74.0));
      expect(initialBase.baselineValue, equals(74.0));

      // Test B: Dati multipli per la stessa dataIso (duplicati ciclo + sonno) -> Esattamente 1 valore per notte
      final List<CicloFisiologico> cycles = [
        const CicloFisiologico(dataIso: '2026-10-01', recoveryScore: 70, hrvNotte: 65, rhrNotte: 52),
        const CicloFisiologico(dataIso: '2026-10-02', recoveryScore: 68, hrvNotte: 64, rhrNotte: 53),
      ];
      final List<Sonno> sleeps = [
        const Sonno(dataIso: '2026-10-01', oraInizio: '2026-10-01T00:00:00Z', oraFine: '2026-10-01T08:00:00Z', durataTotMin: 480, sonnoProfondoMin: 90, sonnoRemMin: 110, sleepPerformancePct: 80.0),
        const Sonno(dataIso: '2026-10-01', oraInizio: '2026-10-01T00:00:00Z', oraFine: '2026-10-01T08:00:00Z', durataTotMin: 480, sonnoProfondoMin: 90, sonnoRemMin: 110, sleepPerformancePct: 80.0), // Duplicato
        const Sonno(dataIso: '2026-10-02', oraInizio: '2026-10-02T00:00:00Z', oraFine: '2026-10-02T07:30:00Z', durataTotMin: 450, sonnoProfondoMin: 85, sonnoRemMin: 105, sleepPerformancePct: 76.0),
      ];

      final calculated = BaselineCalculator.calculateRollingBaselines(
        cycles: cycles,
        sleeps: sleeps,
        referenceDateIso: '2026-10-03',
        rollingDays: 30,
      );

      final perfBase = calculated['sleep_performance'];
      expect(perfBase, isNotNull);
      // Conteggio notti uniche = 2 (10-01 e 10-02)
      expect(perfBase!.sampleCount, equals(2));
      // Media di 80 e 76 = 78.0%
      expect(perfBase.mean, equals(78.0));
    });
  });
}
