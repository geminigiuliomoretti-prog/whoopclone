import 'dart:typed_data';
import 'package:flutter/foundation.dart';

/// Algoritmo CRC-32 WHOOP (Standard IEEE 802.3 / zlib con fallback legacy)
/// Il firmware reale della band (WHOOP 4.0 / 5.0) verifica il CRC-32 standard IEEE 802.3
/// con polinomio riflesso 0xEDB88320, init 0xFFFFFFFF, xorOut 0xFFFFFFFF.
class WhoopCrc32 {
  static const int poly = 0x04C11DB7;
  static const int xorOut = 0xF43F44AC;

  // Tabella precalcolata IEEE 802.3 CRC-32 (standard zlib / hardware nRF / WHOOP firmware)
  static final List<int> _ieeeTable = () {
    final table = List<int>.filled(256, 0);
    for (int i = 0; i < 256; i++) {
      int c = i;
      for (int k = 0; k < 8; k++) {
        if ((c & 1) != 0) {
          c = (c >>> 1) ^ 0xEDB88320;
        } else {
          c = c >>> 1;
        }
      }
      table[i] = c & 0xFFFFFFFF;
    }
    return table;
  }();

  /// Calcola il checksum standard IEEE 802.3 CRC-32 atteso dal firmware reale WHOOP
  static int compute(List<int> bytes) {
    int crc = 0xFFFFFFFF;
    for (int b in bytes) {
      crc = (crc >>> 8) ^ _ieeeTable[(crc ^ (b & 0xFF)) & 0xFF];
    }
    return (crc ^ 0xFFFFFFFF) & 0xFFFFFFFF;
  }

  /// Calcolo legacy con XOR out proprietario 0xF43F44AC (mantenuto per retrocompatibilità test)
  static int computeLegacy(List<int> bytes) {
    int crc = 0x00000000;
    for (int b in bytes) {
      int reflectedByte = _reverseBits8(b & 0xFF);
      crc ^= (reflectedByte << 24) & 0xFFFFFFFF;
      for (int i = 0; i < 8; i++) {
        if ((crc & 0x80000000) != 0) {
          crc = ((crc << 1) ^ poly) & 0xFFFFFFFF;
        } else {
          crc = (crc << 1) & 0xFFFFFFFF;
        }
      }
    }
    int reflectedCrc = _reverseBits32(crc);
    return (reflectedCrc ^ xorOut) & 0xFFFFFFFF;
  }

  /// Verifica se un pacchetto da 20 byte ha una firma CRC-32 valida nei byte [16..19]
  /// Verifica sia con CRC-32 standard sia con fallback legacy
  static bool verify(List<int> bytesWithCrc) {
    if (bytesWithCrc.length < 20) return false;
    final payload = bytesWithCrc.sublist(0, 16);
    final actualCrc = (bytesWithCrc[16] |
        (bytesWithCrc[17] << 8) |
        (bytesWithCrc[18] << 16) |
        (bytesWithCrc[19] << 24)) & 0xFFFFFFFF;
    
    // 1. Prova CRC-32 standard (hardware reale)
    final expectedStandard = compute(payload);
    if (expectedStandard == actualCrc) return true;

    // 2. Fallback legacy
    final expectedLegacy = computeLegacy(payload);
    return expectedLegacy == actualCrc;
  }

  static int _reverseBits8(int b) {
    int val = b & 0xFF;
    int rev = 0;
    for (int i = 0; i < 8; i++) {
      rev = (rev << 1) | (val & 1);
      val >>= 1;
    }
    return rev;
  }

  static int _reverseBits32(int x) {
    int val = x & 0xFFFFFFFF;
    int rev = 0;
    for (int i = 0; i < 32; i++) {
      rev = (rev << 1) | (val & 1);
      val >>= 1;
    }
    return rev & 0xFFFFFFFF;
  }
}

/// Algoritmo CRC-8 (Polinomio 0x07 / Lookup Table) per la verifica dell'Header della telemetria WHOOP
class WhoopCrc8 {
  static const List<int> _table = [
    0x00, 0x07, 0x0E, 0x09, 0x1C, 0x1B, 0x12, 0x15, 0x38, 0x3F, 0x36, 0x31, 0x24, 0x23, 0x2A, 0x2D,
    0x70, 0x77, 0x7E, 0x79, 0x6C, 0x6B, 0x62, 0x65, 0x48, 0x4F, 0x46, 0x41, 0x54, 0x53, 0x5A, 0x5D,
    0xE0, 0xE7, 0xEE, 0xE9, 0xFC, 0xFB, 0xF2, 0xF5, 0xD8, 0xDF, 0xD6, 0xD1, 0xC4, 0xC3, 0xCA, 0xCD,
    0x90, 0x97, 0x9E, 0x99, 0x8C, 0x8B, 0x82, 0x85, 0xA8, 0xAF, 0xA6, 0xA1, 0xB4, 0xB3, 0xBA, 0xBD,
    0xC7, 0xC0, 0xC9, 0xCE, 0xDB, 0xDC, 0xD5, 0xD2, 0xFF, 0xF8, 0xF1, 0xF6, 0xE3, 0xE4, 0xED, 0xEA,
    0xB7, 0xB0, 0xB9, 0xBE, 0xAB, 0xAC, 0xA5, 0xA2, 0x8F, 0x88, 0x81, 0x86, 0x93, 0x94, 0x9D, 0x9A,
    0x27, 0x20, 0x29, 0x2E, 0x3B, 0x3C, 0x35, 0x32, 0x1F, 0x18, 0x11, 0x16, 0x03, 0x04, 0x0D, 0x0A,
    0x57, 0x50, 0x59, 0x5E, 0x4B, 0x4C, 0x45, 0x42, 0x6F, 0x68, 0x61, 0x66, 0x73, 0x74, 0x7D, 0x7A,
    0x89, 0x8E, 0x87, 0x80, 0x95, 0x92, 0x9B, 0x9C, 0xB1, 0xB6, 0xBF, 0xB8, 0xAD, 0xAA, 0xA3, 0xA4,
    0xF9, 0xFE, 0xF7, 0xF0, 0xE5, 0xE2, 0xEB, 0xEC, 0xC1, 0xC6, 0xCF, 0xC8, 0xDD, 0xDA, 0xD3, 0xD4,
    0x69, 0x6E, 0x67, 0x60, 0x75, 0x72, 0x7B, 0x7C, 0x51, 0x56, 0x5F, 0x58, 0x4D, 0x4A, 0x43, 0x44,
    0x19, 0x1E, 0x17, 0x10, 0x05, 0x02, 0x0B, 0x0C, 0x21, 0x26, 0x2F, 0x28, 0x3D, 0x3A, 0x33, 0x34,
    0x4E, 0x49, 0x40, 0x47, 0x52, 0x55, 0x5C, 0x5B, 0x76, 0x71, 0x78, 0x7F, 0x6A, 0x6D, 0x64, 0x63,
    0x3E, 0x39, 0x30, 0x37, 0x22, 0x25, 0x2C, 0x2B, 0x06, 0x01, 0x08, 0x0F, 0x1A, 0x1D, 0x14, 0x13,
    0xAE, 0xA9, 0xA0, 0xA7, 0xB2, 0xB5, 0xBC, 0xBB, 0x96, 0x91, 0x98, 0x9F, 0x8A, 0x8D, 0x84, 0x83,
    0xDE, 0xD9, 0xD0, 0xD7, 0xC2, 0xC5, 0xCC, 0xCB, 0xE6, 0xE1, 0xE8, 0xEF, 0xFA, 0xFD, 0xF4, 0xF3,
  ];

  static int compute(List<int> bytes) {
    int crc = 0x00;
    for (int b in bytes) {
      crc = _table[(crc ^ (b & 0xFF)) & 0xFF];
    }
    return crc & 0xFF;
  }

  static bool verify(List<int> bytes, int expectedCrc) {
    return compute(bytes) == (expectedCrc & 0xFF);
  }
}

/// Calcolatore CRC16-Modbus per il framing dei pacchetti BLE WHOOP (da ryanbr/noop)
class Crc16Modbus {
  static int calculate(List<int> bytes) {
    int crc = 0xFFFF;
    for (int b in bytes) {
      crc ^= (b & 0xFF);
      for (int i = 0; i < 8; i++) {
        if ((crc & 0x0001) != 0) {
          crc = (crc >> 1) ^ 0xA001;
        } else {
          crc >>= 1;
        }
      }
    }
    return crc & 0xFFFF;
  }

  static bool verify(List<int> bytesWithCrc) {
    if (bytesWithCrc.length < 2) return false;
    final payload = bytesWithCrc.sublist(0, bytesWithCrc.length - 2);
    final expectedCrc = calculate(payload);
    final actualCrc = bytesWithCrc[bytesWithCrc.length - 2] | (bytesWithCrc[bytesWithCrc.length - 1] << 8);
    return expectedCrc == actualCrc;
  }
}

/// Encoder per comandi, vibrazione aptica e sveglia per WHOOP 4.0 / 5.0
class HapticClockEncoder {
  /// Costruisce un frame di comando binario formattato per WHOOP 4.0 / 5.0:
  /// Header: [0xAA, len_lo, len_hi, crc8([len_lo, len_hi])]
  /// Body:   [type (0x23), seq, cmd, ...payload]
  /// Tail:   [crc32_lo, crc32_b1, crc32_b2, crc32_hi]
  static Uint8List buildFramedCommand({
    required int cmd,
    List<int> payload = const [],
    int seq = 1,
    int type = 0x23,
  }) {
    // Lunghezza del body = 1 (type) + 1 (seq) + 1 (cmd) + payload.length + 4 (crc32)
    final int bodyLength = 3 + payload.length + 4;
    final Uint8List frame = Uint8List(4 + bodyLength);

    // 0..3: Header con Sync byte 0xAA e CRC8 su len
    frame[0] = 0xAA;
    frame[1] = bodyLength & 0xFF;
    frame[2] = (bodyLength >> 8) & 0xFF;
    frame[3] = WhoopCrc8.compute([frame[1], frame[2]]);

    // 4..N: Byte interni su cui viene calcolato il CRC-32
    final List<int> innerBytes = [
      type & 0xFF,
      seq & 0xFF,
      cmd & 0xFF,
      ...payload,
    ];

    for (int i = 0; i < innerBytes.length; i++) {
      frame[4 + i] = innerBytes[i];
    }

    // CRC-32 standard IEEE 802.3 sui byte interni
    final int crc32 = WhoopCrc32.compute(innerBytes);
    final int crcOffset = 4 + innerBytes.length;
    frame[crcOffset] = crc32 & 0xFF;
    frame[crcOffset + 1] = (crc32 >> 8) & 0xFF;
    frame[crcOffset + 2] = (crc32 >> 16) & 0xFF;
    frame[crcOffset + 3] = (crc32 >> 24) & 0xFF;

    return frame;
  }

  /// Genera il pacchetto binario a 20 byte per impostare il comando allarme alla caratteristica CMD_TO_STRAP:
  ///   0x00 - 0x04: Preambolo fisso [0xAA, 0x10, 0x00, 0x57, 0x23]
  ///   0x05: Contatore pacchetto uint8_t
  ///   0x06 - 0x07: Flag modalità allarme uint16_le (0x0142 -> cmd 0x42 SET_ALARM_TIME, subflag 0x01)
  ///   0x08 - 0x0B: Timestamp Target UTC Epoch uint32_le
  ///   0x0C - 0x0F: Padding [0x00, 0x00, 0x00, 0x00]
  ///   0x10 - 0x13: Checksum CRC-32 uint32_le
  static Uint8List buildAlarmCommandPayload({
    required int targetTimestampUtc,
    int packetCounter = 0x01,
    int alarmFlags = 0x0142,
  }) {
    final payload = Uint8List(20);

    // 0x00 - 0x04: Header fisso
    payload[0] = 0xAA;
    payload[1] = 0x10;
    payload[2] = 0x00;
    payload[3] = 0x57;
    payload[4] = 0x23;

    // 0x05: Contatore pacchetto
    payload[5] = packetCounter & 0xFF;

    // 0x06 - 0x07: Flag modalità (uint16_le: 0x0142 -> [0x42, 0x01])
    payload[6] = alarmFlags & 0xFF;
    payload[7] = (alarmFlags >> 8) & 0xFF;

    // 0x08 - 0x0B: Timestamp UTC Epoch uint32_le
    payload[8] = targetTimestampUtc & 0xFF;
    payload[9] = (targetTimestampUtc >> 8) & 0xFF;
    payload[10] = (targetTimestampUtc >> 16) & 0xFF;
    payload[11] = (targetTimestampUtc >> 24) & 0xFF;

    // 0x0C - 0x0F: Padding
    payload[12] = 0x00;
    payload[13] = 0x00;
    payload[14] = 0x00;
    payload[15] = 0x00;

    // 0x10 - 0x13: Checksum CRC-32 (Standard IEEE 802.3)
    final checksum = WhoopCrc32.compute(payload.sublist(0, 16));

    payload[16] = checksum & 0xFF;
    payload[17] = (checksum >> 8) & 0xFF;
    payload[18] = (checksum >> 16) & 0xFF;
    payload[19] = (checksum >> 24) & 0xFF;

    return payload;
  }

  /// Alias con nome PascalCase per test ed integrazioni `BuildAlarmCommandPayload`
  static Uint8List BuildAlarmCommandPayload(
    int targetTimestampUtc,
    int packetCounter,
    int alarmFlags,
  ) {
    return buildAlarmCommandPayload(
      targetTimestampUtc: targetTimestampUtc,
      packetCounter: packetCounter,
      alarmFlags: alarmFlags,
    );
  }

  /// Genera il pacchetto di allarme impostando il timestamp UTC da DateTime
  static Uint8List encodeAlarmTime({
    required DateTime alarmTime,
    bool isSilentAlarm = true,
    int vibrationPattern = 1,
    int packetCounter = 0x01,
    int alarmFlags = 0x0142,
  }) {
    final timestampSeconds = alarmTime.toUtc().millisecondsSinceEpoch ~/ 1000;
    return buildAlarmCommandPayload(
      targetTimestampUtc: timestampSeconds,
      packetCounter: packetCounter,
      alarmFlags: alarmFlags,
    );
  }

  /// Genera il pacchetto per il test vibrazione immediato (T_attuale + 3 secondi)
  static Uint8List encodeTestVibrationPayload({int pattern = 1, int packetCounter = 0x01}) {
    final nowUtc = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
    return buildAlarmCommandPayload(
      targetTimestampUtc: nowUtc + 3,
      packetCounter: packetCounter & 0xFF,
      alarmFlags: 0x0142,
    );
  }

  /// Opcode 68 (0x44): RUN_ALARM -> Attiva immediatamente il buzzer dell'allarme sulla strap
  static Uint8List buildRunAlarmCommand({int seq = 1}) {
    return buildFramedCommand(cmd: 68, payload: const [0x01], seq: seq);
  }

  /// Opcode 79 (0x4F): RUN_HAPTICS_PATTERN -> Esegue un pattern haptic predefinito sul motore WHOOP 4.0
  static Uint8List buildRunHapticsPatternCommand({int seq = 1, int patternId = 2, int duration = 3}) {
    return buildFramedCommand(cmd: 79, payload: [patternId, duration, 0x00, 0x00, 0x00], seq: seq);
  }

  /// Opcode 19 (0x13): RUN_HAPTIC_PATTERN_MAVERICK -> Esegue pattern haptic su WHOOP 5.0 / MG / Maverick
  static Uint8List buildRunHapticPatternMaverickCommand({int seq = 1, int loops = 3}) {
    final loopCount = (loops - 1).clamp(0, 10);
    return buildFramedCommand(
      cmd: 19,
      payload: [0x01, 47, 152, 0, 0, 0, 0, 0, 0, 0, 0, loopCount],
      seq: seq,
    );
  }

  /// Opcode 69 (0x45): DISABLE_ALARM -> Disabilita l'allarme attivo sul cinturino
  static Uint8List buildDisableAlarmCommand({int seq = 1}) {
    return buildFramedCommand(cmd: 69, payload: const [0x01], seq: seq);
  }

  /// Opcode 35 / 145: GET_HELLO -> Handshake iniziale WHOOP 4.0 (35) / 5.0 (145)
  static Uint8List buildGetHelloCommand({int seq = 1, bool isMaverick = false}) {
    return buildFramedCommand(cmd: isMaverick ? 145 : 35, payload: const [], seq: seq);
  }

  /// Opcode 10 (0x0A): SET_CLOCK -> Sincronizza l'orologio interno del cinturino
  static Uint8List buildSetClockCommand({required int epochSec, int seq = 1}) {
    final payload = [
      epochSec & 0xFF,
      (epochSec >> 8) & 0xFF,
      (epochSec >> 16) & 0xFF,
      (epochSec >> 24) & 0xFF,
      0x00, 0x00, 0x00, 0x00,
    ];
    return buildFramedCommand(cmd: 10, payload: payload, seq: seq);
  }

  /// Opcode 14 (0x0E): TOGGLE_GENERIC_HR_PROFILE -> Sblocca e abilita il profilo standard BLE Heart Rate (0x180D)
  static Uint8List buildToggleGenericHrProfileCommand({int seq = 1, bool enable = true}) {
    return buildFramedCommand(cmd: 14, payload: [enable ? 0x01 : 0x00], seq: seq);
  }

  /// Opcode 3 (0x03): TOGGLE_REALTIME_HR -> Abilita lo streaming dei pacchetti real-time 1 Hz
  static Uint8List buildToggleRealtimeHrCommand({int seq = 1, bool enable = true}) {
    return buildFramedCommand(cmd: 3, payload: [enable ? 0x01 : 0x00], seq: seq);
  }

  /// Genera il pacchetto di comando diretto motore haptic (Opcode 0x07)
  static Uint8List encodeHapticMotorDirect({int pattern = 1}) {
    final bytes = <int>[0x07, 0x01, pattern & 0xFF, 0x0A, 0x00, 0x00];
    final crc = Crc16Modbus.calculate(bytes);
    return Uint8List.fromList([...bytes, crc & 0xFF, (crc >> 8) & 0xFF]);
  }

  /// Genera il pacchetto per annullare/disattivare la sveglia sul cinturino
  static Uint8List encodeCancelAlarm() {
    return buildAlarmCommandPayload(
      targetTimestampUtc: 0,
      packetCounter: 0x00,
      alarmFlags: 0x0000,
    );
  }
}

/// Demuxer e validatore dei pacchetti proprietari a 96-byte (WhoopProtocol di noop)
class NoopProtocolDecoder {
  /// Valida la struttura del frame a 96 byte del sensore WHOOP
  static bool isValid96ByteFrame(Uint8List bytes) {
    if (bytes.length < 96) return false;
    final syncByte = bytes[0];
    if (syncByte != 0xAA && syncByte != 0x55) return false;
    return true;
  }

  /// Estrae i campioni raw di segnale (PPG, ECG, Accel) da un pacchetto a 96 byte
  static Map<String, dynamic> parseRawFrame(Uint8List bytes) {
    if (!isValid96ByteFrame(bytes)) {
      return {'valid': false};
    }

    final data = ByteData.view(bytes.buffer);
    final sequenceNum = data.getUint16(2, Endian.little);
    final timestampMs = data.getUint32(4, Endian.little);
    final hrBpm = data.getUint8(8);
    final hrvMs = data.getUint16(9, Endian.little) / 10.0;
    final accelX = data.getInt16(11, Endian.little) / 1000.0;
    final accelY = data.getInt16(13, Endian.little) / 1000.0;
    final accelZ = data.getInt16(15, Endian.little) / 1000.0;
    final tempC = 36.0 + (data.getInt8(17) / 10.0);

    return {
      'valid': true,
      'sequenceNum': sequenceNum,
      'timestampMs': timestampMs,
      'hrBpm': hrBpm,
      'hrvMs': hrvMs,
      'accelG': {'x': accelX, 'y': accelY, 'z': accelZ},
      'tempC': tempC,
    };
  }
}

/// Definizioni delle varianti hardware WHOOP (Whoop5Variant da ryanbr/noop)
enum WhoopHardwareVariant {
  whoop3('WHOOP 3.0', 'WP3'),
  whoop4('WHOOP 4.0', 'WP4'),
  whoop5('WHOOP 5.0', 'WP5');

  final String displayName;
  final String codePrefix;
  const WhoopHardwareVariant(this.displayName, this.codePrefix);

  static WhoopHardwareVariant fromPlatformName(String name) {
    final upper = name.toUpperCase();
    if (upper.contains('5.0') || upper.contains('WP5')) return WhoopHardwareVariant.whoop5;
    if (upper.contains('3.0') || upper.contains('WP3')) return WhoopHardwareVariant.whoop3;
    return WhoopHardwareVariant.whoop4;
  }
}
