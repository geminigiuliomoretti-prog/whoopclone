import 'package:flutter_test/flutter_test.dart';
import 'package:whoop_clone/domain/analytics/whoop_analytics_engine.dart';
import 'package:whoop_clone/data/models/sonno.dart';
import 'package:whoop_clone/data/database/database_helper.dart';
import 'package:whoop_clone/data/services/overnight_sleep_engine.dart';
import 'package:whoop_clone/data/ble/whoop_96byte_packet.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('P0-P3 Comprehensive Technical Audit Suite', () {
    setUpAll(() async {
      DatabaseHelper.isTestMode = true;
      final db = await DatabaseHelper().database;
      await db.delete(DatabaseHelper.tableSonno);
      await db.delete(DatabaseHelper.tableCicliFisiologici);
      await db.delete(DatabaseHelper.tableSleepStageSegments);
      await db.delete(DatabaseHelper.tableTelemetriaGrezza);
    });

    test('P0.1: 65% effettive/necessarie (390 min / 600 min) calcola 65.0% e NON 100%', () {
      final ratio = WhoopAnalyticsEngine.calculateActualVsNeededPct(
        actualDurationMin: 390.0,
        sleepNeedMin: 600.0,
      );
      expect(ratio, equals(65.0));

      final sonno = const Sonno(
        dataIso: '2026-10-13',
        oraInizio: '2026-10-12T23:00:00.000Z',
        oraFine: '2026-10-13T05:30:00.000Z',
        durataTotMin: 390,
        sonnoProfondoMin: 80,
        sonnoRemMin: 90,
        sleepNeedMin: 600,
        sleepPerformancePct: 65.0,
      );

      expect(sonno.actualVsNeededPct, equals(65.0));
    });

    test('P0.2: Sessione senza bisogno valido (sleepNeedMin <= 0 o null) restituisce null e NON 100%', () {
      final ratioNull = WhoopAnalyticsEngine.calculateActualVsNeededPct(
        actualDurationMin: 390.0,
        sleepNeedMin: null,
      );
      expect(ratioNull, isNull);

      final ratioZero = WhoopAnalyticsEngine.calculateActualVsNeededPct(
        actualDurationMin: 390.0,
        sleepNeedMin: 0.0,
      );
      expect(ratioZero, isNull);

      final sonnoSenzaBisogno = const Sonno(
        dataIso: '2026-10-13',
        oraInizio: '2026-10-12T23:00:00.000Z',
        oraFine: '2026-10-13T05:30:00.000Z',
        durataTotMin: 390,
        sonnoProfondoMin: 80,
        sonnoRemMin: 90,
        sleepNeedMin: null,
      );
      expect(sonnoSenzaBisogno.actualVsNeededPct, isNull);
    });

    test('P0.3: Distinzione netta tra dato WHOOP importato e stima calcolata', () {
      final sonnoImport = const Sonno(
        dataIso: '2026-10-10',
        oraInizio: '2026-10-09T23:00:00.000Z',
        oraFine: '2026-10-10T07:00:00.000Z',
        durataTotMin: 450,
        sonnoProfondoMin: 90,
        sonnoRemMin: 100,
        sleepNeedMin: 500,
        sleepPerformancePct: 90.0,
        provenance: 'WHOOP_IMPORT',
      );

      final sonnoStima = const Sonno(
        dataIso: '2026-10-11',
        oraInizio: '2026-10-10T23:00:00.000Z',
        oraFine: '2026-10-11T07:00:00.000Z',
        durataTotMin: 400,
        sonnoProfondoMin: 80,
        sonnoRemMin: 70,
        sleepNeedMin: 500,
        sleepPerformancePct: 80.0,
        provenance: 'REAL',
      );

      expect(sonnoImport.provenance, equals('WHOOP_IMPORT'));
      expect(sonnoStima.provenance, equals('REAL'));
      expect(sonnoImport.sleepPerformancePct, equals(90.0));
      expect(sonnoStima.sleepPerformancePct, equals(80.0));
    });

    test('P0.4: Aggiornamenti transazionali proteggono sessione precedente da sincronizzazioni parziali', () async {
      final engine = OvernightSleepEngine();
      final baseTs = DateTime(2026, 10, 5, 23, 0);

      // Crea sessione valida iniziale di 480 minuti (8 ore)
      final validRecords = <Map<String, dynamic>>[];
      for (int i = 0; i < 960; i++) {
        validRecords.add({
          'timestamp': baseTs.add(Duration(seconds: i * 30)).toIso8601String(),
          'hr': 55.0,
          'bpm': 55.0,
          'rmssd': 65.0,
          'motion_var': 0.001,
          'accel_enmo': 0.001,
        });
      }

      final baseline = {
        'rhr_mean': 55.0,
        'rmssd_mean': 65.0,
        'sleep_need_min': 480.0,
      };

      await engine.processNightlyTelemetry(
        rawTelemetryRecords: validRecords,
        userBaseline30d: baseline,
        targetDateIso: '2026-10-06',
      );

      final db = await DatabaseHelper().database;
      final rowsBefore = await db.query(DatabaseHelper.tableSonno, where: 'data_iso = ?', whereArgs: ['2026-10-06']);
      expect(rowsBefore.isNotEmpty, isTrue);
      final durBefore = rowsBefore.first['durata_tot_min'] as int;
      expect(durBefore, greaterThan(400));

      // Simula sincronizzazione parziale/frammentata con solo 30 minuti di dati
      final partialRecords = <Map<String, dynamic>>[];
      for (int i = 0; i < 60; i++) {
        partialRecords.add({
          'timestamp': baseTs.add(Duration(seconds: i * 30)).toIso8601String(),
          'hr': 55.0,
          'bpm': 55.0,
          'rmssd': 65.0,
          'motion_var': 0.001,
        });
      }

      await engine.processNightlyTelemetry(
        rawTelemetryRecords: partialRecords,
        userBaseline30d: baseline,
        targetDateIso: '2026-10-06',
      );

      final rowsAfter = await db.query(DatabaseHelper.tableSonno, where: 'data_iso = ?', whereArgs: ['2026-10-06']);
      expect(rowsAfter.first['durata_tot_min'], equals(durBefore)); // Preservata intatta
    });

    test('P1.1: Sleep Efficiency calcola tempo a letto distinguendo veglia e sonno effettivo', () {
      final sonno = const Sonno(
        dataIso: '2026-10-12',
        oraInizio: '2026-10-11T23:00:00.000Z',
        oraFine: '2026-10-12T07:00:00.000Z', // 480 min a letto
        durataTotMin: 432, // 432 min dormiti, 48 min veglia
        sonnoProfondoMin: 100,
        sonnoRemMin: 110,
        efficienzaPct: 90.0,
      );

      expect(sonno.tempoALettoMin, equals(480));
      expect(sonno.vegliaMin, equals(48.0));
      expect(sonno.durataTotMin, equals(432));
      expect(sonno.efficienzaPct, equals(90.0));
    });

    test('P2.1: Whoop96BytePacket valida le varianti di frame e rigetta valori non validati', () {
      final raw = List<int>.filled(96, 0);
      raw[0] = 0xAA;
      raw[8] = 60; // HR 60

      final packet = Whoop96BytePacket.fromBytes(raw);
      expect(packet.isValid, isTrue);
      expect(packet.isWhoopFramed, isTrue);
      expect(packet.heartRateBpm, equals(60));
      // Senza payload ottico o RSA valido nei float32, non inventa valori
      expect(packet.respiratoryRate, equals(0.0));
      expect(packet.spo2Ratio, equals(0.0));
    });
  });
}
