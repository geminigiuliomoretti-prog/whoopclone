import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import '../database/database_helper.dart';

/// Frame tipizzato a 1 Hz per telemetria WHOOP (Architettura NOOP)
@immutable
class NoopTelemetryFrame {
  final int timestampUtcMs;
  final int heartRate; // Range fisiologico: 30-220 bpm
  final List<double> rrIntervalsMs; // Validi nel range 300-1500 ms
  final double accelEnmo; // Dynamic acceleration max(0, sqrt(x^2+y^2+z^2) - 1.0)
  final double? skinTempCelsius; // Temperatura cutanea normalizzata
  final double? spo2Pct; // Saturazione ossigeno nel range 85-100%
  final double? motionVariance;
  final bool isCalibrating;

  const NoopTelemetryFrame({
    required this.timestampUtcMs,
    required this.heartRate,
    required this.rrIntervalsMs,
    required this.accelEnmo,
    this.skinTempCelsius,
    this.spo2Pct,
    this.motionVariance,
    this.isCalibrating = false,
  });

  /// Intervallo RR medio rappresentativo del secondo (se presente)
  double? get meanRrMs {
    if (rrIntervalsMs.isEmpty) return null;
    return rrIntervalsMs.reduce((a, b) => a + b) / rrIntervalsMs.length;
  }

  Map<String, dynamic> toDbMap() {
    return {
      'timestamp': DateTime.fromMillisecondsSinceEpoch(timestampUtcMs, isUtc: true).toIso8601String(),
      'timestamp_utc_ms': timestampUtcMs,
      'bpm': heartRate,
      'rr_ms': meanRrMs,
      'rr_intervals_json': jsonEncode(rrIntervalsMs),
      'accel_enmo': accelEnmo,
      'motion_var': motionVariance ?? accelEnmo,
      'skin_temp_celsius': skinTempCelsius,
      'spo2_pct': spo2Pct,
    };
  }

  @override
  String toString() {
    return 'NoopTelemetryFrame(ts: $timestampUtcMs, hr: $heartRate bpm, rrCount: ${rrIntervalsMs.length}, enmo: ${accelEnmo.toStringAsFixed(4)}g, temp: $skinTempCelsius°C, spo2: $spo2Pct%)';
  }
}

/// Decoder del Protocollo BLE e Demuxer dei canali di segnale NOOP
class NoopBleDecoder {
  int? _lastSequenceNumber;
  int? _lastTimestampMs;

  int? get lastSequenceNumber => _lastSequenceNumber;
  int? get lastTimestampMs => _lastTimestampMs;

  /// Resetta lo stato di sincronizzazione del flusso
  void resetStream() {
    _lastSequenceNumber = null;
    _lastTimestampMs = null;
  }

  /// Calcola l'accelerazione netta dinamica ENMO:
  /// ENMO = max(0.0, sqrt(X^2 + Y^2 + Z^2) - 1.0g)
  static double calculateEnmo(double xG, double yG, double zG) {
    final magnitude = sqrt(xG * xG + yG * yG + zG * zG);
    final enmo = magnitude - 1.0;
    return max(0.0, enmo);
  }

  /// Filtra una lista di intervalli RR rimuovendo artefatti non fisiologici (< 300 ms o > 1500 ms)
  static List<double> filterRrIntervals(List<double> rawIntervals) {
    final valid = <double>[];
    for (final rr in rawIntervals) {
      if (rr >= 300.0 && rr <= 1500.0) {
        valid.add(rr);
      }
    }
    return valid;
  }

  /// Converte il rapporto ottico PPG (R-ratio) in percentuale di SpO2 calibrata
  /// Formula standard pulsossimetria: SpO2 = 110 - 25 * R_ratio (clamped 85-100%)
  static double? calculateSpo2FromRatio(double rRatio) {
    if (rRatio <= 0.0 || rRatio > 1.2) return null;
    final spo2 = 110.0 - (25.0 * rRatio);
    if (spo2 < 85.0 || spo2 > 100.0) return null;
    return double.parse(spo2.toStringAsFixed(1));
  }

  /// Decodifica un frame binario da 96 byte o inviluppo BLE a 1 Hz
  NoopTelemetryFrame? decodeFrame(Uint8List rawBytes, {int? explicitTimestampMs}) {
    if (rawBytes.length < 20) {
      // Pacchetto incompleto o corrotto
      return null;
    }

    final byteData = ByteData.sublistView(rawBytes);

    // Frame WHOOP 96 byte proprietario
    if (rawBytes.length >= 96) {
      final syncByte = rawBytes[0];
      // Verifica del sync byte (0xAA o 0x55)
      if (syncByte != 0xAA && syncByte != 0x55) {
        return null;
      }

      final seqNum = byteData.getUint16(0, Endian.little);
      final rawTimestampMs = explicitTimestampMs ?? DateTime.now().toUtc().millisecondsSinceEpoch;

      // Controllo perdita sincronizzazione o frame duplicato
      if (_lastSequenceNumber != null) {
        // Scarta frame duplicati esatti
        if (seqNum == _lastSequenceNumber) {
          return null; // Duplicato
        }
      }
      _lastSequenceNumber = seqNum;
      _lastTimestampMs = rawTimestampMs;

      // 1. Frequenza Cardiaca (Byte 4, uint8)
      final rawHr = rawBytes[4];
      if (rawHr < 30 || rawHr > 220) {
        // Fuori dal range fisiologico
        return null;
      }

      // 2. Accelerometria 3-assi (Float32 o Int16 normalizzati in g)
      final double motionVar = byteData.getFloat32(8, Endian.little);
      
      // Calcolo ENMO se presenti assi x,y,z (Bytes 12-23)
      double accelEnmo = motionVar;
      if (rawBytes.length >= 24) {
        try {
          final x = byteData.getFloat32(12, Endian.little);
          final y = byteData.getFloat32(16, Endian.little);
          final z = byteData.getFloat32(20, Endian.little);
          if (x.isFinite && y.isFinite && z.isFinite && (x.abs() <= 16.0 && y.abs() <= 16.0 && z.abs() <= 16.0)) {
            accelEnmo = calculateEnmo(x, y, z);
          }
        } catch (e) {
          debugPrint('[NoopBleDecoder] Error decoding accelerometer data: $e');
        }
      }

      // 3. Intervalli R-R (Bytes 40-43 rMSSD o estrazione serie)
      final rawRmssd = byteData.getFloat32(40, Endian.little);
      final List<double> rrList = [];
      if (rawRmssd > 0 && rawRmssd.isFinite) {
        final instantaneousRr = 60000.0 / rawHr;
        if (instantaneousRr >= 300.0 && instantaneousRr <= 1500.0) {
          rrList.add(instantaneousRr);
        }
      }

      // 4. Temperatura cutanea (Bytes 28-29 uint16 raw -> °C)
      double? skinTemp;
      if (rawBytes.length >= 30) {
        final rawTemp = byteData.getUint16(28, Endian.little);
        if (rawTemp > 1000 && rawTemp < 6000) {
          final tempC = (rawTemp * 0.0078125);
          if (tempC >= 25.0 && tempC <= 42.0) {
            skinTemp = double.parse(tempC.toStringAsFixed(2));
          }
        }
      }

      // 5. SpO2 da PPG R-ratio (Bytes 32-35 float32 LE)
      double? spo2;
      if (rawBytes.length >= 36) {
        final rRatio = byteData.getFloat32(32, Endian.little);
        spo2 = calculateSpo2FromRatio(rRatio);
      }

      return NoopTelemetryFrame(
        timestampUtcMs: rawTimestampMs,
        heartRate: rawHr,
        rrIntervalsMs: filterRrIntervals(rrList),
        accelEnmo: accelEnmo,
        motionVariance: motionVar,
        skinTempCelsius: skinTemp,
        spo2Pct: spo2,
      );
    }

    // Standard BLE Heart Rate Service (0x180D) / Inviluppo 20 Byte
    final flags = rawBytes[0];
    final is16BitHr = (flags & 0x01) != 0;
    final hasRrIntervals = (flags & 0x10) != 0;

    int offset = 1;
    int hr = 0;
    if (is16BitHr && rawBytes.length >= 3) {
      hr = byteData.getUint16(offset, Endian.little);
      offset += 2;
    } else if (rawBytes.length >= 2) {
      hr = byteData.getUint8(offset);
      offset += 1;
    }

    if (hr < 30 || hr > 220) return null;

    final rrList = <double>[];
    if (hasRrIntervals) {
      while (offset + 1 < rawBytes.length) {
        final rawRr = byteData.getUint16(offset, Endian.little);
        final rrMs = (rawRr / 1024.0) * 1000.0;
        if (rrMs >= 300.0 && rrMs <= 1500.0) {
          rrList.add(rrMs);
        }
        offset += 2;
      }
    }

    final ts = explicitTimestampMs ?? DateTime.now().toUtc().millisecondsSinceEpoch;

    return NoopTelemetryFrame(
      timestampUtcMs: ts,
      heartRate: hr,
      rrIntervalsMs: rrList,
      accelEnmo: 0.0,
      motionVariance: 0.001,
      skinTempCelsius: null,
      spo2Pct: null,
    );
  }

  /// Inserisce un batch di frame validati su SQLite nella tabella `telemetria_grezza`
  static Future<int> insertBatchFrames(Database db, List<NoopTelemetryFrame> frames) async {
    if (frames.isEmpty) return 0;

    int insertedCount = 0;
    final batch = db.batch();

    for (final frame in frames) {
      batch.insert(
        DatabaseHelper.tableTelemetriaGrezza,
        frame.toDbMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      insertedCount++;
    }

    await batch.commit(noResult: true);
    return insertedCount;
  }
}
