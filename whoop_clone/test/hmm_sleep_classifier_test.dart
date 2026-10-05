import 'package:flutter_test/flutter_test.dart';
import 'package:whoop_clone/data/biometrics/hmm_sleep_classifier.dart';
import 'package:whoop_clone/data/biometrics/recovery_engine.dart';

void main() {
  group('Phase 6 — HMM Sleep Staging & Recovery Gating (STG-01..07)', () {
    final now = DateTime(2026, 10, 5, 23, 0);

    test('STG-04: Enforces minimum bout duration and removes isolated flickering', () {
      // Create a sequence of 60 epochs (30 min)
      // Normal LIGHT sleep, with an isolated 1-epoch SWS at index 10 and 2-epoch REM at index 30
      // And a genuine sustained 6-epoch SWS at index 40..45
      final epochs = List.generate(60, (i) {
        if (i == 10) {
          // Isolated 1-epoch SWS candidate (30 seconds)
          return HmmEpochInput(
            index: i,
            timestamp: now.add(Duration(seconds: i * 30)),
            enmo: 0.002,
            hr: 48.0,
            rmssd: 75.0,
          );
        } else if (i >= 20 && i < 22) {
          // Isolated 2-epoch REM candidate (1 minute, < minBoutEpochs)
          return HmmEpochInput(
            index: i,
            timestamp: now.add(Duration(seconds: i * 30)),
            enmo: 0.003,
            hr: 62.0,
            rmssd: 65.0,
          );
        } else if (i >= 25 && i < 31) {
          // Valid sustained 6-epoch SWS (3 minutes >= minBoutEpochs) in first half
          return HmmEpochInput(
            index: i,
            timestamp: now.add(Duration(seconds: i * 30)),
            enmo: 0.002,
            hr: 47.0,
            rmssd: 80.0,
          );
        } else {
          // Standard light sleep
          return HmmEpochInput(
            index: i,
            timestamp: now.add(Duration(seconds: i * 30)),
            enmo: 0.012,
            hr: 58.0,
            rmssd: 55.0,
          );
        }
      });

      final stages = HmmSleepClassifier.classifyNight(epochs);

      expect(stages.length, equals(60));
      // Isolated SWS must be smoothed to light sleep
      expect(stages[10], equals(HmmSleepStage.light), reason: 'Isolated 30s SWS must not flicker');
      // Short 2-epoch REM must be smoothed to light sleep
      expect(stages[20], equals(HmmSleepStage.light), reason: 'Sub-minimum REM bout must revert to light');
      expect(stages[21], equals(HmmSleepStage.light));
      // Sustained 6-epoch SWS bout must be preserved as SWS
      expect(stages[25], equals(HmmSleepStage.sws));
      expect(stages[28], equals(HmmSleepStage.sws));
      expect(stages[30], equals(HmmSleepStage.sws));
    });

    test('STG-04 / STG-02: Ultradian priors concentrate SWS early and REM late in the night', () {
      const int totalEpochs = 200; // 100 minutes
      final epochs = List.generate(totalEpochs, (i) {
        // First half: deeper sleep, lower HR (48 bpm)
        // Second half: higher HR variability / REM candidate (55 bpm)
        final isFirstHalf = i < 100;
        return HmmEpochInput(
          index: i,
          timestamp: now.add(Duration(seconds: i * 30)),
          enmo: 0.003,
          hr: isFirstHalf ? 48.0 : 55.0,
          rmssd: isFirstHalf ? 70.0 : 60.0,
        );
      });

      final stages = HmmSleepClassifier.classifyNight(epochs);

      // In the first third, quiet low-HR epochs should be SWS
      final earlySwsCount = stages.sublist(0, 50).where((s) => s == HmmSleepStage.sws).length;
      expect(earlySwsCount, greaterThan(30), reason: 'SWS must dominate the first portion of the night');

      // In the final third, SWS is suppressed in favor of REM/Light
      final lateRemOrLight = stages.sublist(150, 200).where((s) => s == HmmSleepStage.rem || s == HmmSleepStage.light).length;
      expect(lateRemOrLight, greaterThan(30), reason: 'Late sleep must favor REM and light sleep over deep SWS');
    });

    test('STG-03 / STG-05: Preserves MISSING epochs without clamping or forcing to light sleep', () {
      final epochs = List.generate(30, (i) {
        if (i >= 10 && i < 15) {
          // Gap of 5 missing epochs (2.5 minutes)
          return HmmEpochInput(
            index: i,
            timestamp: now.add(Duration(seconds: i * 30)),
            isMissing: true,
          );
        }
        return HmmEpochInput(
          index: i,
          timestamp: now.add(Duration(seconds: i * 30)),
          enmo: 0.005,
          hr: 54.0,
          rmssd: 60.0,
        );
      });

      final stages = HmmSleepClassifier.classifyNight(epochs);

      for (int i = 10; i < 15; i++) {
        expect(stages[i], equals(HmmSleepStage.missing), reason: 'Missing epochs must remain strictly MISSING');
      }
    });

    test('STG-06: Recovery Score Gating strictly rejects short sleep, low RR epochs, or cold baseline', () {
      // 1. Duration < 120 minutes
      final shortSleepGate = HmmSleepClassifier.evaluateRecoveryGating(
        sleepDurationMinutes: 105.0,
        validRrEpochsCount: 150,
        baselineDaysCount: 14,
      );
      expect(shortSleepGate.isEligible, isFalse);
      expect(shortSleepGate.reason, contains('< 120 minuti'));

      // 2. Valid RR epochs < 30
      final lowRrGate = HmmSleepClassifier.evaluateRecoveryGating(
        sleepDurationMinutes: 450.0,
        validRrEpochsCount: 22,
        baselineDaysCount: 14,
      );
      expect(lowRrGate.isEligible, isFalse);
      expect(lowRrGate.reason, contains('< 30 epoche'));

      // 3. Baseline days < 4 (calibrating)
      final coldStartGate = HmmSleepClassifier.evaluateRecoveryGating(
        sleepDurationMinutes: 480.0,
        validRrEpochsCount: 500,
        baselineDaysCount: 2,
      );
      expect(coldStartGate.isEligible, isFalse);
      expect(coldStartGate.reason, contains('2/4 giorni'));

      // 4. Fully eligible
      final eligibleGate = HmmSleepClassifier.evaluateRecoveryGating(
        sleepDurationMinutes: 450.0,
        validRrEpochsCount: 400,
        baselineDaysCount: 10,
      );
      expect(eligibleGate.isEligible, isTrue);
      expect(eligibleGate.reason, isNull);
    });

    test('STG-06: RecoveryEngine.calculateRecoveryScore respects strict gating and returns null', () {
      // When strictGating is true and sleep is short (< 120 min)
      final scoreShortSleep = RecoveryEngine.calculateRecoveryScore(
        currentRmssdMs: 70.0,
        historicalLnRmssd: [4.2, 4.25, 4.18, 4.22],
        currentFcrBpm: 52.0,
        historicalRhr: [52.0, 53.0, 51.0, 52.0],
        sleepDurationMinutes: 90.0, // < 120
        validRrEpochsCount: 120,
        strictGating: true,
      );
      expect(scoreShortSleep, isNull);

      // When strictGating is true and RR epochs < 30
      final scoreLowRr = RecoveryEngine.calculateRecoveryScore(
        currentRmssdMs: 70.0,
        historicalLnRmssd: [4.2, 4.25, 4.18, 4.22],
        currentFcrBpm: 52.0,
        historicalRhr: [52.0, 53.0, 51.0, 52.0],
        sleepDurationMinutes: 420.0,
        validRrEpochsCount: 18, // < 30
        strictGating: true,
      );
      expect(scoreLowRr, isNull);

      // When baseline is under 4 days
      final scoreColdStart = RecoveryEngine.calculateRecoveryScore(
        currentRmssdMs: 70.0,
        historicalLnRmssd: [4.2, 4.25], // 2 days < 4
        currentFcrBpm: 52.0,
        historicalRhr: [52.0, 53.0],
        sleepDurationMinutes: 420.0,
        validRrEpochsCount: 200,
        strictGating: true,
      );
      expect(scoreColdStart, isNull);

      // When all requirements are met
      final scoreValid = RecoveryEngine.calculateRecoveryScore(
        currentRmssdMs: 70.0,
        historicalLnRmssd: [4.2, 4.25, 4.18, 4.22],
        currentFcrBpm: 52.0,
        historicalRhr: [52.0, 53.0, 51.0, 52.0],
        sleepDurationMinutes: 420.0,
        validRrEpochsCount: 200,
        strictGating: true,
      );
      expect(scoreValid, isNotNull);
      expect(scoreValid!, greaterThan(50.0));
    });
  });
}
