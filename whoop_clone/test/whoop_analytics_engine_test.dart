import 'package:flutter_test/flutter_test.dart';
import 'package:whoop_clone/domain/analytics/whoop_analytics_engine.dart';

void main() {
  group('Reverse-Engineered WHOOP Stress & Strain Engine Tests', () {
    // ═══════════════════════════════════════════════════════════════════════
    // 1. TEST STRESS: Crollo HRV & FC Elevata (z_HRV = 1.5, z_HR = 1.2) → > 2.0
    // ═══════════════════════════════════════════════════════════════════════
    test('1. Test Stress: Crollo HRV e FC elevata (z_HRV = 1.5, z_HR = 1.2) → Stress in Fascia Elevata (>2.0)', () {
      final stress = WhoopAnalyticsEngine.calculateStressScore(
        hrLive: 60.0,
        hrvLiveMs: 65.0,
        zHrvOverride: 1.5,
        zHrOverride: 1.2,
        accMagnitude: 1.0, // Nessun movimento (stasi)
      );

      final category = WhoopAnalyticsEngine.getStressCategory(stress);

      expect(stress, greaterThan(2.0),
          reason: 'Un elevato bilancio simpatovagale (z_HRV = 1.5, z_HR = 1.2) deve produrre uno Stress > 2.0');
      expect(category, equals('Elevato'),
          reason: 'Lo stress > 2.0 deve rientrare nella fascia operativa Elevato');
    });

    // ═══════════════════════════════════════════════════════════════════════
    // 2. TEST MOTION GATING: Accelerometro attivo (Acc > 1.2) attenua z_HR
    // ═══════════════════════════════════════════════════════════════════════
    test('2. Test Motion Gating: Acc > 1.2 attenua l\'effetto di z_HR sullo Stress', () {
      final staticStress = WhoopAnalyticsEngine.calculateStressScore(
        hrLive: 60.0,
        hrvLiveMs: 65.0,
        zHrvOverride: 1.5,
        zHrOverride: 1.2,
        accMagnitude: 1.0, // Stasi (f(Acc) = 1.0)
      );

      final activeMotionStress = WhoopAnalyticsEngine.calculateStressScore(
        hrLive: 60.0,
        hrvLiveMs: 65.0,
        zHrvOverride: 1.5,
        zHrOverride: 1.2,
        accMagnitude: 2.45, // Movimento (f(Acc) = 0.5)
      );

      expect(activeMotionStress, lessThan(staticStress),
          reason: 'L\'elevazione di HR dovuta al movimento deve essere attenuata dal filtro accelerometrico');
    });

    // ═══════════════════════════════════════════════════════════════════════
    // 3. TEST NON-ADDITIVITÀ STRAIN: L1 = 380 (12.8) + L2 = 210 (9.6) → L_tot = 590 (Day Strain ~14.6)
    // ═══════════════════════════════════════════════════════════════════════
    test('3. Test Non-Additività Strain: L1 = 380 (~12.8), L2 = 210 (~9.6) → L_tot = 590 (Day Strain ~14.6)', () {
      final strain1 = WhoopAnalyticsEngine.convertRawLoadToStrain(380.0);
      final strain2 = WhoopAnalyticsEngine.convertRawLoadToStrain(210.0);
      final dayStrain = WhoopAnalyticsEngine.convertRawLoadToStrain(380.0 + 210.0);

      expect(strain1, closeTo(12.8, 1.0),
          reason: 'Carico grezzo 380 deve produrre Strain ~12.8');
      expect(strain2, closeTo(9.6, 1.0),
          reason: 'Carico grezzo 210 deve produrre Strain ~9.6');
      expect(dayStrain, greaterThanOrEqualTo(14.0),
          reason: 'Carico cumulativo 590 deve produrre Day Strain >= 14.0');

      // Verifica concavità rigorosa: f(L1 + L2) < f(L1) + f(L2)
      expect(dayStrain, lessThan(strain1 + strain2),
          reason: 'Lo Strain giornaliero rispetta la disuguaglianza di concavità logaritmica e non è additivo (14.6 != 12.8 + 9.6)');
    });

    // ═══════════════════════════════════════════════════════════════════════
    // 4. TEST DI REGRESSIONE SU STRAIN, RECOVERY E SLEEP NEED
    // ═══════════════════════════════════════════════════════════════════════
    test('4. Strain a riposo: BPM = HR_rest → Strain ≈ 0.0', () {
      final hrStream = List<int>.filled(600, 60);
      final strain = WhoopAnalyticsEngine.calculateStrain(
        heartRateStream: hrStream,
        hrMax: 190,
        hrRest: 60,
      );
      expect(strain, closeTo(0.0, 0.1));
    });

    test('5. Recovery bilanciato: HRV e RHR nella media → Recovery ∈ [50, 65]', () {
      final recovery = WhoopAnalyticsEngine.calculateRecovery(
        hrvMssd: 45.0,
        hrv30dMean: 45.0,
        hrv30dStd: 12.0,
        rhrNight: 55,
        rhr30dMean: 55.0,
        rhr30dStd: 3.0,
        sleepPerformancePct: 85.0,
      );
      expect(recovery, greaterThanOrEqualTo(50));
      expect(recovery, lessThanOrEqualTo(65));
    });

    test('6. Sleep Need: Strain elevato incrementa il fabbisogno rispetto alla baseline', () {
      const int baseline = 480;
      final sleepNeedHigh = WhoopAnalyticsEngine.calculateSleepNeed(
        baselineMinutes: baseline,
        sleepDebtMinutes: 30,
        dayStrain: 18.0,
        napMinutes: 0,
      );
      expect(sleepNeedHigh, greaterThan(baseline));
    });
  });
}
