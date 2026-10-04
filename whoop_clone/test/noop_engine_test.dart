import 'dart:math';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:whoop_clone/data/database/database_helper.dart';
import 'package:whoop_clone/data/services/noop_analytics_engine.dart';
import 'package:whoop_clone/data/services/noop_ble_decoder.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    DatabaseHelper.isTestMode = true;
  });

  group('NOOP Scientific Metric Engine Tests (Task Force 1996, TRIMP, Plews/Buchheit)', () {
    test('1. Calcolo Autentico rMSSD (Task Force 1996) con sequenza nota RR', () {
      // Sequenza di test specificata nel prompt: RR = [800, 850, 810, 860, 805]
      final rrSequence = [800.0, 850.0, 810.0, 860.0, 805.0];
      
      // Calcolo matematico manuale:
      // Δ1 = 850 - 800 = +50 -> 2500
      // Δ2 = 810 - 850 = -40 -> 1600
      // Δ3 = 860 - 810 = +50 -> 2500
      // Δ4 = 805 - 860 = -55 -> 3025
      // Somma = 9625, N - 1 = 4, Media = 2406.25, sqrt = 49.0535... ms
      final rmssd = NoopAnalyticsEngine.calculateRmssd(rrSequence);
      expect(rmssd, isNotNull);
      expect(rmssd!, closeTo(49.05, 0.5));
    });

    test('2. Rigetto battiti ectopici isolati (|ΔRR| > 200 ms)', () {
      // Sequenza contenente un artefatto ectopico spurio (1200 ms da 800 ms = Δ400 ms)
      final rrWithEctopic = [800.0, 850.0, 1250.0, 850.0, 800.0];
      
      // Senza filtro: Δ = 50^2 + 400^2 + 400^2 + 50^2 = 325000 / 4 = 81250 -> sqrt ≈ 285 ms
      // Con filtro ectopico: scarta i salti > 200 ms e calcola solo sui delta validi (50^2 + 50^2 = 5000 / 2 = 2500 -> sqrt = 50.0 ms)
      final filteredRmssd = NoopAnalyticsEngine.calculateRmssd(rrWithEctopic, filterEctopic: true);
      expect(filteredRmssd, isNotNull);
      expect(filteredRmssd!, closeTo(50.0, 1.0));
    });

    test('3. Calcolo Day Strain con rigorosa esclusione della finestra di sonno notturno', () {
      final sleepStart = DateTime(2026, 8, 15, 0, 0, 0);
      final sleepEnd = DateTime(2026, 8, 15, 7, 0, 0);

      // Flusso di 3600 campioni a 150 bpm durante la notte (ore 02:00-03:00)
      final nocturnalStream = <Map<String, dynamic>>[];
      for (int i = 0; i < 600; i++) {
        nocturnalStream.add({
          'timestamp': sleepStart.add(Duration(seconds: 3600 + i)).toIso8601String(),
          'bpm': 150,
          'accel_enmo': 0.005,
        });
      }

      // Strain calcolato includendo i timestamp notturni ma impostando la finestra di sonno:
      // Deve restituire 0.0 perché tutti i campioni appartengono al sonno
      final strainOnlySleep = NoopAnalyticsEngine.calculateDayStrain(
        telemetryStream: nocturnalStream,
        hrMax: 190.0,
        hrRest: 55.0,
        sleepStartTime: sleepStart,
        sleepEndTime: sleepEnd,
      );
      expect(strainOnlySleep, equals(0.0));

      // Flusso diurno (ore 10:00-10:30, 1800 campioni a 150 bpm)
      final daytimeStream = <Map<String, dynamic>>[];
      for (int i = 0; i < 1800; i++) {
        daytimeStream.add({
          'timestamp': DateTime(2026, 8, 15, 10, 0, 0).add(Duration(seconds: i)).toIso8601String(),
          'bpm': 150,
          'accel_enmo': 0.25,
        });
      }

      // Flusso combinato (Notte + Giorno): solo il giorno deve essere accumulato
      final combinedStream = [...nocturnalStream, ...daytimeStream];
      final combinedStrain = NoopAnalyticsEngine.calculateDayStrain(
        telemetryStream: combinedStream,
        hrMax: 190.0,
        hrRest: 55.0,
        sleepStartTime: sleepStart,
        sleepEndTime: sleepEnd,
      );

      final daytimeOnlyStrain = NoopAnalyticsEngine.calculateDayStrain(
        telemetryStream: daytimeStream,
        hrMax: 190.0,
        hrRest: 55.0,
        sleepStartTime: sleepStart,
        sleepEndTime: sleepEnd,
      );

      expect(combinedStrain, greaterThan(5.0));
      expect(combinedStrain, equals(daytimeOnlyStrain)); // Identici: la notte è stata totalmente ignorata!
    });

    test('4. Recovery Score (Metodologia Plews / Buchheit) e Null Safety su assenza dati', () {
      // Caso 1: Dati notturni assenti -> Restituisce null (nessun numero inventato, mostra '--')
      final nullRecovery = NoopAnalyticsEngine.calculateRecoveryScore(
        nightlyRmssd: null,
        nightlyRhr: null,
        baselineRmssdMean: 65.0,
        baselineRmssdStd: 15.0,
        baselineRhrMean: 55.0,
        baselineRhrStd: 3.5,
      );
      expect(nullRecovery, isNull);

      // Caso 2: Valori notturni perfettamente in linea con la baseline (Z = 0) -> Recovery ~ 50%
      final baselineRecovery = NoopAnalyticsEngine.calculateRecoveryScore(
        nightlyRmssd: 65.0,
        nightlyRhr: 55.0,
        baselineRmssdMean: 65.0,
        baselineRmssdStd: 15.0,
        baselineRhrMean: 55.0,
        baselineRhrStd: 3.5,
      );
      expect(baselineRecovery, isNotNull);
      expect(baselineRecovery!, closeTo(50.0, 2.0));

      // Caso 3: Ottimo recupero (HRV alto 85ms (+1.33σ), RHR basso 48bpm (+2σ)) -> Recovery > 80% (Verde)
      final highRecovery = NoopAnalyticsEngine.calculateRecoveryScore(
        nightlyRmssd: 85.0,
        nightlyRhr: 48.0,
        baselineRmssdMean: 65.0,
        baselineRmssdStd: 15.0,
        baselineRhrMean: 55.0,
        baselineRhrStd: 3.5,
      );
      expect(highRecovery, isNotNull);
      expect(highRecovery!, greaterThan(80.0));
    });

    test('5. Frequenza Respiratoria via Picco Spettrale RSA', () {
      // Crea una serie temporale sintetica con oscillazione respiratoria a 0.25 Hz (15.0 respiri/minuto)
      final sampleRate = 4.0;
      final numSamples = 128;
      final rrSeries = <double>[];
      for (int i = 0; i < numSamples; i++) {
        final t = i / sampleRate;
        final rr = 800.0 + 50.0 * sin(2.0 * pi * 0.25 * t);
        rrSeries.add(rr);
      }

      final rpm = NoopAnalyticsEngine.calculateRespiratoryRateRpm(rrSeries, samplingRateHz: sampleRate);
      expect(rpm, isNotNull);
      expect(rpm!, closeTo(15.0, 0.5));
    });
  });

  group('NOOP BLE Frame Demuxing & Persistence Tests', () {
    test('6. Demuxing 1 Hz con calcolo ENMO dinamico', () {
      // Test formula ENMO: sqrt(0^2 + 0^2 + 1.2^2) - 1.0 = 0.2g
      final enmo = NoopBleDecoder.calculateEnmo(0.0, 0.0, 1.2);
      expect(enmo, closeTo(0.2, 0.001));

      // Stasi (1.0g gravità terrestre): max(0, 1.0 - 1.0) = 0.0g
      final enmoStasi = NoopBleDecoder.calculateEnmo(0.0, 0.0, 1.0);
      expect(enmoStasi, equals(0.0));
    });

    test('7. Frame corrotto o con BPM fuori range fisiologico scartato', () {
      final decoder = NoopBleDecoder();
      
      // Byte troppo corti (< 20 bytes)
      final shortBytes = Uint8List.fromList([0xAA, 0x01, 0x02]);
      expect(decoder.decodeFrame(shortBytes), isNull);

      // Frame BLE Heart rate con BPM = 250 (fuori range 30-220)
      final invalidHrBytes = Uint8List.fromList([0x00, 250, 0x00, 0x00]);
      expect(decoder.decodeFrame(invalidHrBytes), isNull);
    });

    test('8. Batch SQLite Writing in telemetria_grezza', () async {
      final dbHelper = DatabaseHelper();
      final db = await dbHelper.database;

      final frames = [
        const NoopTelemetryFrame(
          timestampUtcMs: 1723700000000,
          heartRate: 62,
          rrIntervalsMs: [967.7],
          accelEnmo: 0.004,
          skinTempCelsius: 36.2,
          spo2Pct: 98.0,
        ),
        const NoopTelemetryFrame(
          timestampUtcMs: 1723700001000,
          heartRate: 64,
          rrIntervalsMs: [937.5],
          accelEnmo: 0.005,
          skinTempCelsius: 36.2,
          spo2Pct: 98.0,
        ),
      ];

      final inserted = await NoopBleDecoder.insertBatchFrames(db, frames);
      expect(inserted, equals(2));

      final rows = await db.query(DatabaseHelper.tableTelemetriaGrezza);
      expect(rows, isNotEmpty);
      final last = rows.last;
      expect(last['bpm'], equals(64));
      expect(last['accel_enmo'], closeTo(0.005, 0.001));
    });
  });
}
