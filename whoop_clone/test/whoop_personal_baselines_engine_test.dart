import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:whoop_clone/data/biometrics/recovery_engine.dart';
import 'package:whoop_clone/data/biometrics/sleep_need_engine.dart';
import 'package:whoop_clone/data/models/ciclo_fisiologico.dart';
import 'package:whoop_clone/data/models/sonno.dart';
import 'package:whoop_clone/data/services/baseline_calculator.dart';

void main() {
  group('WHOOP-Style Personal Baselines Engine Tests', () {
    // Helper per generare cicli fisiologici fittizi ordinati
    CicloFisiologico createCycle({
      required String dateIso,
      double? hrv,
      int? rhr,
      double? respRate,
      double? temp,
      double? spo2,
    }) {
      return CicloFisiologico(
        dataIso: dateIso,
        hrvNotte: hrv,
        rhrNotte: rhr?.toDouble(),
        frequenzaRespiratoriaRpm: respRate,
        tempCutaneaC: temp,
        spo2Pct: spo2,
      );
    }

    test('1. Finestra rolling 30 giorni completa: calcola esattamente sui 30 giorni precedenti escludendo il giorno target', () {
      final cycles = <CicloFisiologico>[];
      final baseDate = DateTime(2026, 1, 1);

      // Genera 40 giorni di dati: giorno 0 .. 39 (da 2026-01-01 a 2026-02-09)
      for (int i = 0; i < 40; i++) {
        final d = baseDate.add(Duration(days: i)).toIso8601String().substring(0, 10);
        cycles.add(createCycle(
          dateIso: d,
          hrv: 60.0 + i, // Valore crescente
          rhr: 50 + (i % 5),
          respRate: 14.0,
          temp: 34.0,
          spo2: 96.0,
        ));
      }

      // Valuta giorno 35 (2026-02-05)
      final targetDate = baseDate.add(const Duration(days: 35)).toIso8601String().substring(0, 10);
      final baselines = BaselineCalculator.calculateRollingBaselines(
        cycles: cycles,
        sleeps: const [],
        referenceDateIso: targetDate,
        rollingDays: 30,
      );

      final hrvBase = baselines['hrv']!;
      // Finestra: giorni [5 .. 34] -> esattamente 30 giorni precedenti
      expect(hrvBase.sampleCount, 30);

      // Il giorno 35 (valore 60+35 = 95) NON deve essere presente
      expect(hrvBase.maxVal, lessThan(95.0));
      expect(hrvBase.maxVal, 60.0 + 34); // Giorno 34
      expect(hrvBase.minVal, 60.0 + 5);  // Giorno 5
    });

    test('2. Meno di 30 giorni disponibili: calcola sui giorni validi senza inventare valori', () {
      final cycles = <CicloFisiologico>[];
      final baseDate = DateTime(2026, 3, 1);

      // Solo 10 giorni storici prima del target
      for (int i = 0; i < 10; i++) {
        final d = baseDate.add(Duration(days: i)).toIso8601String().substring(0, 10);
        cycles.add(createCycle(
          dateIso: d,
          hrv: 70.0,
          rhr: 52,
          respRate: 15.0,
          temp: 34.5,
          spo2: 97.0,
        ));
      }

      final targetDate = baseDate.add(const Duration(days: 10)).toIso8601String().substring(0, 10);
      final baselines = BaselineCalculator.calculateRollingBaselines(
        cycles: cycles,
        sleeps: const [],
        referenceDateIso: targetDate,
        rollingDays: 30,
      );

      expect(baselines['hrv']!.sampleCount, 10);
      expect(baselines['hrv']!.mean, 70.0);
      expect(baselines['rhr']!.sampleCount, 10);
      expect(baselines['rhr']!.mean, 52.0);
    });

    test('3. Giorni mancanti: i giorni senza dati vengono saltati senza generare valori artificiali', () {
      final cycles = <CicloFisiologico>[];
      final baseDate = DateTime(2026, 4, 1);

      // 20 giorni su 30 disponibili (10 giorni mancanti/buchi temporali)
      for (int i = 0; i < 30; i++) {
        if (i % 3 == 0) continue; // Salta ogni 3 giorni (giorni mancanti)
        final d = baseDate.add(Duration(days: i)).toIso8601String().substring(0, 10);
        cycles.add(createCycle(
          dateIso: d,
          hrv: 65.0,
          rhr: 54,
          respRate: 14.5,
        ));
      }

      final targetDate = baseDate.add(const Duration(days: 30)).toIso8601String().substring(0, 10);
      final baselines = BaselineCalculator.calculateRollingBaselines(
        cycles: cycles,
        sleeps: const [],
        referenceDateIso: targetDate,
        rollingDays: 30,
      );

      // 30 giorni meno 10 saltati = 20 osservazioni
      expect(baselines['hrv']!.sampleCount, 20);
      expect(baselines['hrv']!.mean, 65.0);
    });

    test('4. Dati null o invalidi: vengono ignorati dal calcolo statistico', () {
      final cycles = <CicloFisiologico>[
        createCycle(dateIso: '2026-05-01', hrv: null, rhr: null, respRate: null),
        createCycle(dateIso: '2026-05-02', hrv: 60.0, rhr: 50, respRate: 14.0),
        createCycle(dateIso: '2026-05-03', hrv: 80.0, rhr: 60, respRate: 16.0),
        createCycle(dateIso: '2026-05-04', hrv: 0.0, rhr: 10, respRate: 3.0), // Fuori dai range fisiologici
      ];

      final baselines = BaselineCalculator.calculateRollingBaselines(
        cycles: cycles,
        sleeps: const [],
        referenceDateIso: '2026-05-05',
        rollingDays: 30,
      );

      // Solo 2026-05-02 e 2026-05-03 sono validi
      expect(baselines['hrv']!.sampleCount, 2);
      expect(baselines['hrv']!.mean, 70.0);
      expect(baselines['rhr']!.sampleCount, 2);
      expect(baselines['rhr']!.mean, 55.0);
      expect(baselines['respiratory_rate']!.sampleCount, 2);
      expect(baselines['respiratory_rate']!.mean, 15.0);
    });

    test('5. Duplicati: la lista ordinata e filtrata gestisce correttamente i campioni', () {
      final cycles = <CicloFisiologico>[
        createCycle(dateIso: '2026-05-01', hrv: 60.0, rhr: 50),
        createCycle(dateIso: '2026-05-01', hrv: 60.0, rhr: 50), // Stessa data
        createCycle(dateIso: '2026-05-02', hrv: 80.0, rhr: 56),
      ];

      final baselines = BaselineCalculator.calculateRollingBaselines(
        cycles: cycles,
        sleeps: const [],
        referenceDateIso: '2026-05-03',
        rollingDays: 30,
      );

      expect(baselines['hrv']!.sampleCount, 3);
      expect(baselines['hrv']!.mean, closeTo(66.67, 0.01));
    });

    test('6. Giorno corrente rigorosamente escluso dalla propria baseline', () {
      final cycles = <CicloFisiologico>[
        createCycle(dateIso: '2026-05-01', hrv: 50.0, rhr: 50),
        createCycle(dateIso: '2026-05-02', hrv: 50.0, rhr: 50),
        // Giorno target con valore estremo anomalo
        createCycle(dateIso: '2026-05-03', hrv: 200.0, rhr: 120),
      ];

      final baselines = BaselineCalculator.calculateRollingBaselines(
        cycles: cycles,
        sleeps: const [],
        referenceDateIso: '2026-05-03',
        rollingDays: 30,
      );

      // Il valore del 2026-05-03 (200ms) non deve alterare la baseline
      expect(baselines['hrv']!.sampleCount, 2);
      expect(baselines['hrv']!.mean, 50.0);
      expect(baselines['hrv']!.maxVal, 50.0);
      expect(baselines['rhr']!.mean, 50.0);
    });

    test('7. Aggiornamento dinamico della baseline quando arriva una nuova notte', () {
      final initialCycles = <CicloFisiologico>[
        createCycle(dateIso: '2026-05-01', hrv: 60.0, rhr: 55),
        createCycle(dateIso: '2026-05-02', hrv: 60.0, rhr: 55),
      ];

      // Baseline per il 2026-05-03
      final baselineDay3 = BaselineCalculator.calculateRollingBaselines(
        cycles: initialCycles,
        sleeps: const [],
        referenceDateIso: '2026-05-03',
        rollingDays: 30,
      );
      expect(baselineDay3['hrv']!.sampleCount, 2);
      expect(baselineDay3['hrv']!.mean, 60.0);

      // Arriva la notte del 2026-05-03 registrata dalla strap (HRV = 90.0)
      final updatedCycles = [
        ...initialCycles,
        createCycle(dateIso: '2026-05-03', hrv: 90.0, rhr: 55),
      ];

      // Calcolo baseline per il giorno successivo 2026-05-04
      final baselineDay4 = BaselineCalculator.calculateRollingBaselines(
        cycles: updatedCycles,
        sleeps: const [],
        referenceDateIso: '2026-05-04',
        rollingDays: 30,
      );

      // Ora include la notte del 2026-05-03 (60, 60, 90 -> media = 70.0)
      expect(baselineDay4['hrv']!.sampleCount, 3);
      expect(baselineDay4['hrv']!.mean, 70.0);
    });

    test('8. Source of Truth Linkage: BaselineEngine -> Recovery -> Sleep -> UI condividono gli identici valori', () {
      final cycles = List.generate(10, (i) {
        final d = (i + 1).toString().padLeft(2, '0');
        return createCycle(
          dateIso: '2026-04-$d',
          hrv: 74.5,
          rhr: 52,
          respRate: 14.4,
          spo2: 97,
        );
      });
      final sleeps = List<Sonno>.generate(10, (i) {
        final d = (i + 1).toString().padLeft(2, '0');
        return Sonno(
          id: i + 1,
          dataIso: '2026-04-$d',
          oraInizio: '2026-04-${d}T23:00:00.000Z',
          oraFine: '2026-04-${d}T06:30:00.000Z',
          durataTotMin: 450,
          sonnoProfondoMin: 90,
          sonnoRemMin: 100,
          sleepPerformancePct: 88.5,
          efficienzaPct: 93.75,
        );
      });

      // Target day: 2026-04-11 (finestra precedente 1..10)
      final baselines = BaselineCalculator.calculateRollingBaselines(
        cycles: cycles,
        sleeps: sleeps,
        referenceDateIso: '2026-04-11',
        rollingDays: 30,
      );

      final hrvBaseline = baselines['hrv']!;
      final rhrBaseline = baselines['rhr']!;
      final respBaseline = baselines['respiratory_rate']!;
      final sleepPerfBaseline = baselines['sleep_performance']!;
      final sleepDurBaseline = baselines['sleep_duration']!;

      // 1. Valori precisi interni intatti
      expect(hrvBaseline.mean, equals(74.5));
      expect(rhrBaseline.mean, equals(52.0));
      expect(respBaseline.mean, equals(14.4));
      expect(sleepPerfBaseline.mean, equals(88.5));
      expect(sleepDurBaseline.mean, equals(450.0));

      // 2. Recovery Engine riceve esattamente hrvBaseline e rhrBaseline
      final recScore = RecoveryEngine.calculateRecoveryScore(
        currentRmssdMs: 76.0,
        historicalLnRmssd: List.filled(10, math.log(hrvBaseline.mean)),
        currentFcrBpm: 50.0,
        historicalRhr: List.filled(10, rhrBaseline.mean),
        sleepPerformancePct: sleepPerfBaseline.mean,
        currentRespRateRpm: 14.0,
        baselineRespRateRpm: respBaseline.mean,
      );
      expect(recScore, isNotNull);

      // 3. Sleep Engine / Sleep Need usa esattamente sleepDurBaseline
      final sleepNeed = SleepNeedEngine.calculateSleepNeedMinutes(
        baselineSleepMin: sleepDurBaseline.mean,
        dailyStrain: 10.0,
      );
      expect(sleepNeed, greaterThan(sleepDurBaseline.mean));

      // 4. Arrotondamento esclusivo per visualizzazione UI
      expect(hrvBaseline.mean.round(), equals(75)); // 74.5 -> 75
      expect(rhrBaseline.mean.round(), equals(52));
      expect(respBaseline.mean.toStringAsFixed(1), equals('14.4'));
      expect(sleepPerfBaseline.mean.round(), equals(89)); // 88.5 -> 89
      expect(sleepDurBaseline.mean.round(), equals(450));
    });
  });
}
