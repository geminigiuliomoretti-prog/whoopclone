import 'package:flutter_test/flutter_test.dart';
import 'package:whoop_clone/data/services/noop_workout_detector.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WHOOP AutoWorkoutDetector False Positive Sensitivity Tests', () {
    test('FC moderata (20% HRR) e movimento lieve (0.040g) per 15 min NON innescano un allenamento', () {
      final detector = AutoWorkoutDetector(
        restHr: 60.0,
        maxHr: 190.0,
        alphaTrigger: 0.35, // 35% HRR -> hrTrigger = 60 + 0.35 * 130 = 105.5 bpm
        enmoMotionThresh: 0.120,
      );

      final now = DateTime.now();

      // Simula 15 minuti (900 campioni a 1Hz) con FC = 86 bpm (20% HRR) ed ENMO = 0.040g
      for (int i = 0; i < 900; i++) {
        detector.ingestSensorFrame(
          now.add(Duration(seconds: i)),
          86, // FC sotto la soglia di innesco 105.5 bpm
          enmo: 0.040, // Movimento sotto la soglia 0.120g
        );
      }

      // Lo stato deve rimanere su idleMonitoring (nessun falso positivo)
      expect(detector.state, equals(AutoWorkoutState.idleMonitoring));
    });

    test('FC elevata ma movimento nullo/lieve (0.040g) NON innesca allenamento automatico', () {
      final detector = AutoWorkoutDetector(
        restHr: 60.0,
        maxHr: 190.0,
        alphaTrigger: 0.35,
        enmoMotionThresh: 0.120,
      );

      final now = DateTime.now();

      // Simula 15 minuti con FC = 120 bpm ma ENMO = 0.040g (es. emozione/caffè da fermo)
      for (int i = 0; i < 900; i++) {
        detector.ingestSensorFrame(
          now.add(Duration(seconds: i)),
          120,
          enmo: 0.040,
        );
      }

      expect(detector.state, equals(AutoWorkoutState.idleMonitoring));
    });
  });
}
