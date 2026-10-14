import 'dart:math' as math;
import 'dart:typed_data';

/// Modello e parser per il pacchetto proprietario Whoop da 96 Byte
/// ricevuto dalla caratteristica `61080005-8d6d-82b8-614a-1c8cb0f8dcc6`.
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

  /// True se il pacchetto utilizza l'incapsulamento Whoop con header di sincronizzazione 0xAA
  bool get isWhoopFramed => rawBytes.isNotEmpty && rawBytes[0] == 0xAA;

  // Getters per i dati biometrici estratti dal pacchetto 96 byte (layout proprietario Whoop 4.0 / 5.0)
  // I byte offsets sono basati sull'analisi del protocollo Whoop
  
  /// Heart Rate (bpm):
  /// - In frame Whoop con header (0xAA), i byte 4-7 contengono il timestamp UTC a 32-bit,
  ///   quindi l'heart rate si trova al byte 8.
  /// - In pacchetti flat/senza header 0xAA, l'heart rate si trova al byte 4 (uint8).
  int get heartRateBpm {
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
    return rawBytes.length > 4 ? rawBytes[4] : 0;
  }
  
  /// Motion Variance (ENMO):
  /// - In frame Whoop con header (0xAA), i byte 8-11 ospitano HR, HRV e accelX.
  ///   Per evitare corruzione, calcoliamo la varianza di movimento / ENMO direttamente dall'accelerometro triassiale (byte 11-16).
  /// - In pacchetti flat, bytes 8-11 (float32 LE) rappresentano la varianza dell'accelerazione.
  double get motionVariance {
    if (isWhoopFramed) {
      final ax = accelX;
      final ay = accelY;
      final az = accelZ;
      final mag = math.sqrt(ax * ax + ay * ay + az * az);
      final enmo = mag - 1.0;
      return enmo > 0.0 ? enmo : 0.0;
    }
    if (rawBytes.length < 12) return 0.0;
    final bd = ByteData.sublistView(Uint8List.fromList(rawBytes.sublist(8, 12)));
    final val = bd.getFloat32(0, Endian.little);
    return (val.isFinite && val >= 0.0) ? val : 0.0;
  }

  double get enmo => motionVariance;
  
  /// Respiratory Power RSA:
  /// - In frame Whoop con header (0xAA), byte 15-16 è accelZ e byte 17 è tempC;
  ///   non si interpreta come float32 a byte 16-19 per evitare corruzione con l'accelerometro.
  /// - In pacchetti flat, bytes 16-19 (float32 LE) - Ampiezza picco spettrale RSA [0.12 - 0.40 Hz].
  double get respiratoryPower {
    if (isWhoopFramed) return 0.0;
    if (rawBytes.length < 20) return 0.0;
    final bd = ByteData.sublistView(Uint8List.fromList(rawBytes.sublist(16, 20)));
    final val = bd.getFloat32(0, Endian.little);
    return (val.isFinite && val >= 0.0) ? val : 0.0;
  }
  
  /// Respiratory Rate:
  /// - Se isWhoopFramed e rawBytes.length >= 28 legge float32 da sublist(24, 28); con fallback su sublist(20, 24)
  double get respiratoryRate {
    if (isWhoopFramed && rawBytes.length >= 28) {
      final bd = ByteData.sublistView(Uint8List.fromList(rawBytes.sublist(24, 28)));
      final val = bd.getFloat32(0, Endian.little);
      if (val.isFinite && val >= 7.0 && val <= 30.0) return val;
    }
    if (rawBytes.length >= 24) {
      final bd = ByteData.sublistView(Uint8List.fromList(rawBytes.sublist(20, 24)));
      final val = bd.getFloat32(0, Endian.little);
      if (val.isFinite && val >= 7.0 && val <= 30.0) return val;
    }
    return 0.0;
  }
  
  /// Skin Temperature raw:
  /// - Multi-scala: legge uint16 LE (AS6221, centesimi o decimi) o fallback byte 17
  int get skinTempRaw {
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

  /// Skin Temperature (°C):
  /// - Decodifica multi-scala:
  ///   - Byte 32..33 (se framed 0xAA) o Byte 28..29 (se flat), o Byte 18..19 nei frame compatti:
  ///     * val16 in [3840, 5312] (AS6221): tempC = val16 * 0.0078125
  ///     * val16 in [3000, 3839] (centesimi): tempC = val16 / 100.0
  ///     * val16 in [300, 415] (decimi): tempC = val16 / 10.0
  ///   - Fallback Byte 17 (int8 != 0, tra -55 e +50): tempC = 36.0 + (int8Val / 10.0)
  ///   - Valida tempC in [28.0, 42.0] °C
  double? get skinTempCelsius {
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
      double? tempC;
      if (val16 >= 3840 && val16 <= 5312) {
        tempC = val16 * 0.0078125;
      } else if (val16 >= 3000 && val16 <= 3839) {
        tempC = val16 / 100.0;
      } else if (val16 >= 300 && val16 <= 415) {
        tempC = val16 / 10.0;
      }

      if (tempC != null && tempC >= 28.0 && tempC <= 42.0) {
        return double.parse(tempC.toStringAsFixed(2));
      }
    }

    if (rawBytes.length >= 18) {
      final bd = ByteData.sublistView(Uint8List.fromList(rawBytes));
      final int8Val = bd.getInt8(17);
      if (int8Val != 0 && int8Val >= -55 && int8Val <= 50) {
        final tempC = 36.0 + (int8Val / 10.0);
        if (tempC >= 28.0 && tempC <= 42.0) {
          return double.parse(tempC.toStringAsFixed(2));
        }
      }
    }
    return null;
  }
  
  /// SpO2 (%):
  /// - Cerca a Byte 36..39 (se framed 0xAA), Byte 32..35 (se flat), Byte 20..21 (se compatto)
  ///   e nella coda ottica Byte 106..109 (se record storico v18 Type 0x2F, lunghezza >= 110):
  ///   * float32 LE in [0.40, 1.20] (R-ratio Red/IR): spo2Pct = (110.0 - 25.0 * rRatio).clamp(80.0, 100.0)
  ///   * float32 LE in [85.0, 100.0]: valore diretto
  ///   * uint16 LE in [850, 1000]: val16 / 10.0
  double? get spo2Pct {
    if (rawBytes.length >= 110) {
      final pct = _evalFloat32Spo2(106);
      if (pct != null) return pct;
    }
    if (isWhoopFramed && rawBytes.length >= 40) {
      final pct = _evalFloat32Spo2(36);
      if (pct != null) return pct;
    }
    if (rawBytes.length >= 36) {
      final pct = _evalFloat32Spo2(32);
      if (pct != null) return pct;
    }
    if (rawBytes.length >= 22) {
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

  /// SpO2 R-ratio:
  double get spo2Ratio {
    if (rawBytes.length >= 110) {
      final r = _evalFloat32Ratio(106);
      if (r != null) return r;
    }
    if (isWhoopFramed && rawBytes.length >= 40) {
      final r = _evalFloat32Ratio(36);
      if (r != null) return r;
    }
    if (rawBytes.length >= 36) {
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
  
  /// HRV rMSSD (ms):
  /// - In frame 0xAA: bytes 9-10 (uint16 LE diviso 10.0)
  /// - In pacchetti flat: bytes 40-43 (float32 LE)
  double get hrvRmssdMs {
    if (isWhoopFramed) {
      if (rawBytes.length < 11) return 0.0;
      final bd = ByteData.sublistView(Uint8List.fromList(rawBytes));
      return bd.getUint16(9, Endian.little) / 10.0;
    }
    if (rawBytes.length < 44) return 0.0;
    final bd = ByteData.sublistView(Uint8List.fromList(rawBytes.sublist(40, 44)));
    final val = bd.getFloat32(0, Endian.little);
    return (val.isFinite && val >= 0.0) ? val : 0.0;
  }

  /// Alias per compatibilità con stream telemetrici
  int get bpm => heartRateBpm;
  double get hrvMs => hrvRmssdMs;

  /// Accelerazione triassiale (g): bytes 11-16 (int16 LE in milli-g)
  /// Attivo in frame Whoop (0xAA) dove non confligge con motionVariance (8-11) o respiratoryPower (16-19)
  double get accelX {
    if (!isWhoopFramed || rawBytes.length < 13) return 0.0;
    final bd = ByteData.sublistView(Uint8List.fromList(rawBytes));
    return bd.getInt16(11, Endian.little) / 1000.0;
  }

  double get accelY {
    if (!isWhoopFramed || rawBytes.length < 15) return 0.0;
    final bd = ByteData.sublistView(Uint8List.fromList(rawBytes));
    return bd.getInt16(13, Endian.little) / 1000.0;
  }

  double get accelZ {
    if (!isWhoopFramed || rawBytes.length < 17) return 0.0;
    final bd = ByteData.sublistView(Uint8List.fromList(rawBytes));
    return bd.getInt16(15, Endian.little) / 1000.0;
  }

  factory Whoop96BytePacket.fromBytes(List<int> bytes) {
    if (bytes.length < 20) {
      return Whoop96BytePacket(
        rawBytes: bytes,
        sequenceNumber: 0,
        timestamp: DateTime.now(),
        isValid: false,
      );
    }

    final byteData = ByteData.sublistView(Uint8List.fromList(bytes));

    // Estrazione sequenceNumber corretta in base all'header del protocollo:
    // Se inizia con 0xAA, byte 0 è Sync e byte 1 è la lunghezza;
    // la sequenza si trova al byte 2 (uint16 LE) per 96-byte e record flash, o byte 5 per comandi incapsulati.
    // Se flat/senza header 0xAA, la sequenza si trova nei primi 2 byte (0..1).
    final int seqNum;
    if (bytes[0] == 0xAA) {
      if (bytes.length >= 96) {
        seqNum = byteData.getUint16(2, Endian.little);
      } else if (bytes.length >= 6) {
        seqNum = bytes[5];
      } else {
        seqNum = byteData.getUint16(2, Endian.little);
      }
    } else {
      seqNum = byteData.getUint16(0, Endian.little);
    }

    // Estrazione timestamp sicura:
    // Solo per i frame con header 0xAA i byte 4-7 sono riservati a timestamp UTC uint32.
    // Nei pacchetti senza header 0xAA, il byte 4 contiene heartRateBpm e non deve
    // essere interpretato come timestamp per evitare conflitti e corruzioni.
    DateTime packetTs = DateTime.now();
    if (bytes[0] == 0xAA && bytes.length >= 8) {
      final tsVal = byteData.getUint32(4, Endian.little);
      if (tsVal > 1577836800 && tsVal < 2524608000) {
        packetTs = DateTime.fromMillisecondsSinceEpoch(tsVal * 1000, isUtc: true).toLocal();
      }
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
    return 'Whoop96BytePacket(seq: $sequenceNumber, length: ${rawBytes.length}, isValid: $isValid)';
  }
}
