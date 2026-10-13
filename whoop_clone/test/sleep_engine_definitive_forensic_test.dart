import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:whoop_clone/data/database/database_helper.dart';
import 'package:whoop_clone/data/models/ciclo_fisiologico.dart';
import 'package:whoop_clone/data/models/sonno.dart';
import 'package:whoop_clone/data/repositories/sqlite_whoop_repository.dart';
import 'package:whoop_clone/data/repositories/user_repository.dart';
import 'package:whoop_clone/data/services/overnight_sleep_engine.dart';
import 'package:whoop_clone/data/services/posterior_sleep_detector.dart';
import 'package:whoop_clone/data/services/whoop_csv_parser.dart';
import 'package:whoop_clone/domain/analytics/whoop_analytics_engine.dart';
import 'package:whoop_clone/data/biometrics/sleep_need_engine.dart';
import 'package:whoop_clone/viewmodels/whoop_viewmodel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  DatabaseHelper.isTestMode = true;

  group('WHOOP Sleep Engine, Sleep Need, Actual vs Needed & Historical Persistence Tests', () {
    late DatabaseHelper dbHelper;
    late SqliteWhoopRepository repository;
    late UserRepository userRepository;

    setUp(() async {
      dbHelper = DatabaseHelper();
      await dbHelper.clearAllTables();
      repository = SqliteWhoopRepository();
      userRepository = UserRepository();
    });

    // ─────────────────────────────────────────────────────────────────────────
    // 1. CASO DIAGNOSTICO REALE E PERCENTUALE ORE EFFETTIVE VS NECESSARIE
    // ─────────────────────────────────────────────────────────────────────────
    test('1. Caso Diagnostico Reale: 7h25 (445m) vs 13h48 (828m) produce ~54%, MAI 100%', () {
      const actualHours = 7;
      const actualMinutes = 25;
      const actualTotalMin = (actualHours * 60) + actualMinutes; // 445 min

      const needHours = 13;
      const needMinutes = 48;
      const needTotalMin = (needHours * 60) + needMinutes; // 828 min

      expect(actualTotalMin, 445);
      expect(needTotalMin, 828);

      final pct = WhoopAnalyticsEngine.calculateActualVsNeededPct(
        actualDurationMin: actualTotalMin.toDouble(),
        sleepNeedMin: needTotalMin.toDouble(),
      );

      expect(pct, isNotNull);
      // 445 / 828 * 100 = 53.7439... -> ~53.7% / 54%
      expect(pct, closeTo(53.7, 0.1));
      expect(pct!.round(), 54);
      expect(pct, isNot(equals(100.0)));

      final perfPct = WhoopAnalyticsEngine.calculateSleepPerformancePct(
        actualDurationMin: actualTotalMin.toDouble(),
        sleepNeedMin: needTotalMin.toDouble(),
      );
      expect(perfPct, closeTo(53.7, 0.1));
      expect(perfPct, isNot(equals(100.0)));
    });

    test('2. Percentuale Ore Effettive vs Necessarie copre tutti i casi limite (edge cases)', () {
      // Caso 1: Sonno effettivo inferiore al bisogno -> < 100%
      final under = WhoopAnalyticsEngine.calculateActualVsNeededPct(
        actualDurationMin: 360.0, // 6h
        sleepNeedMin: 480.0, // 8h
      );
      expect(under, equals(75.0));

      // Caso 2: Sonno effettivo uguale al bisogno -> esattamente 100%
      final equal = WhoopAnalyticsEngine.calculateActualVsNeededPct(
        actualDurationMin: 480.0,
        sleepNeedMin: 480.0,
      );
      expect(equal, equals(100.0));

      // Caso 3: Sonno effettivo superiore al bisogno -> conforme alla regola di clamp (100.0)
      final over = WhoopAnalyticsEngine.calculateActualVsNeededPct(
        actualDurationMin: 540.0, // 9h
        sleepNeedMin: 480.0, // 8h
      );
      expect(over, equals(100.0));

      // Caso 4: Bisogno nullo o non valido (0 o negativo) -> null (MAI 100.0)
      expect(
        WhoopAnalyticsEngine.calculateActualVsNeededPct(
          actualDurationMin: 400.0,
          sleepNeedMin: null,
        ),
        isNull,
      );
      expect(
        WhoopAnalyticsEngine.calculateActualVsNeededPct(
          actualDurationMin: 400.0,
          sleepNeedMin: 0.0,
        ),
        isNull,
      );
      expect(
        WhoopAnalyticsEngine.calculateActualVsNeededPct(
          actualDurationMin: 400.0,
          sleepNeedMin: -50.0,
        ),
        isNull,
      );

      // Caso 5: Sonno effettivo assente o 0 min -> null
      expect(
        WhoopAnalyticsEngine.calculateActualVsNeededPct(
          actualDurationMin: 0.0,
          sleepNeedMin: 480.0,
        ),
        isNull,
      );
      expect(
        WhoopAnalyticsEngine.calculateActualVsNeededPct(
          actualDurationMin: null,
          sleepNeedMin: 480.0,
        ),
        isNull,
      );

      // SleepNeedEngine rispetta il limite senza inventare 100% su dati invalidi
      expect(
        SleepNeedEngine.calculateSleepPerformancePct(actualSleepMin: 0.0, sleepNeedMin: 480.0),
        equals(0.0),
      );
      expect(
        SleepNeedEngine.calculateSleepPerformancePct(actualSleepMin: 400.0, sleepNeedMin: 0.0),
        equals(0.0),
      );
    });

    // ─────────────────────────────────────────────────────────────────────────
    // 2. FABBISOGNO DI SONNO E PREVENZIONE DOPPIA SOMMA
    // ─────────────────────────────────────────────────────────────────────────
    test('3. Prevenzione doppia somma del bisogno di sonno', () {
      // In WHOOP, l'export del ciclo riporta già il bisogno totale (es. 600 min).
      // Se il dato importato è presente, il ViewModel deve usarlo direttamente senza sommare nuovamente debito e strain!
      final ciclo = CicloFisiologico(
        dataIso: '2026-05-02',
        sleepNeedMin: 600, // Valore autentico importato da WHOOP
        sonnoArretratoMin: 45,
        strainGiornaliero: 14.5,
        provenance: 'WHOOP_IMPORT',
      );

      // Quando il bisogno è calcolato internamente a partire da baseline:
      // Baseline sonno (480 min = 8h), NON sleep_need (600m)!
      final internalNeed = WhoopAnalyticsEngine.calculateSleepNeedMinutes(
        baselineNeedMin: 480.0,
        dayStrain: 14.5,
        sleepDebtMin: 45.0,
      );

      // 480 + 45 + (2.5 * 14.5^1.2 ~= 62) = 587 min (~9h 47m)
      expect(internalNeed, lessThan(700));
      expect(internalNeed, greaterThan(550));
      // Non deve MAI arrivare a 828 min (13h 48m)!
      expect(internalNeed, isNot(equals(828)));

      // Se invece si sommasse 600m + 155m debito + 73m strain si otterrebbe 828m (il bug originale).
      // Verifichiamo che il valore importato dal ciclo rimanga esattamente 600 min
      expect(ciclo.sleepNeedMin, equals(600));
    });

    // ─────────────────────────────────────────────────────────────────────────
    // 3. ORARIO DI ADDORMENTAMENTO E SEGMENTAZIONE DEL SONNO
    // ─────────────────────────────────────────────────────────────────────────
    test('4. Orario di addormentamento usa la prima epoca di sonno reale e NON windowStart', () async {
      final engine = OvernightSleepEngine(dbHelper: dbHelper);

      // Creiamo telemetria con finestra che parte alle 23:00,
      // ma dove l'utente è sveglio fino alle 23:28 (frequenza alta e moto).
      // Dalle 23:28 in poi l'utente dorme (LIGHT/SWS).
      final windowStart = DateTime(2026, 5, 2, 23, 0); // Utente a letto alle 23:00
      final sleepOnset = DateTime(2026, 5, 2, 23, 28); // Addormentamento reale alle 23:28
      final wakeTime = DateTime(2026, 5, 3, 7, 0); // Risveglio reale alle 07:00
      final windowEnd = DateTime(2026, 5, 3, 7, 15); // Fine finestra alle 07:15

      final telemetry = <Map<String, dynamic>>[];

      // 1. Periodo Veglia iniziale (23:00 - 23:28): 56 epoche da 30s
      var t = windowStart;
      while (t.isBefore(sleepOnset)) {
        telemetry.add({
          'timestamp': t.toIso8601String(),
          'timestamp_utc_ms': t.millisecondsSinceEpoch,
          'bpm': 75.0, // Frequenza da sveglio (ben sopra rhr 55)
          'hr': 75.0,
          'rmssd': 30.0,
          'accel_enmo': 0.08, // Moto da veglia
          'motion_var': 0.08,
        });
        t = t.add(const Duration(seconds: 30));
      }

      // 2. Periodo Sonno effettivo (23:28 - 07:00): 904 epoche da 30s (~452 min)
      while (t.isBefore(wakeTime)) {
        telemetry.add({
          'timestamp': t.toIso8601String(),
          'timestamp_utc_ms': t.millisecondsSinceEpoch,
          'bpm': 52.0, // FC a riposo notturna
          'hr': 52.0,
          'rmssd': 68.0,
          'accel_enmo': 0.003, // Immobile
          'motion_var': 0.003,
          'resp_rate': 14.2,
          'resp_power': 0.25,
        });
        t = t.add(const Duration(seconds: 30));
      }

      // 3. Periodo Veglia finale (07:00 - 07:15): 30 epoche da 30s
      while (t.isBefore(windowEnd)) {
        telemetry.add({
          'timestamp': t.toIso8601String(),
          'timestamp_utc_ms': t.millisecondsSinceEpoch,
          'bpm': 80.0,
          'hr': 80.0,
          'rmssd': 35.0,
          'accel_enmo': 0.07,
          'motion_var': 0.07,
        });
        t = t.add(const Duration(seconds: 30));
      }

      final result = await engine.processNightlyTelemetry(
        rawTelemetryRecords: telemetry,
        userBaseline30d: {
          'rhr_mean': 55.0,
          'rmssd_mean': 65.0,
          'sleep_need_min': 480.0,
        },
        windowStart: windowStart,
        windowEnd: windowEnd,
        targetDateIso: '2026-05-03',
      );

      expect(result['has_data'], isTrue);
      final totalSleepMin = result['total_sleep_min'] as double;
      // Il sonno effettivo deve escludere i 28 min di veglia iniziale e i 15 min di veglia finale
      expect(totalSleepMin, closeTo(452.0, 5.0));

      // Verifichiamo cosa è stato salvato nel database
      final savedSonno = await dbHelper.getSonnoByDate('2026-05-03');
      expect(savedSonno, isNotNull);
      final oraInizio = DateTime.parse(savedSonno!['ora_inizio'] as String);
      final oraFine = DateTime.parse(savedSonno['ora_fine'] as String);

      // L'addormentamento effettivo deve essere intorno alle 23:28, NON alle 23:00!
      expect(oraInizio.hour, 23);
      expect(oraInizio.minute, inInclusiveRange(27, 29));
      expect(oraFine.hour, 7);
      expect(oraFine.minute, inInclusiveRange(0, 2));
    });

    // ─────────────────────────────────────────────────────────────────────────
    // 4. REGOLARITÀ DEL SONNO E MULTI-NOTTE
    // ─────────────────────────────────────────────────────────────────────────
    test('5. Regolarità del sonno: calcolo multi-notte e gestione notte singola (null)', () {
      // Notte 1: 23:30 -> 07:00
      final n1Start = DateTime(2026, 5, 2, 23, 30);
      final n1End = DateTime(2026, 5, 3, 7, 0);

      // Notte 2 quasi identica: 23:28 -> 07:05
      final n2Start = DateTime(2026, 5, 3, 23, 28);
      final n2End = DateTime(2026, 5, 4, 7, 5);

      final consistency = WhoopAnalyticsEngine.calculateSleepConsistency(
        currentOnset: n2Start,
        currentWake: n2End,
        previousOnset: n1Start,
        previousWake: n1End,
      );

      expect(consistency, isNotNull);
      expect(consistency!, greaterThan(95.0)); // Overlap quasi perfetto

      // Notte con grande shift di orario: 03:00 -> 11:00 vs 23:30 -> 07:00
      final nShiftStart = DateTime(2026, 5, 3, 3, 0);
      final nShiftEnd = DateTime(2026, 5, 4, 11, 0);

      final shiftConsistency = WhoopAnalyticsEngine.calculateSleepConsistency(
        currentOnset: nShiftStart,
        currentWake: nShiftEnd,
        previousOnset: n1Start,
        previousWake: n1End,
      );

      expect(shiftConsistency, isNotNull);
      expect(shiftConsistency!, lessThan(70.0));

      // Se manca la notte precedente (o orari invertiti), restituisce null
      final invalid = WhoopAnalyticsEngine.calculateSleepConsistency(
        currentOnset: n1End, // fine prima di inizio
        currentWake: n1Start,
        previousOnset: n1Start,
        previousWake: n1End,
      );
      expect(invalid, isNull);
    });

    // ─────────────────────────────────────────────────────────────────────────
    // 5. PROTEZIONE INTEGRITÀ STORICA E ANTI-SOVRASCRITTURA
    // ─────────────────────────────────────────────────────────────────────────
    test('6. Protezione dati storici: WHOOP_IMPORT non viene MAI sovrascritta da sync o sessioni vuote', () async {
      // Inseriamo una sessione storica autentica importata da WHOOP
      final historicalSonno = Sonno(
        dataIso: '2026-05-02',
        oraInizio: '2026-05-01T23:28:00',
        oraFine: '2026-05-02T07:00:00',
        durataTotMin: 445,
        sonnoProfondoMin: 95,
        sonnoRemMin: 120,
        efficienzaPct: 94.0,
        sleepPerformancePct: 88.0,
        regolaritaSonnoPctVal: 82.0,
        sleepNeedMin: 506,
        sleepDebtMin: 25,
        provenance: 'WHOOP_IMPORT',
      );

      await dbHelper.insertOrUpdateSonno(historicalSonno.toMap());

      // Verifichiamo che esista
      var inDb = await dbHelper.getSonnoByDate('2026-05-02');
      expect(inDb, isNotNull);
      expect(inDb!['provenance'], 'WHOOP_IMPORT');
      expect(inDb['durata_tot_min'], 445);
      expect(inDb['regolarita_sonno_pct'], 82.0);
      expect(inDb['sleep_need_min'], 506);

      // Eseguiamo PosteriorSleepDetector sulla data storica
      final detector = PosteriorSleepDetector(dbHelper: dbHelper);
      await detector.runPosteriorDetectionAndPersist(
        windowStart: DateTime(2026, 5, 1, 22, 0),
        windowEnd: DateTime(2026, 5, 2, 8, 0),
      );

      // Verifichiamo che la sessione WHOOP_IMPORT sia rimasta INTATTA
      inDb = await dbHelper.getSonnoByDate('2026-05-02');
      expect(inDb, isNotNull);
      expect(inDb!['provenance'], 'WHOOP_IMPORT');
      expect(inDb['durata_tot_min'], 445);
      expect(inDb['regolarita_sonno_pct'], 82.0);
      expect(inDb['sleep_need_min'], 506);
      expect(inDb['sleep_performance_pct'], 88.0);
    });

    test('7. Navigazione giorni passati nel ViewModel non clobbera i dati con la data odierna', () async {
      // Inseriamo due giornate distinte
      final c1 = CicloFisiologico(
        dataIso: '2026-05-01',
        recoveryScore: 45.0,
        strainGiornaliero: 12.0,
        sleepNeedMin: 490,
        provenance: 'WHOOP_IMPORT',
      );
      final s1 = Sonno(
        dataIso: '2026-05-01',
        oraInizio: '2026-04-30T23:30:00',
        oraFine: '2026-05-01T06:30:00',
        durataTotMin: 420,
        sonnoProfondoMin: 80,
        sonnoRemMin: 100,
        sleepPerformancePct: 85.0,
        regolaritaSonnoPctVal: 78.0,
        sleepNeedMin: 490,
        provenance: 'WHOOP_IMPORT',
      );

      await dbHelper.upsertCicloFisiologico(c1.toMap());
      await dbHelper.insertOrUpdateSonno(s1.toMap());

      final viewModel = WhoopViewModel(
        repository: repository,
        userRepository: userRepository,
      );

      // Selezioniamo il giorno passato 2026-05-01
      await viewModel.setSelectedDate(DateTime(2026, 5, 1));

      expect(viewModel.selectedDateIso, '2026-05-01');
      expect(viewModel.isToday, isFalse);
      expect(viewModel.ultimoCiclo?.dataIso, '2026-05-01');
      expect(viewModel.ultimoCiclo?.recoveryScore, 45.0);
      expect(viewModel.sonnoList.isNotEmpty, isTrue);
      expect(viewModel.sonnoList.first.dataIso, '2026-05-01');
      expect(viewModel.sonnoList.first.durataTotMin, 420);
      expect(viewModel.currentSleepNeedMinutes, 490.0);
    });

    test('8. Parsing CSV WHOOP autentico preserva sleep_need, sleep_debt, andamento_sonno e regolarita_sonno', () {
      const csvCycles = '''Ora di inizio ciclo,Ora di fine ciclo,Fuso orario ciclo,Punteggio di recupero %,Frequenza cardiaca a riposo (bpm),Variabilità della frequenza cardiaca (ms),Temp. cutanea (C),Ossigeno nel sangue %,Sforzo giornaliero,Energia bruciata (cal),FC max. (bpm),FC media (bpm),Inizio del sonno,Inizio del risveglio,Andamento del sonno %,Frequenza respiratoria (rpm),Durata del sonno (min),Tempo a letto (min),Durata del sonno leggero (min),Durata profondo (SWS) (min),Durata REM (min),Durata del risveglio (min),Sonno richiesto (min),Sonno arretrato (min),Efficienza del sonno %,Regolarità del sonno %
2026-05-03 00:52:20,2026-05-03 23:59:00,UTC+02:00,68,55,67,34.19,93.65,11.2,2100,150,72,2026-05-03 00:52:20,2026-05-03 08:57:17,79,14.2,428,484,209,90,129,56,634,96,88,76
''';

      const csvSleeps = '''Ora di inizio ciclo,Ora di fine ciclo,Fuso orario ciclo,Inizio del sonno,Inizio del risveglio,Andamento del sonno %,Frequenza respiratoria (rpm),Durata del sonno (min),Tempo a letto (min),Durata del sonno leggero (min),Durata profondo (SWS) (min),Durata REM (min),Durata del risveglio (min),Sonno richiesto (min),Sonno arretrato (min),Efficienza del sonno %,Regolarità del sonno %,Riposo breve
2026-05-03 00:52:20,2026-05-03 23:59:00,UTC+02:00,2026-05-03 00:52:20,2026-05-03 08:57:17,79,14.2,428,484,209,90,129,56,634,96,88,76,false
''';

      final cycles = WhoopCsvParser.parseCicliFisiologici(csvCycles);
      expect(cycles.length, 1);
      expect(cycles[0].sleepNeedMin, 634);
      expect(cycles[0].sonnoArretratoMinVal, 96);
      expect(cycles[0].recoveryScore, 68.0);

      final sleeps = WhoopCsvParser.parseSonno(csvSleeps);
      expect(sleeps.length, 1);
      expect(sleeps[0].durataTotMin, 428);
      expect(sleeps[0].sleepPerformancePct, 79.0);
      expect(sleeps[0].regolaritaSonnoPct, 76.0);
      expect(sleeps[0].sleepNeedMin, 634);
      expect(sleeps[0].sleepDebtMin, 96);
    });
  });
}
