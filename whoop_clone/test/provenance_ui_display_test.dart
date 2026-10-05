import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whoop_clone/views/widgets/provenance_badge.dart';
import 'package:whoop_clone/views/widgets/recovery_detail_modal.dart';
import 'package:whoop_clone/views/widgets/sleep_detail_modal.dart';

void main() {
  group('MCK-02 & MCK-03: Provenance Badge & Zero-Tolerance Mock Tests', () {
    testWidgets('ProvenanceBadge renders correct label and style for each type', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                ProvenanceBadge(provenance: DataProvenance.real),
                ProvenanceBadge(provenance: DataProvenance.userEntered),
                ProvenanceBadge(provenance: DataProvenance.bootstrap),
                ProvenanceBadge(provenance: DataProvenance.partial),
                ProvenanceBadge.fromString('USER_ENTERED'),
                ProvenanceBadge.fromString('MANUAL'),
                ProvenanceBadge.fromString('BOOTSTRAP'),
                ProvenanceBadge.fromString('PARTIAL'),
                ProvenanceBadge.fromString('REAL'),
              ],
            ),
          ),
        ),
      );

      // Verify that labels are displayed
      expect(find.text('REALE'), findsWidgets);
      expect(find.text('MANUALE'), findsWidgets);
      expect(find.text('BOOTSTRAP'), findsWidgets);
      expect(find.text('PARZIALE'), findsWidgets);
    });

    testWidgets('RecoveryDetailModal displays ProvenanceBadge with provided provenance', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: RecoveryDetailModal(
            recoveryPct: 82,
            hrvMs: 64.0,
            fcrBpm: 54,
            respRateRpm: 14.5,
            spo2Pct: 98.0,
            tempDeltaC: -0.2,
            hrvBaseline: null, // Uncalibrated baseline
            fcrBaseline: null,
            provenance: 'BOOTSTRAP',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check that the BOOTSTRAP provenance badge is rendered
      expect(find.text('BOOTSTRAP'), findsOneWidget);

      // Check that null baseline displays '--' or 'n/d' and never hardcoded '72.0'
      expect(find.textContaining('72.0'), findsNothing);
      expect(find.text('82%'), findsWidgets);
    });

    testWidgets('RecoveryDetailModal displays REALE badge and respects real baseline when calibrated', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: RecoveryDetailModal(
            recoveryPct: 91,
            hrvMs: 80.0,
            fcrBpm: 48,
            respRateRpm: 13.8,
            spo2Pct: 99.0,
            tempDeltaC: 0.1,
            hrvBaseline: 75.0,
            fcrBaseline: 50,
            provenance: 'REAL',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('REALE'), findsOneWidget);
      expect(find.text('91%'), findsWidgets);
      expect(find.text('80'), findsOneWidget);
      expect(find.text('75'), findsOneWidget);
    });

    testWidgets('SleepDetailModal displays ProvenanceBadge with MANUALE for user entered sleep', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SleepDetailModal(
            sleepPct: 88,
            durationMin: 450,
            sleepNeedMin: 480,
            sleepDebtMin: 30,
            lightSleepMin: 220,
            deepSleepMin: 110,
            remSleepMin: 100,
            awakeMin: 20,
            efficiencyPct: 95.5,
            consistencyPct: 82.0,
            provenance: 'USER_ENTERED',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('MANUALE'), findsOneWidget);
      expect(find.text('88%'), findsWidgets);
    });

    testWidgets('SleepDetailModal displays ProvenanceBadge with PARZIALE for partial sleep', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SleepDetailModal(
            sleepPct: 65,
            durationMin: 300,
            sleepNeedMin: 480,
            sleepDebtMin: 60,
            lightSleepMin: 150,
            deepSleepMin: 70,
            remSleepMin: 60,
            awakeMin: 20,
            efficiencyPct: 92.0,
            consistencyPct: 75.0,
            provenance: 'PARTIAL',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('PARZIALE'), findsOneWidget);
      expect(find.text('65%'), findsWidgets);
    });
  });
}
