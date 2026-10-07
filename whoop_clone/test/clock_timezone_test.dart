import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:whoop_clone/core/utils/clock.dart';
import 'package:whoop_clone/data/database/database_helper.dart';
import 'package:whoop_clone/data/models/allenamento.dart';
import 'package:whoop_clone/data/models/ciclo_fisiologico.dart';
import 'package:whoop_clone/data/models/sonno.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  DatabaseHelper.isTestMode = true;

  group('TIM-01: Clock and Timezone Tests', () {
    tearDown(() {
      Clock.reset();
    });

    test('Clock.formatOffset formats offsets correctly according to ISO-8601', () {
      expect(Clock.formatOffset(const Duration(hours: 2)), equals('+02:00'));
      expect(Clock.formatOffset(const Duration(hours: 1)), equals('+01:00'));
      expect(Clock.formatOffset(const Duration(hours: -5)), equals('-05:00'));
      expect(Clock.formatOffset(const Duration(hours: 5, minutes: 30)), equals('+05:30'));
      expect(Clock.formatOffset(const Duration(hours: -3, minutes: -30)), equals('-03:30'));
      expect(Clock.formatOffset(Duration.zero), equals('+00:00'));
    });

    test('TestClock allows freezing time, overriding timezone offset, and advancing time', () {
      final fixedUtc = DateTime.utc(2026, 10, 5, 8, 0, 0);
      final testClock = TestClock(
        fixedUtc,
        timeZoneOffset: const Duration(hours: 2),
      );

      Clock.setClock(testClock);

      expect(Clock.current.now(), equals(fixedUtc));
      expect(Clock.current.nowUtc(), equals(fixedUtc));
      expect(Clock.current.timeZoneOffset, equals(const Duration(hours: 2)));
      expect(Clock.current.formattedTimeZoneOffset, equals('+02:00'));

      // Advance by 15 minutes
      testClock.advance(const Duration(minutes: 15));
      expect(Clock.current.now(), equals(fixedUtc.add(const Duration(minutes: 15))));

      // Simulate DST transition (+02:00 to +01:00)
      testClock.setTimeZoneOffset(const Duration(hours: 1));
      expect(Clock.current.formattedTimeZoneOffset, equals('+01:00'));
    });

    test('Domain models dynamically resolve fusoOrario from Clock.current', () {
      final testClock = TestClock(
        DateTime.utc(2026, 10, 5, 12, 0),
        timeZoneOffset: const Duration(hours: 3),
      );
      Clock.setClock(testClock);

      const ciclo = CicloFisiologico(
        dataIso: '2026-10-05',
        recoveryScore: 85,
        rhrNotte: 52,
        hrvNotte: 78.0,
      );
      expect(ciclo.fusoOrario, equals('+03:00'));

      const sonno = Sonno(
        dataIso: '2026-10-05',
        oraInizio: '2026-10-04T23:00:00Z',
        oraFine: '2026-10-05T07:00:00Z',
        durataTotMin: 480,
        sonnoProfondoMin: 90,
        sonnoRemMin: 110,
      );
      expect(sonno.fusoOrario, equals('+03:00'));

      final allenamento = Allenamento(
        nomeAttivita: 'Corsa',
        sforzoRichiesto: 12.5,
      );
      expect(allenamento.fusoOrario, equals('+03:00'));

      // Simulate timezone change to UTC-4 (e.g. traveling to New York in standard time)
      testClock.setTimeZoneOffset(const Duration(hours: -4));
      expect(ciclo.fusoOrario, equals('-04:00'));
      expect(sonno.fusoOrario, equals('-04:00'));
      expect(allenamento.fusoOrario, equals('-04:00'));
    });

    test('DatabaseHelper persists timestamp_utc_ms as positive integer in UTC', () async {
      final dbHelper = DatabaseHelper();
      final db = await dbHelper.database;

      final testUtcTime = DateTime.utc(2026, 10, 5, 14, 30, 0);
      final testClock = TestClock(testUtcTime);
      Clock.setClock(testClock);

      // Insert stress measurement
      final id = await dbHelper.insertMisurazioneStress('2026-10-05', 1.85, 68.0, 62);
      expect(id, isPositive);

      final rows = await db.query(
        DatabaseHelper.tableMisurazioniStress,
        where: 'id = ?',
        whereArgs: [id],
      );

      expect(rows.length, equals(1));
      final row = rows.first;
      expect(row['timestamp_utc_ms'], equals(testUtcTime.millisecondsSinceEpoch));
      expect(row['timestamp_utc_ms'] is int, isTrue);
      expect((row['timestamp_utc_ms'] as int) > 0, isTrue);
    });
  });
}
