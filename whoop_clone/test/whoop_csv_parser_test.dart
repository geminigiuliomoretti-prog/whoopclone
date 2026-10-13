import 'package:flutter_test/flutter_test.dart';
import 'package:whoop_clone/data/services/whoop_csv_parser.dart';
import 'package:whoop_clone/data/services/baseline_calculator.dart';
import 'package:whoop_clone/data/models/ciclo_fisiologico.dart';
import 'package:whoop_clone/data/models/sonno.dart';

void main() {
  group('WhoopCsvParser Tests', () {
    test('parseCsv handles quotes, commas, escapes and empty values', () {
      const csv = '''col1,col2,col3
val1,"val, with comma",val3
"val with ""escaped"" quote",,val6''';

      final records = WhoopCsvParser.parseCsv(csv);
      expect(records.length, 3);
      expect(records[0], ['col1', 'col2', 'col3']);
      expect(records[1], ['val1', 'val, with comma', 'val3']);
      expect(records[2], ['val with "escaped" quote', '', 'val6']);
    });

    test('parseCicliFisiologici extracts authentic measurements without fake data', () {
      const sample = '''Ora di inizio ciclo,Ora di fine ciclo,Fuso orario ciclo,Punteggio di recupero %,Frequenza cardiaca a riposo (bpm),Variabilità della frequenza cardiaca (ms),Temp. cutanea (C),Ossigeno nel sangue %,Sforzo giornaliero,Energia bruciata (cal),FC max. (bpm),FC media (bpm),Inizio del sonno,Inizio del risveglio,Andamento del sonno %,Frequenza respiratoria (rpm),Durata del sonno (min),Tempo a letto (min),Durata del sonno leggero (min),Durata profondo (SWS) (min),Durata REM (min),Durata del risveglio (min),Sonno richiesto (min),Sonno arretrato (min),Efficienza del sonno %,Regolarità del sonno %
2026-05-03 00:52:20,,UTC+02:00,68,55,67,34.19,93.65,,,,,2026-05-03 00:52:20,2026-05-03 08:57:17,79,14.2,428,484,209,90,129,56,634,96,88,76
2026-05-02 00:11:47,2026-05-03 00:52:20,UTC+02:00,50,56,61,33.99,95.68,16.0,3048,170,73,2026-05-02 00:11:47,2026-05-02 09:24:20,81,13.9,502,552,239,131,132,50,651,127,90,70
2026-03-17 07:27:47,2026-03-18 00:00:57,UTC+01:00,,,,,,0.8,1104,107,71,,,,,,,,,,,,,,
''';

      final cycles = WhoopCsvParser.parseCicliFisiologici(sample);
      expect(cycles.length, 3);

      // Row 1 (active cycle):
      expect(cycles[0].dataIso, '2026-05-03');
      expect(cycles[0].recoveryScore, 68.0);
      expect(cycles[0].rhrNotte, 55.0);
      expect(cycles[0].hrvNotte, 67.0);
      expect(cycles[0].tempCutaneaC, 34.19);
      expect(cycles[0].spo2Pct, 93.65);
      expect(cycles[0].strainGiornaliero, isNull); // Empty in export, MUST BE NULL, not 0!
      expect(cycles[0].calorieTot, isNull);

      // Row 2:
      expect(cycles[1].dataIso, '2026-05-02');
      expect(cycles[1].recoveryScore, 50.0);
      expect(cycles[1].strainGiornaliero, 16.0);
      expect(cycles[1].calorieTot, 3048);

      // Row 3 (cycle without sleep/recovery):
      expect(cycles[2].dataIso, '2026-03-17');
      expect(cycles[2].recoveryScore, isNull);
      expect(cycles[2].hrvNotte, isNull);
      expect(cycles[2].strainGiornaliero, 0.8);
      expect(cycles[2].calorieTot, 1104);
    });

    test('parseSonno extracts sleep sessions including naps', () {
      const sample = '''Ora di inizio ciclo,Ora di fine ciclo,Fuso orario ciclo,Inizio del sonno,Inizio del risveglio,Andamento del sonno %,Frequenza respiratoria (rpm),Durata del sonno (min),Tempo a letto (min),Durata del sonno leggero (min),Durata profondo (SWS) (min),Durata REM (min),Durata del risveglio (min),Sonno richiesto (min),Sonno arretrato (min),Efficienza del sonno %,Regolarità del sonno %,Riposo breve
2026-05-03 00:52:20,,UTC+02:00,2026-05-03 00:52:20,2026-05-03 08:57:17,79,14.2,428,484,209,90,129,56,634,96,88,76,false
2026-03-18 22:45:24,2026-03-19 23:35:11,UTC+01:00,2026-03-19 07:30:46,2026-03-19 09:55:46,15,13.0,111,145,68,27,16,34,623,127,76,,true
''';

      final sleeps = WhoopCsvParser.parseSonno(sample);
      expect(sleeps.length, 2);
      expect(sleeps[0].durataTotMin, 428);
      expect(sleeps[0].sonnoProfondoMin, 90);
      expect(sleeps[0].sonnoRemMin, 129);
      expect(sleeps[0].provenance, 'WHOOP_IMPORT');

      expect(sleeps[1].durataTotMin, 111);
      expect(sleeps[1].provenance, 'WHOOP_NAP');
    });

    test('parseAllenamenti extracts workouts and zone percentages', () {
      const sample = '''Ora di inizio ciclo,Ora di fine ciclo,Fuso orario ciclo,Ora di inizio allenamento,Ora di fine allenamento,Durata (min),Nome attività,Sforzo richiesto dall'attività,Energia bruciata (cal),FC max. (bpm),FC media (bpm),Zona FC 1 %,Zona FC 2 %,Zona FC 3 %,Zona FC 4 %,Zona FC 5 %,GPS abilitato
2026-05-03 00:52:20,,UTC+02:00,2026-05-03 18:12:00,2026-05-03 18:40:29,28,Tennis,5.0,90.0,140,109,41,0,0,0,0,false
2026-04-29 22:44:53,2026-05-01 00:19:14,UTC+02:00,2026-04-30 17:03:00,2026-04-30 18:01:29,58,Tennis,12.9,591.0,183,145,27,40,26,5,0,false
''';

      final workouts = WhoopCsvParser.parseAllenamenti(sample);
      expect(workouts.length, 2);
      expect(workouts[0].nomeAttivita, 'Tennis');
      expect(workouts[0].durataMin, 28);
      expect(workouts[0].strainAttivita, 5.0);
      expect(workouts[0].calorie, 90);
      expect(workouts[0].hrMax, 140);
      expect(workouts[0].hrMedia, 109);
      expect(workouts[0].zoneZ1Pct, 41.0);

      expect(workouts[1].nomeAttivita, 'Tennis');
      expect(workouts[1].strainAttivita, 12.9);
      expect(workouts[1].calorie, 591);
      expect(workouts[1].hrMax, 183);
    });

    test('parseVociDiario extracts diary items and boolean answers', () {
      const sample = '''Ora di inizio ciclo,Ora di fine ciclo,Fuso orario ciclo,Testo domanda,Risposta affermativa,Note
2026-05-03 00:52:20,,UTC+02:00,Hai assunto farmaci antistaminici?,true,
2026-05-03 00:52:20,,UTC+02:00,Hai dormito in un ambiente rumoroso?,false,
2026-03-05 23:19:23,2026-03-06 23:01:55,UTC+01:00,Hai provato ansia o nervosismo?,true,Torneo e tachicardia
''';

      final diary = WhoopCsvParser.parseVociDiario(sample);
      expect(diary.length, 3);
      expect(diary[0].chiaveDomanda, 'Hai assunto farmaci antistaminici?');
      expect(diary[0].rispostaBool, isTrue);
      expect(diary[0].note, isNull);

      expect(diary[1].chiaveDomanda, 'Hai dormito in un ambiente rumoroso?');
      expect(diary[1].rispostaBool, isFalse);

      expect(diary[2].chiaveDomanda, 'Hai provato ansia o nervosismo?');
      expect(diary[2].rispostaBool, isTrue);
      expect(diary[2].note, 'Torneo e tachicardia');
    });

    test('BaselineCalculator calculates comprehensive statistics from imported data', () {
      final cycles = [
        const CicloFisiologico(dataIso: '2026-05-01', hrvNotte: 70, rhrNotte: 50, tempCutaneaC: 34.2, spo2Pct: 96.0, frequenzaRespiratoriaRpm: 14.0),
        const CicloFisiologico(dataIso: '2026-05-02', hrvNotte: 60, rhrNotte: 56, tempCutaneaC: 34.4, spo2Pct: 95.0, frequenzaRespiratoriaRpm: 14.2),
        const CicloFisiologico(dataIso: '2026-05-03', hrvNotte: 50, rhrNotte: 60, tempCutaneaC: 34.6, spo2Pct: 94.0, frequenzaRespiratoriaRpm: 14.4),
      ];

      final sleeps = [
        const Sonno(dataIso: '2026-05-01', oraInizio: '2026-05-01T00:00:00.000Z', oraFine: '2026-05-01T08:00:00.000Z', durataTotMin: 480, sonnoProfondoMin: 100, sonnoRemMin: 120, efficienzaPct: 90),
        const Sonno(dataIso: '2026-05-02', oraInizio: '2026-05-02T00:00:00.000Z', oraFine: '2026-05-02T07:30:00.000Z', durataTotMin: 450, sonnoProfondoMin: 90, sonnoRemMin: 110, efficienzaPct: 88),
        const Sonno(dataIso: '2026-05-03', oraInizio: '2026-05-03T00:00:00.000Z', oraFine: '2026-05-03T07:00:00.000Z', durataTotMin: 420, sonnoProfondoMin: 80, sonnoRemMin: 100, efficienzaPct: 92),
      ];

      final baselines = BaselineCalculator.calculateAllBaselines(cycles: cycles, sleeps: sleeps);
      expect(baselines.containsKey('hrv'), isTrue);
      expect(baselines.containsKey('rhr'), isTrue);
      expect(baselines.containsKey('respiratory_rate'), isTrue);
      expect(baselines.containsKey('skin_temp'), isTrue);
      expect(baselines.containsKey('spo2'), isTrue);
      expect(baselines.containsKey('sleep_duration'), isTrue);

      final hrvBase = baselines['hrv']!;
      expect(hrvBase.mean, 60.0);
      expect(hrvBase.median, 60.0);
      expect(hrvBase.sampleCount, 3);
      expect(hrBaseExtraLn(hrvBase), isNotNull);

      final rhrBase = baselines['rhr']!;
      expect(rhrBase.median, 56.0);
      expect(rhrBase.sampleCount, 3);
    });
  });
}

double? hrBaseExtraLn(dynamic hrvBase) {
  return (hrvBase.extraStats['mean_ln_rmssd'] as num?)?.toDouble();
}
