import 'dart:math' as math;
import 'dart:typed_data';

/// Modello e parser per i pacchetti proprietari WHOOP 4.0 (6108) e WHOOP 5.0 (fd4b)
/// Supporta pacchetti 96-byte flat/framed, frame WHOOP 5.0 Format-1 (R18_BIOMETRIC, REALTIME_DATA 0x28, HISTORICAL_DATA 0x2F)
/// ed estrae fedelmente Frequenza Cardiaca, Intervalli R-R in ticks (1/1024s), ENMO/Accelerometro,
/// Temperatura Cutanea reale (centesimi °C) e SpO2.
class Whoop96BytePacket {
  final List<int> rawBytes;
  final int sequenceNumber;
  final DateTime timestamp;
  final bool isValid;

  Whoop96BytePacket({
    required this.rawBytes,
    required this.sequenceNumber,
    required this.timestamp,
    this.isValid = true,
  });

  int get seqNumber => sequenceNumber;

  /// True se il pacchetto utilizza l'incapsulamento WHOOP con start byte 0xAA
  bool get isWhoopFramed => rawBytes.isNotEmpty && rawBytes[0] == 0xAA;

  /// True se il pacchetto è un frame WHOOP 5.0 Format-1 (header a 8 byte, SOF 0xAA, Version 0x01)
  bool get isWhoop5Framed =>
      rawBytes.length >= 8 && rawBytes[0] == 0xAA && rawBytes[1] == 0x01;

  /// Opcode / Packet Type del frame WHOOP 5.0 (al byte 8)
  int? get whoop5PacketType =>
      isWhoop5Framed && rawBytes.length > 8 ? rawBytes[8] : null;

  /// Layout Version del record WHOOP 5.0 (al byte 9)
  int? get whoop5Layout =>
      isWhoop5Framed && rawBytes.length > 9 ? rawBytes[9] : null;

  /// True se è un record biometrico R18 del WHOOP 5.0 (Layout 18 su tipo 0x2F o 0x2B, len 124 byte)
  bool get isWhoop5R18 =>
      isWhoop5Framed &&
      (whoop5PacketType == 0x2F || whoop5PacketType == 0x2B) &&
      whoop5Layout == 18 &&
      rawBytes.length >= 75;

  /// True se è un pacchetto REALTIME_DATA 0x28 del WHOOP 5.0
  bool get isWhoop5Realtime =>
      isWhoop5Framed && whoop5PacketType == 0x28 && rawBytes.length >= 18;

  /// True se è un pacchetto REALTIME_DATA 0x28 del WHOOP 4.0
  bool get isWhoop4Realtime =>
      isWhoopFramed &&
      !isWhoop5Framed &&
      rawBytes.length >= 14 &&
      rawBytes[4] == 0x28;

  // ─────────────────────────────────────────────────────────────
  // GETTERS DATI BIOMETRICI
  // ─────────────────────────────────────────────────────────────

  /// Heart Rate (bpm)
  int get heartRateBpm {
    // 1. Record biometrico R18 WHOOP 5.0: HR al byte 22
    if (isWhoop5R18 && rawBytes.length > 22) {
      final hr = rawBytes[22];
      if (hr >= 30 && hr <= 250) return hr;
    }

    // 2. Realtime data 0x28 WHOOP 5.0: HR al byte 16
    if (isWhoop5Realtime && rawBytes.length > 16) {
      final hr = rawBytes[16];
      if (hr >= 30 && hr <= 250) return hr;
    }

    // 3. Realtime data 0x28 WHOOP 4.0: HR al byte 12
    if (isWhoop4Realtime && rawBytes.length > 12) {
      final hr = rawBytes[12];
      if (hr >= 30 && hr <= 250) return hr;
    }

    // 4. Frame generico WHOOP (0xAA)
    if (isWhoopFramed) {
      if (rawBytes.length > 8 && rawBytes[8] >= 30 && rawBytes[8] <= 250) {
        return rawBytes[8];
      }
      if (rawBytes.length > 6 && rawBytes[6] >= 30 && rawBytes[6] <= 250) {
        return rawBytes[6];
      }
      if (rawBytes.length > 4 && rawBytes[4] >= 30 && rawBytes[4] <= 250) {
        return rawBytes[4];
      }
      return rawBytes.length > 8 ? rawBytes[8] : 0;
    }

    // 5. Pacchetti flat senza header 0xAA
    return rawBytes.length > 4 ? rawBytes[4] : 0;
  }

  /// Intervalli R-R in millisecondi estratti dal pacchetto
  List<double> get rrIntervalsMs {
    final list = <double>[];

    // WHOOP 5.0 R18: byte 23 = declared count (max 4), byte 24 + 2i = ticks di 1/1024 s
    if (isWhoop5R18 && rawBytes.length >= 24) {
      final declared = math.min(rawBytes[23], 4);
      for (int i = 0; i < declared; i++) {
        final off = 24 + i * 2;
        if (off + 1 < rawBytes.length) {
          final ticks = rawBytes[off] | (rawBytes[off + 1] << 8);
          if (ticks > 0) {
            final ms = ticks * 1000.0 / 1024.0;
            if (ms >= 300.0 && ms <= 2000.0) list.add(ms);
          }
        }
      }
      return list;
    }

    // WHOOP 5.0 Realtime 0x28: byte 17 = count, byte 18 + 2i = ticks di 1/1024 s
    if (isWhoop5Realtime && rawBytes.length >= 18) {
      final count = rawBytes[17];
      for (int i = 0; i < count; i++) {
        final off = 18 + i * 2;
        if (off + 1 < rawBytes.length) {
          final ticks = rawBytes[off] | (rawBytes[off + 1] << 8);
          if (ticks > 0) {
            final ms = ticks * 1000.0 / 1024.0;
            if (ms >= 300.0 && ms <= 2000.0) list.add(ms);
          }
        }
      }
      return list;
    }

    // WHOOP 4.0 Realtime 0x28: byte 13 = count, byte 14 + 2i = millisecondi (u16le)
    if (isWhoop4Realtime && rawBytes.length >= 14) {
      final count = rawBytes[13];
      for (int i = 0; i < count; i++) {
        final off = 14 + i * 2;
        if (off + 1 < rawBytes.length) {
          final ms = rawBytes[off] | (rawBytes[off + 1] << 8);
          if (ms >= 300 && ms <= 2000) list.add(ms.toDouble());
        }
      }
      return list;
    }

    return list;
  }

  /// Motion Variance (ENMO in g)
  double get motionVariance {
    // 1. Record R18 WHOOP 5.0: dynamic_accel_g (f32le) ai byte 41..44
    if (isWhoop5R18 && rawBytes.length >= 45) {
      final bd = ByteData.sublistView(Uint8List.fromList(rawBytes));
      final val = bd.getFloat32(41, Endian.little);
      if (val.isFinite && val >= 0.0 && val <= 8.0) return val;
    }

    // 2. Frame con accelerometro triassiale (byte 11..16)
    if (isWhoopFramed && !isWhoop5Framed) {
      final ax = accelX;
      final ay = accelY;
      final az = accelZ;
      final mag = math.sqrt(ax * ax + ay * ay + az * az);
      final enmo = mag - 1.0;
      return enmo > 0.0 ? enmo : 0.0;
    }

    // 3. Pacchetti flat a 96-byte: bytes 8-11 (float32 LE)
    if (rawBytes.length >= 12 && !isWhoop5Framed) {
      final bd = ByteData.sublistView(Uint8List.fromList(rawBytes.sublist(8, 12)));
      final val = bd.getFloat32(0, Endian.little);
      return (val.isFinite && val >= 0.0) ? val : 0.0;
    }

    return 0.0;
  }

  double get enmo => motionVariance;

  /// Respiratory Power RSA
  double get respiratoryPower {
    if (isWhoopFramed) return 0.0;
    if (rawBytes.length < 20) return 0.0;
    final bd = ByteData.sublistView(Uint8List.fromList(rawBytes.sublist(16, 20)));
    final val = bd.getFloat32(0, Endian.little);
    return (val.isFinite && val >= 0.0) ? val : 0.0;
  }

  /// Respiratory Rate
  double get respiratoryRate {
    if (isWhoopFramed && rawBytes.length >= 28 && !isWhoop5Framed) {
      final bd = ByteData.sublistView(Uint8List.fromList(rawBytes.sublist(24, 28)));
      final val = bd.getFloat32(0, Endian.little);
      if (val.isFinite && val >= 7.0 && val <= 30.0) return val;
    }
    if (rawBytes.length >= 24 && !isWhoop5Framed) {
      final bd = ByteData.sublistView(Uint8List.fromList(rawBytes.sublist(20, 24)));
      final val = bd.getFloat32(0, Endian.little);
      if (val.isFinite && val >= 7.0 && val <= 30.0) return val;
    }
    return 0.0;
  }

  /// Skin Temperature raw
  int get skinTempRaw {
    // WHOOP 5.0 R18: byte 73..74 u16le
    if (isWhoop5R18 && rawBytes.length >= 75) {
      return rawBytes[73] | (rawBytes[74] << 8);
    }

    final List<int> offsets = [];
    if (isWhoopFramed) {
      if (rawBytes.length >= 34) offsets.add(32);
      if (rawBytes.length >= 20) offsets.add(18);
      if (rawBytes.length >= 30) offsets.add(28);
    } else {
      if (rawBytes.length >= 30) offsets.add(28);
      if (rawBytes.length >= 20) offsets.add(18);
    }
    for (final off in offsets) {
      final val16 = rawBytes[off] | (rawBytes[off + 1] << 8);
      if ((val16 >= 3840 && val16 <= 5312) ||
          (val16 >= 3000 && val16 <= 3839) ||
          (val16 >= 300 && val16 <= 415)) {
        return val16;
      }
    }
    if (rawBytes.length >= 18 && rawBytes[17] != 0) {
      return rawBytes[17];
    }
    return 0;
  }

  /// Skin Temperature (°C)
  double? get skinTempCelsius {
    // 1. WHOOP 5.0 R18 layout: offset 73..74 uint16 LE in centesimi di grado (°C = raw / 100.0)
    if (isWhoop5R18 && rawBytes.length >= 75) {
      final raw16 = rawBytes[73] | (rawBytes[74] << 8);
      final c = raw16 / 100.0;
      if (c >= 5.0 && c <= 45.0) {
        return double.parse(c.toStringAsFixed(2));
      }
    }

    // 2. Decodifica multi-scala legacy per frame compatti e AS6221
    final List<int> offsets = [];
    if (isWhoopFramed && !isWhoop5Framed) {
      if (rawBytes.length >= 34) offsets.add(32);
      if (rawBytes.length >= 20) offsets.add(18);
      if (rawBytes.length >= 30) offsets.add(28);
    } else if (!isWhoop5Framed) {
      if (rawBytes.length >= 30) offsets.add(28);
      if (rawBytes.length >= 20) offsets.add(18);
    }

    for (final off in offsets) {
      if (off + 1 >= rawBytes.length) continue;
      final val16 = rawBytes[off] | (rawBytes[off + 1] << 8);
      double? tempC;
      if (val16 >= 3840 && val16 <= 5312) {
        tempC = val16 * 0.0078125;
      } else if (val16 >= 3000 && val16 <= 3839) {
        tempC = val16 / 100.0;
      } else if (val16 >= 300 && val16 <= 415) {
        tempC = val16 / 10.0;
      }

      if (tempC != null && tempC >= 25.0 && tempC <= 42.0) {
        return double.parse(tempC.toStringAsFixed(2));
      }
    }

    if (rawBytes.length >= 18 && !isWhoop5Framed) {
      final bd = ByteData.sublistView(Uint8List.fromList(rawBytes));
      final int8Val = bd.getInt8(17);
      if (int8Val != 0 && int8Val >= -55 && int8Val <= 50) {
        final tempC = 36.0 + (int8Val / 10.0);
        if (tempC >= 25.0 && tempC <= 42.0) {
          return double.parse(tempC.toStringAsFixed(2));
        }
      }
    }
    return null;
  }

  /// SpO2 (%)
  double? get spo2Pct {
    if (rawBytes.length >= 110) {
      final pct = _evalFloat32Spo2(106);
      if (pct != null) return pct;
    }
    if (isWhoopFramed && rawBytes.length >= 40 && !isWhoop5Framed) {
      final pct = _evalFloat32Spo2(36);
      if (pct != null) return pct;
    }
    if (rawBytes.length >= 36 && !isWhoop5Framed) {
      final pct = _evalFloat32Spo2(32);
      if (pct != null) return pct;
    }
    if (rawBytes.length >= 22 && !isWhoop5Framed) {
      final val16 = rawBytes[20] | (rawBytes[21] << 8);
      if (val16 >= 850 && val16 <= 1000) {
        return double.parse((val16 / 10.0).toStringAsFixed(1));
      }
    }
    return null;
  }

  double? _evalFloat32Spo2(int offset) {
    if (rawBytes.length < offset + 4) return null;
    final bd = ByteData.sublistView(Uint8List.fromList(rawBytes));
    final val = bd.getFloat32(offset, Endian.little);
    if (!val.isFinite) return null;
    if (val >= 0.40 && val <= 1.20) {
      final pct = (110.0 - 25.0 * val).clamp(80.0, 100.0);
      return double.parse(pct.toStringAsFixed(1));
    }
    if (val >= 85.0 && val <= 100.0) {
      return double.parse(val.toStringAsFixed(1));
    }
    return null;
  }

  /// SpO2 R-ratio
  double get spo2Ratio {
    if (rawBytes.length >= 110) {
      final r = _evalFloat32Ratio(106);
      if (r != null) return r;
    }
    if (isWhoopFramed && rawBytes.length >= 40 && !isWhoop5Framed) {
      final r = _evalFloat32Ratio(36);
      if (r != null) return r;
    }
    if (rawBytes.length >= 36 && !isWhoop5Framed) {
      final r = _evalFloat32Ratio(32);
      if (r != null) return r;
    }
    final pct = spo2Pct;
    if (pct != null && pct >= 80.0 && pct <= 100.0) {
      return double.parse(((110.0 - pct) / 25.0).toStringAsFixed(3));
    }
    return 0.0;
  }

  double? _evalFloat32Ratio(int offset) {
    if (rawBytes.length < offset + 4) return null;
    final bd = ByteData.sublistView(Uint8List.fromList(rawBytes));
    final val = bd.getFloat32(offset, Endian.little);
    if (val.isFinite && val >= 0.40 && val <= 1.20) {
      return double.parse(val.toStringAsFixed(3));
    }
    return null;
  }

  /// HRV rMSSD (ms)
  double get hrvRmssdMs {
    // 1. Se abbiamo intervalli R-R nel pacchetto, calcola RMSSD direttamente
    final rrs = rrIntervalsMs;
    if (rrs.length >= 2) {
      double sumDiffSq = 0.0;
      int count = 0;
      for (int i = 0; i < rrs.length - 1; i++) {
        final diff = (rrs[i + 1] - rrs[i]).abs();
        if (diff <= 200.0) {
          sumDiffSq += diff * diff;
          count++;
        }
      }
      if (count > 0) {
        return double.parse(math.sqrt(sumDiffSq / count).toStringAsFixed(1));
      }
    }

    // 2. In frame WHOOP 4.0: bytes 9-10 (uint16 LE / 10.0)
    if (isWhoopFramed && !isWhoop5Framed) {
      if (rawBytes.length < 11) return 0.0;
      final bd = ByteData.sublistView(Uint8List.fromList(rawBytes));
      return bd.getUint16(9, Endian.little) / 10.0;
    }

    // 3. In pacchetti flat 96-byte: bytes 40-43 (float32 LE)
    if (rawBytes.length >= 44 && !isWhoop5Framed) {
      final bd = ByteData.sublistView(Uint8List.fromList(rawBytes.sublist(40, 44)));
      final val = bd.getFloat32(0, Endian.little);
      return (val.isFinite && val >= 0.0) ? val : 0.0;
    }

    return 0.0;
  }

  /// Alias per compatibilità
  int get bpm => heartRateBpm;
  double get hrvMs => hrvRmssdMs;

  /// Accelerazione triassiale (g)
  double get accelX {
    if (isWhoop5R18 && rawBytes.length >= 49) {
      final bd = ByteData.sublistView(Uint8List.fromList(rawBytes));
      final val = bd.getFloat32(45, Endian.little);
      return val.isFinite ? val : 0.0;
    }
    if (!isWhoopFramed || rawBytes.length < 13) return 0.0;
    final bd = ByteData.sublistView(Uint8List.fromList(rawBytes));
    return bd.getInt16(11, Endian.little) / 1000.0;
  }

  double get accelY {
    if (isWhoop5R18 && rawBytes.length >= 53) {
      final bd = ByteData.sublistView(Uint8List.fromList(rawBytes));
      final val = bd.getFloat32(49, Endian.little);
      return val.isFinite ? val : 0.0;
    }
    if (!isWhoopFramed || rawBytes.length < 15) return 0.0;
    final bd = ByteData.sublistView(Uint8List.fromList(rawBytes));
    return bd.getInt16(13, Endian.little) / 1000.0;
  }

  double get accelZ {
    if (isWhoop5R18 && rawBytes.length >= 57) {
      final bd = ByteData.sublistView(Uint8List.fromList(rawBytes));
      final val = bd.getFloat32(53, Endian.little);
      return val.isFinite ? val : 0.0;
    }
    if (!isWhoopFramed || rawBytes.length < 17) return 0.0;
    final bd = ByteData.sublistView(Uint8List.fromList(rawBytes));
    return bd.getInt16(15, Endian.little) / 1000.0;
  }

  factory Whoop96BytePacket.fromBytes(List<int> bytes) {
    if (bytes.length < 8) {
      return Whoop96BytePacket(
        rawBytes: bytes,
        sequenceNumber: 0,
        timestamp: DateTime.now(),
        isValid: false,
      );
    }

    final byteData = ByteData.sublistView(Uint8List.fromList(bytes));

    int seqNum = 0;
    DateTime packetTs = DateTime.now();

    // 1. Frame WHOOP 5.0 (0xAA 0x01 ...)
    if (bytes.length >= 8 && bytes[0] == 0xAA && bytes[1] == 0x01) {
      final ptype = bytes.length > 8 ? bytes[8] : 0;
      final layout = bytes.length > 9 ? bytes[9] : 0;

      if ((ptype == 0x2F || ptype == 0x2B) && layout == 18 && bytes.length >= 19) {
        // Record R18: record_index a 11..14, unix_seconds a 15..18
        if (bytes.length >= 15) {
          seqNum = byteData.getUint32(11, Endian.little) & 0xFFFF;
        }
        if (bytes.length >= 19) {
          final tsSec = byteData.getUint32(15, Endian.little);
          if (tsSec > 1577836800 && tsSec < 2524608000) {
            packetTs = DateTime.fromMillisecondsSinceEpoch(tsSec * 1000, isUtc: true).toLocal();
          }
        }
      } else if (ptype == 0x28 && bytes.length >= 14) {
        // Realtime 0x28: unix_seconds a 10..13
        final tsSec = byteData.getUint32(10, Endian.little);
        if (tsSec > 1577836800 && tsSec < 2524608000) {
          packetTs = DateTime.fromMillisecondsSinceEpoch(tsSec * 1000, isUtc: true).toLocal();
        }
      }
    }
    // 2. Frame WHOOP 4.0 con header 0xAA
    else if (bytes[0] == 0xAA) {
      if (bytes.length >= 96) {
        seqNum = byteData.getUint16(2, Endian.little);
      } else if (bytes.length >= 6) {
        seqNum = bytes[5];
      } else {
        seqNum = byteData.getUint16(2, Endian.little);
      }

      if (bytes.length >= 8) {
        final tsVal = byteData.getUint32(4, Endian.little);
        if (tsVal > 1577836800 && tsVal < 2524608000) {
          packetTs = DateTime.fromMillisecondsSinceEpoch(tsVal * 1000, isUtc: true).toLocal();
        }
      }
    }
    // 3. Flat packets senza header 0xAA
    else if (bytes.length >= 2) {
      seqNum = byteData.getUint16(0, Endian.little);
    }

    return Whoop96BytePacket(
      rawBytes: bytes,
      sequenceNumber: seqNum,
      timestamp: packetTs,
      isValid: true,
    );
  }

  @override
  String toString() {
    return 'Whoop96BytePacket(seq: $sequenceNumber, length: ${rawBytes.length}, bpm: $bpm, isValid: $isValid)';
  }
}
