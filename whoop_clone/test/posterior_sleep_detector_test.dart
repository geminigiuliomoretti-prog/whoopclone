import 'package:flutter_test/flutter_test.dart';
import 'package:whoop_clone/data/services/posterior_sleep_detector.dart';

void main() {
  group('PosteriorSleepDetector Tests (Phase 5: SLP-01..08)', () {
    late PosteriorSleepDetector detector;

    setUp(() {
      detector = PosteriorSleepDetector();
    });

    test('1. Rileva sonno notturno (23:30 -> 07:15) salvato con data ISO del giorno di risveglio (SLP-02)', () {
      final nightStart = DateTime.utc(2026, 10, 4, 23, 30);
      final nightEnd = DateTime.utc(2026, 10, 5, 7, 15);

      final records = <Map<String, dynamic>>[];

      // 15 minuti di veglia iniziale prima di andare a dormire
      for (int m = 0; m < 15; m++) {
        final t = nightStart.subtract(Duration(minutes: 15 - m));
        records.add({
          'timestamp_utc_ms': t.millisecondsSinceEpoch,
          'bpm': 85.0,
          'accel_enmo': 0.120, // movimento
        });
      }

      // 465 minuti di sonno notturno (campionati ogni 30s: ENMO basso 0.005g, HR basso 52 bpm)
      final totalSec = nightEnd.difference(nightStart).inSeconds;
      for (int s = 0; s < totalSec; s += 30) {
        final t = nightStart.add(Duration(seconds: s));
        records.add({
          'timestamp_utc_ms': t.millisecondsSinceEpoch,
          'bpm': 52.0,
          'accel_enmo': 0.005, // quiete
        });
      }

      // 30 minuti di veglia sostenuta al risveglio
      for (int m = 0; m < 30; m++) {
        final t = nightEnd.add(Duration(minutes: m));
        records.add({
          'timestamp_utc_ms': t.millisecondsSinceEpoch,
          'bpm': 90.0,
          'accel_enmo': 0.150, // attività motoria
        });
      }

      final sessions = detector.analyzeTelemetryRecords(records, rhrBaseline: 52.0);

      expect(sessions.length, 1);
      final night = sessions.first;

      // REQUISITO IMPERATIVO SLP-02: data_iso deve essere 2026-10-05 (giorno di risveglio)
      final expectedWakeIso = nightEnd.toLocal().toIso8601String().substring(0, 10);
      expect(night.wakeDateIso, expectedWakeIso);
      expect(night.wakeDateIso, '2026-10-05');
      expect(night.isNap, isFalse);
      expect(night.durationMinutes, greaterThanOrEqualTo(460));
      expect(night.provenance, 'REAL');
      expect(night.coveragePct, greaterThanOrEqualTo(95.0));
    });

    test('2. Rileva pisolino pomeridiano (14:00 -> 14:45) come sessione nap separata', () {
      final napStart = DateTime.utc(2026, 10, 5, 14, 0);
      final napEnd = DateTime.utc(2026, 10, 5, 14, 45);

      final records = <Map<String, dynamic>>[];

      // 20 minuti di veglia precedente
      for (int m = 0; m < 20; m++) {
        final t = napStart.subtract(Duration(minutes: 20 - m));
        records.add({
          'timestamp_utc_ms': t.millisecondsSinceEpoch,
          'bpm': 88.0,
          'accel_enmo': 0.100,
        });
      }

      // 45 minuti di sonno/pisolino
      for (int m = 0; m < 45; m++) {
        final t = napStart.add(Duration(minutes: m));
        records.add({
          'timestamp_utc_ms': t.millisecondsSinceEpoch,
          'bpm': 55.0,
          'accel_enmo': 0.008,
        });
      }

      // 20 minuti di veglia successiva
      for (int m = 0; m < 20; m++) {
        final t = napEnd.add(Duration(minutes: m));
        records.add({
          'timestamp_utc_ms': t.millisecondsSinceEpoch,
          'bpm': 92.0,
          'accel_enmo': 0.140,
        });
      }

      final sessions = detector.analyzeTelemetryRecords(records, rhrBaseline: 55.0);

      expect(sessions.length, 1);
      final nap = sessions.first;
      expect(nap.isNap, isTrue); // Durata < 180m -> Nap!
      expect(nap.durationMinutes, greaterThanOrEqualTo(40));
      expect(nap.durationMinutes, lessThan(60));
      expect(nap.wakeDateIso, '2026-10-05');
    });

    test('3. Tolleranza micro-risveglio di 10 minuti all\'interno del sonno (sessione consolidata)', () {
      final start = DateTime.utc(2026, 10, 5, 1, 0);
      final records = <Map<String, dynamic>>[];

      // 120 minuti sonno
      for (int m = 0; m < 120; m++) {
        records.add({
          'timestamp_utc_ms': start.add(Duration(minutes: m)).millisecondsSinceEpoch,
          'bpm': 50.0,
          'accel_enmo': 0.004,
        });
      }

      // 10 minuti micro-risveglio / movimento notturno
      for (int m = 120; m < 130; m++) {
        records.add({
          'timestamp_utc_ms': start.add(Duration(minutes: m)).millisecondsSinceEpoch,
          'bpm': 80.0,
          'accel_enmo': 0.090, // movimento
        });
      }

      // 150 minuti sonno successivo
      for (int m = 130; m < 280; m++) {
        records.add({
          'timestamp_utc_ms': start.add(Duration(minutes: m)).millisecondsSinceEpoch,
          'bpm': 51.0,
          'accel_enmo': 0.006,
        });
      }

      // 20 minuti risveglio finale
      for (int m = 280; m < 300; m++) {
        records.add({
          'timestamp_utc_ms': start.add(Duration(minutes: m)).millisecondsSinceEpoch,
          'bpm': 95.0,
          'accel_enmo': 0.160,
        });
      }

      final sessions = detector.analyzeTelemetryRecords(records, rhrBaseline: 50.0);

      // Deve essere un'unica sessione di sonno consolidata
      expect(sessions.length, 1);
      final session = sessions.first;
      expect(session.isNap, isFalse); // 270+ min >= 180 min
      expect(session.durationMinutes, greaterThanOrEqualTo(270));
    });

    test('4. Marcatura PARTIAL se copertura campioni < 70% (SLP-04)', () {
      final start = DateTime.utc(2026, 10, 5, 0, 0);
      final records = <Map<String, dynamic>>[];

      // In 240 minuti di finestra, registriamo solo 120 minuti di dati (50% coverage)
      for (int m = 0; m < 240; m += 2) {
        records.add({
          'timestamp_utc_ms': start.add(Duration(minutes: m)).millisecondsSinceEpoch,
          'bpm': 52.0,
          'accel_enmo': 0.005,
        });
      }

      // 20 minuti di veglia successiva
      for (int m = 240; m < 260; m++) {
        records.add({
          'timestamp_utc_ms': start.add(Duration(minutes: m)).millisecondsSinceEpoch,
          'bpm': 95.0,
          'accel_enmo': 0.150,
        });
      }

      final sessions = detector.analyzeTelemetryRecords(records, rhrBaseline: 52.0);

      expect(sessions.length, 1);
      final session = sessions.first;
      expect(session.coveragePct, lessThan(70.0));
      expect(session.provenance, 'PARTIAL');
    });

    test('5. Non inventa sonno in assenza di dati o con sola veglia diurna', () {
      final emptySessions = detector.analyzeTelemetryRecords([]);
      expect(emptySessions, isEmpty);

      // Solo veglia diurna
      final wakeRecords = <Map<String, dynamic>>[];
      final start = DateTime.utc(2026, 10, 5, 10, 0);
      for (int m = 0; m < 120; m++) {
        wakeRecords.add({
          'timestamp_utc_ms': start.add(Duration(minutes: m)).millisecondsSinceEpoch,
          'bpm': 85.0,
          'accel_enmo': 0.110,
        });
      }

      final wakeSessions = detector.analyzeTelemetryRecords(wakeRecords);
      expect(wakeSessions, isEmpty);
    });
  });
}
