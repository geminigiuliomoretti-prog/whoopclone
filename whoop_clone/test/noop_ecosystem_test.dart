import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:whoop_clone/data/ble/noop_protocol_decoder.dart';
import 'package:whoop_clone/data/database/database_helper.dart';
import 'package:whoop_clone/data/services/haptic_alarm_service.dart';
import 'package:whoop_clone/views/breathe/haptic_breathe_screen.dart';
import 'package:whoop_clone/views/stress/stress_timeline_view.dart';
import 'package:whoop_clone/views/widgets/charts/heart_rate_zones_chart.dart';
import 'package:whoop_clone/views/widgets/charts/hypnogram_chart.dart';
import 'package:whoop_clone/views/widgets/charts/intraday_hr_chart.dart';
import 'package:whoop_clone/views/widgets/charts/sparkline_14d.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    DatabaseHelper.isTestMode = true;
  });

  group('1. Smart Alarm & BLE Haptic Engine Tests', () {
    test('1.1 Generazione comandi BLE sveglia e motore aptico diretto', () {
      final targetDt = DateTime(2026, 8, 16, 7, 30);
      final alarmPayload = HapticClockEncoder.encodeAlarmTime(
        alarmTime: targetDt,
        vibrationPattern: 2,
      );
      expect(alarmPayload.length, equals(20));
      expect(alarmPayload[0], equals(0xAA));
      expect(alarmPayload[1], equals(0x10));

      final directMotorPayload = HapticClockEncoder.encodeHapticMotorDirect(pattern: 2);
      expect(directMotorPayload.length, equals(8));
      expect(directMotorPayload[0], equals(0x07));
      expect(directMotorPayload[2], equals(0x02));

      final cancelPayload = HapticClockEncoder.encodeCancelAlarm();
      expect(cancelPayload.length, equals(20));
    });

    test('1.2 Trigger Modalità Sleep Target al raggiungimento dell\'85% del fabbisogno', () {
      final alarmService = HapticAlarmService();
      alarmService.updateSettings(
        isEnabled: true,
        targetTime: const TimeOfDay(hour: 8, minute: 0),
        wakeupMode: WakeupMode.sleepTarget,
        sleepTargetPct: 85.0,
      );

      // Fabbisogno: 480 min. 85% = 408 min.
      // Dormito: 350 min -> Non deve suonare
      alarmService.evaluateWakeupConditions(
        currentSleepDurationMin: 350.0,
        sleepNeedMin: 480.0,
      );
      expect(alarmService.isRinging, isFalse);

      // Dormito: 410 min -> Raggiunto target 85% -> Innesco sveglia!
      alarmService.evaluateWakeupConditions(
        currentSleepDurationMin: 410.0,
        sleepNeedMin: 480.0,
      );
      expect(alarmService.isRinging, isTrue);

      // Dismiss sveglia
      alarmService.dismissAlarm();
      expect(alarmService.isRinging, isFalse);
    });

    test('1.3 Trigger Modalità Finestra Ottimale di Risveglio (Fase Leggera / Movimento)', () {
      final alarmService = HapticAlarmService();
      final now = DateTime.now();
      // Imposta sveglia tra 15 minuti (all'interno della finestra di 30 min)
      final futureTime = now.add(const Duration(minutes: 15));
      alarmService.updateSettings(
        isEnabled: true,
        targetTime: TimeOfDay(hour: futureTime.hour, minute: futureTime.minute),
        wakeupMode: WakeupMode.optimalWakeWindow,
      );

      // Se il sonno è profondo (SWS) e nessun movimento -> Non svegliare prematuramente
      alarmService.evaluateWakeupConditions(
        currentSleepDurationMin: 300.0,
        sleepNeedMin: 480.0,
        currentSleepStage: 'sws',
        currentMotionEnmo: 0.005,
      );
      expect(alarmService.isRinging, isFalse);

      // Se transita in sonno leggero o muove il braccio (ENMO > 0.04g) -> Sveglia dolce intelligente!
      alarmService.evaluateWakeupConditions(
        currentSleepDurationMin: 310.0,
        sleepNeedMin: 480.0,
        currentSleepStage: 'light',
        currentMotionEnmo: 0.06,
      );
      expect(alarmService.isRinging, isTrue);

      // Test Snooze (+9 min)
      alarmService.snoozeAlarm(snoozeMinutes: 9);
      expect(alarmService.isRinging, isFalse);
      expect(alarmService.snoozeUntil, isNotNull);
    });
  });

  group('2. Advanced Charts & Temporal Visualization Tests', () {
    testWidgets('2.1 Rendering Ipnogramma Notturno con 4 stadi', (WidgetTester tester) async {
      final now = DateTime(2026, 8, 15, 23, 0);
      final blocks = [
        HypnogramBlock(startTime: now, endTime: now.add(const Duration(minutes: 60)), stage: 'light', durationMinutes: 60),
        HypnogramBlock(startTime: now.add(const Duration(minutes: 60)), endTime: now.add(const Duration(minutes: 150)), stage: 'sws', durationMinutes: 90),
        HypnogramBlock(startTime: now.add(const Duration(minutes: 150)), endTime: now.add(const Duration(minutes: 240)), stage: 'rem', durationMinutes: 90),
        HypnogramBlock(startTime: now.add(const Duration(minutes: 240)), endTime: now.add(const Duration(minutes: 260)), stage: 'wake', durationMinutes: 20),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HypnogramChart(blocks: blocks),
          ),
        ),
      );

      expect(find.text('VEGLIA'), findsOneWidget);
      expect(find.text('REM'), findsWidgets);
      expect(find.text('SWS'), findsWidgets);
      expect(find.text('LEGGERO'), findsWidgets);
    });

    testWidgets('2.2 Rendering Sparkline a 14 Giorni e Intraday HR', (WidgetTester tester) async {
      final dataPoints = [65.0, 70.0, 72.0, 68.0, 75.0, 80.0, 82.0, 78.0, 85.0, 88.0, 84.0, 90.0, 92.0, 89.0];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                Sparkline14d(dataPoints: dataPoints, baselineValue: 75.0),
                IntradayHrChart(
                  points: [
                    HrDataPoint(timestamp: DateTime(2026, 8, 15, 8, 0), bpm: 60),
                    HrDataPoint(timestamp: DateTime(2026, 8, 15, 12, 0), bpm: 140),
                    HrDataPoint(timestamp: DateTime(2026, 8, 15, 18, 0), bpm: 75),
                  ],
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('MIN: '), findsOneWidget);
      expect(find.text('MAX: '), findsOneWidget);
      expect(find.text('140 BPM'), findsOneWidget);
    });

    testWidgets('2.3 Distribuzione 5 Zone Cardiache per Allenamento', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HeartRateZonesChart.fromPercentages(
              z1Pct: 10.0,
              z2Pct: 30.0,
              z3Pct: 40.0,
              z4Pct: 15.0,
              z5Pct: 5.0,
              totalMinutes: 60,
            ),
          ),
        ),
      );

      expect(find.text('DISTRIBUZIONE ZONE CARDIACHE'), findsOneWidget);
      expect(find.text('Zona 5'), findsOneWidget);
      expect(find.text('Zona 3'), findsOneWidget);
      expect(find.text('40%'), findsOneWidget);
    });
  });

  group('3. Stress Monitor & Autonomic Load Tests', () {
    testWidgets('3.1 Timeline Stress Diurno e conteggio minuti ad alto stress (>2.0)', (WidgetTester tester) async {
      final now = DateTime(2026, 8, 15, 8, 0);
      final samples = [
        StressTimelineSample(timestamp: now, stressScore: 0.5, bpm: 58, hrvMs: 75.0),
        StressTimelineSample(timestamp: now.add(const Duration(hours: 1)), stressScore: 1.2, bpm: 72, hrvMs: 55.0),
        StressTimelineSample(timestamp: now.add(const Duration(hours: 2)), stressScore: 2.4, bpm: 110, hrvMs: 32.0), // Elevato
        StressTimelineSample(timestamp: now.add(const Duration(hours: 3)), stressScore: 2.6, bpm: 115, hrvMs: 28.0), // Elevato
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StressTimelineView(samples: samples, currentStressScore: 1.2),
          ),
        ),
      );

      expect(find.text('TIMELINE STRESS DIURNO'), findsOneWidget);
      // 2 campioni elevati * 5 min = 10m
      expect(find.text('Elevato: 10m'), findsOneWidget);
    });
  });

  group('4. Haptic Breathe & Biofeedback Session Tests', () {
    test('4.1 Verifica timing e cicli dei preset di respirazione', () {
      expect(BreathePreset.relax.totalCycleDurationSec, equals(10.0)); // 4s in + 6s out
      expect(BreathePreset.coherence.totalCycleDurationSec, equals(11.0)); // 5.5s in + 5.5s out (0.1 Hz vagal resonance)
      expect(BreathePreset.box.totalCycleDurationSec, equals(16.0)); // 4+4+4+4
    });
  });
}
