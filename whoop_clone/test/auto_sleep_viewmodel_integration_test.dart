import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:whoop_clone/data/database/database_helper.dart';
import 'package:whoop_clone/data/repositories/sqlite_whoop_repository.dart';
import 'package:whoop_clone/data/services/posterior_sleep_detector.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('Automated Sleep Detection on Wake-Up Verification', () {
    late DatabaseHelper dbHelper;
    late SqliteWhoopRepository repo;

    setUp(() async {
      dbHelper = DatabaseHelper();
      DatabaseHelper.isTestMode = true;
      await dbHelper.clearAllTables();
      repo = SqliteWhoopRepository(dbHelper: dbHelper);
      await repo.initializeAndSeedDatabase();
    });

    tearDown(() async {
      await dbHelper.clearAllTables();
    });

    test('Waking up in the morning: PosteriorSleepDetector automatically finds overnight sleep and saves it', () async {
      // 1. Simula notte di sonno memorizzata su SQLite:
      // Inizio: ieri sera 23:30 (2026-10-05 23:30)
      // Fine: stamattina 07:15 (2026-10-06 07:15) -> 465 minuti di sonno
      // Sveglia: ore 07:30
      final sleepStart = DateTime(2026, 10, 5, 23, 30);
      final sleepEnd = DateTime(2026, 10, 6, 7, 15);
      const wakeDateIso = '2026-10-06';

      // Popola la telemetria continua a campioni da 30s (930 campioni)
      final int totalEpochs = (sleepEnd.difference(sleepStart).inSeconds / 30).round();
      for (int i = 0; i < totalEpochs; i++) {
        final sampleTime = sleepStart.add(Duration(seconds: i * 30));
        // Micro-risveglio di 10 min a metà notte (epoche 400..420)
        final isMicroWake = (i >= 400 && i < 420);
        final isSws = (i >= 100 && i < 180) || (i >= 700 && i < 760);

        final double enmo = isMicroWake ? 0.065 : (isSws ? 0.003 : 0.010);
        final int bpm = isMicroWake ? 75 : (isSws ? 48 : 55);
        final double rmssd = isMicroWake ? 35.0 : (isSws ? 82.0 : 58.0);

        await dbHelper.insertTelemetriaPoint(
          bpm: bpm,
          rrMs: rmssd,
          motionVar: enmo,
          accelEnmo: enmo,
          rmssdMs: rmssd,
          respPower: isSws ? 0.85 : 0.40,
          timestamp: sampleTime,
          timestampUtcMs: sampleTime.toUtc().millisecondsSinceEpoch,
        );
      }

      // 2. Verifica che prima del rilevamento NON esista ancora una sessione per la data di risveglio
      final sonnoBefore = await dbHelper.getSonnoByDate(wakeDateIso);
      expect(sonnoBefore, isNull);

      // 3. Esegui il rilevatore a posteriori come avverrebbe al risveglio
      final detector = PosteriorSleepDetector(dbHelper: dbHelper);
      final savedSessions = await detector.runPosteriorDetectionAndPersist(
        windowStart: sleepStart.subtract(const Duration(hours: 1)),
        windowEnd: sleepEnd.add(const Duration(hours: 1)),
      );

      // 4. VERIFICA DETERMINISTICA:
      // La sessione di sonno notturna DEVE essere stata rilevata e salvata con successo
      expect(savedSessions, greaterThanOrEqualTo(1));

      // Verifica dati persistiti su SQLite
      final sonnoAfter = await dbHelper.getSonnoByDate(wakeDateIso);
      expect(sonnoAfter, isNotNull, reason: 'Il sonno notturno deve essere registrato su SQLite al risveglio');
      expect(sonnoAfter!['data_iso'], equals(wakeDateIso), reason: 'La data deve essere quella del risveglio (SLP-02)');
      expect(sonnoAfter['durata_tot_min'], greaterThanOrEqualTo(400), reason: 'La durata deve coprire la notte');
      expect(sonnoAfter['sonno_profondo_min'], greaterThan(0), reason: 'Deve contenere sonno profondo (SWS)');

      final cicloAfter = await dbHelper.getCicloByDate(wakeDateIso);
      expect(cicloAfter, isNotNull, reason: 'Il ciclo fisiologico deve essere creato automaticamente');
      expect(cicloAfter!['recovery_score'], isNotNull, reason: 'Il recovery score deve essere calcolato');
      expect(cicloAfter['hrv_notte'], isNotNull);
      expect(cicloAfter['rhr_notte'], isNotNull);
    });
  });
}
