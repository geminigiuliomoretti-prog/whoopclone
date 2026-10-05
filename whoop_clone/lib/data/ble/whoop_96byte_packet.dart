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
  
  /// Respiratory Rate: bytes 20-23 (float32 LE) - Frequenza respiratoria estratta (atti/min)
  double get respiratoryRate {
    if (rawBytes.length < 24) return 0.0;
    final bd = ByteData.sublistView(Uint8List.fromList(rawBytes.sublist(20, 24)));
    final val = bd.getFloat32(0, Endian.little);
    return (val.isFinite && val >= 0.0) ? val : 0.0;
  }
  
  /// Skin Temperature raw:
  /// - In frame 0xAA: byte 17 (int8 normalizzato a offset raw)
  /// - In pacchetti flat: bytes 28-29 (uint16 LE) - Valore grezzo sensore AS6221
  int get skinTempRaw {
    if (rawBytes.length >= 30) {
      final val16 = rawBytes[28] | (rawBytes[29] << 8);
      if (val16 > 1000 && val16 < 8000) return val16;
    }
    if (isWhoopFramed) {
      if (rawBytes.length < 18) return 0;
      return rawBytes[17];
    }
    if (rawBytes.length < 30) return 0;
    return rawBytes[28] | (rawBytes[29] << 8);
  }
  
  /// SpO2 R-ratio: bytes 32-35 (float32 LE) - Rapporto R per calcolo saturazione
  double get spo2Ratio {
    if (rawBytes.length < 36) return 0.0;
    final bd = ByteData.sublistView(Uint8List.fromList(rawBytes.sublist(32, 36)));
    final val = bd.getFloat32(0, Endian.little);
    return (val.isFinite && val >= 0.0) ? val : 0.0;
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
    if (bytes.length < 96) {
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
    // la sequenza si trova al byte 2 (uint16 LE).
    // Se flat/senza header 0xAA, la sequenza si trova nei primi 2 byte (0..1).
    final int seqNum;
    if (bytes[0] == 0xAA) {
      seqNum = byteData.getUint16(2, Endian.little);
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
