import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whoop_clone/core/theme/nature_theme.dart';
import 'package:whoop_clone/core/utils/clock.dart';
import 'package:whoop_clone/views/widgets/nature/nature_scene.dart';
import 'package:whoop_clone/views/widgets/recovery_detail_modal.dart';
import 'package:whoop_clone/views/widgets/sleep_detail_modal.dart';
import 'package:whoop_clone/views/widgets/nature/atmospheric_hero_header.dart';

void main() {
  group('Asset Assignment & Home Time-Of-Day Strict Isolation Tests', () {
    test('TimeOfDayPeriod maps exactly to the 4 realistic mountain assets', () {
      expect(TimeOfDayPeriod.morning.assetPath, 'assets/images/nature/morning.jpg');
      expect(TimeOfDayPeriod.midday.assetPath, 'assets/images/nature/midday.jpg');
      expect(TimeOfDayPeriod.afternoon.assetPath, 'assets/images/nature/afternoon.jpg');
      expect(TimeOfDayPeriod.night.assetPath, 'assets/images/nature/night.jpg');
    });

    test('TimeOfDayPeriod resolves correctly based on hour of day', () {
      // Mattina: 05:00 - 11:59
      expect(getTimeOfDayPeriod(DateTime(2026, 10, 7, 5, 0)), TimeOfDayPeriod.morning);
      expect(getTimeOfDayPeriod(DateTime(2026, 10, 7, 8, 30)), TimeOfDayPeriod.morning);
      expect(getTimeOfDayPeriod(DateTime(2026, 10, 7, 11, 59)), TimeOfDayPeriod.morning);

      // Mezzogiorno / Giorno: 12:00 - 16:59
      expect(getTimeOfDayPeriod(DateTime(2026, 10, 7, 12, 0)), TimeOfDayPeriod.midday);
      expect(getTimeOfDayPeriod(DateTime(2026, 10, 7, 14, 15)), TimeOfDayPeriod.midday);
      expect(getTimeOfDayPeriod(DateTime(2026, 10, 7, 16, 59)), TimeOfDayPeriod.midday);

      // Pomeriggio: 17:00 - 20:59
      expect(getTimeOfDayPeriod(DateTime(2026, 10, 7, 17, 0)), TimeOfDayPeriod.afternoon);
      expect(getTimeOfDayPeriod(DateTime(2026, 10, 7, 19, 30)), TimeOfDayPeriod.afternoon);
      expect(getTimeOfDayPeriod(DateTime(2026, 10, 7, 20, 59)), TimeOfDayPeriod.afternoon);

      // Sera / Notte: 21:00 - 04:59
      expect(getTimeOfDayPeriod(DateTime(2026, 10, 7, 21, 0)), TimeOfDayPeriod.night);
      expect(getTimeOfDayPeriod(DateTime(2026, 10, 7, 23, 45)), TimeOfDayPeriod.night);
      expect(getTimeOfDayPeriod(DateTime(2026, 10, 7, 2, 0)), TimeOfDayPeriod.night);
      expect(getTimeOfDayPeriod(DateTime(2026, 10, 7, 4, 59)), TimeOfDayPeriod.night);
    });

    testWidgets('NatureScene in Home renders morning realistic mountain at morning', (tester) async {
      final testClock = TestClock(DateTime(2026, 10, 7, 8, 0));
      Clock.setClock(testClock);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: NatureScene(
              mood: NatureMood.recovery,
            ),
          ),
        ),
      );

      final imageFinder = find.byType(Image);
      expect(imageFinder, findsOneWidget);
      final imageWidget = tester.widget<Image>(imageFinder);
      final assetImage = imageWidget.image as AssetImage;

      expect(assetImage.assetName, 'assets/images/nature/morning.jpg');
      expect(assetImage.assetName, isNot('assets/images/nature/recovery_atmosphere.png'));
      expect(assetImage.assetName, isNot('assets/images/nature/sleep_atmosphere.png'));

      Clock.reset();
    });

    testWidgets('NatureScene in Home renders midday realistic mountain at midday', (tester) async {
      final testClock = TestClock(DateTime(2026, 10, 7, 13, 0));
      Clock.setClock(testClock);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: NatureScene(
              mood: NatureMood.strain,
            ),
          ),
        ),
      );

      final imageFinder = find.byType(Image);
      expect(imageFinder, findsOneWidget);
      final imageWidget = tester.widget<Image>(imageFinder);
      final assetImage = imageWidget.image as AssetImage;

      expect(assetImage.assetName, 'assets/images/nature/midday.jpg');

      Clock.reset();
    });

    testWidgets('NatureScene in Home renders afternoon realistic mountain in the afternoon', (tester) async {
      final testClock = TestClock(DateTime(2026, 10, 7, 18, 0));
      Clock.setClock(testClock);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: NatureScene(),
          ),
        ),
      );

      final imageFinder = find.byType(Image);
      expect(imageFinder, findsOneWidget);
      final imageWidget = tester.widget<Image>(imageFinder);
      final assetImage = imageWidget.image as AssetImage;

      expect(assetImage.assetName, 'assets/images/nature/afternoon.jpg');

      Clock.reset();
    });

    testWidgets('NatureScene in Home renders night realistic mountain at night', (tester) async {
      final testClock = TestClock(DateTime(2026, 10, 7, 22, 30));
      Clock.setClock(testClock);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: NatureScene(
              mood: NatureMood.sleep,
            ),
          ),
        ),
      );

      final imageFinder = find.byType(Image);
      expect(imageFinder, findsOneWidget);
      final imageWidget = tester.widget<Image>(imageFinder);
      final assetImage = imageWidget.image as AssetImage;

      expect(assetImage.assetName, 'assets/images/nature/night.jpg');
      expect(assetImage.assetName, isNot('assets/images/nature/sleep_atmosphere.png'));

      Clock.reset();
    });

    testWidgets('Recovery screen strictly uses stylized recovery_atmosphere.png and NOT home images', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: RecoveryDetailModal(
            recoveryPct: 82.0,
            hrvMs: 65.0,
            fcrBpm: 52,
            respRateRpm: 14.5,
            spo2Pct: 98.0,
            tempDeltaC: 0.1,
          ),
        ),
      );

      final headerFinder = find.byType(AtmosphericHeroHeader);
      expect(headerFinder, findsOneWidget);
      final headerWidget = tester.widget<AtmosphericHeroHeader>(headerFinder);

      expect(headerWidget.imageAsset, 'assets/images/nature/recovery_atmosphere.png');
      expect(headerWidget.imageAsset, isNot('assets/images/nature/sleep_atmosphere.png'));
      expect(headerWidget.imageAsset, isNot('assets/images/nature/morning.jpg'));
      expect(headerWidget.imageAsset, isNot('assets/images/nature/night.jpg'));
    });

    testWidgets('Sleep screen strictly uses stylized sleep_atmosphere.png and NOT home images', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SleepDetailModal(
            sleepPct: 75.0,
            durationMin: 450,
            sleepNeedMin: 480,
            sleepDebtMin: 30,
            lightSleepMin: 220,
            deepSleepMin: 110,
            remSleepMin: 90,
            awakeMin: 30,
            efficiencyPct: 94.0,
            consistencyPct: 88.0,
          ),
        ),
      );

      final headerFinder = find.byType(AtmosphericHeroHeader);
      expect(headerFinder, findsOneWidget);
      final headerWidget = tester.widget<AtmosphericHeroHeader>(headerFinder);

      expect(headerWidget.imageAsset, 'assets/images/nature/sleep_atmosphere.png');
      expect(headerWidget.imageAsset, isNot('assets/images/nature/recovery_atmosphere.png'));
      expect(headerWidget.imageAsset, isNot('assets/images/nature/night.jpg'));
    });
  });
}
