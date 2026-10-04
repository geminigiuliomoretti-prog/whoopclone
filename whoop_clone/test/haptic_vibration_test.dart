import 'package:flutter_test/flutter_test.dart';
import 'package:whoop_clone/data/ble/noop_protocol_decoder.dart';

void main() {
  group('WHOOP Haptic Vibration & Alarm Payload Tests', () {
    test('HapticClockEncoder.encodeTestVibrationPayload genera un frame da 20 byte con preambolo 0xAA e CRC32 valido', () {
      final payload = HapticClockEncoder.encodeTestVibrationPayload(pattern: 1, packetCounter: 0x05);

      expect(payload.length, equals(20));

      // Header fisso [0xAA, 0x10, 0x00, 0x57, 0x23]
      expect(payload[0], equals(0xAA));
      expect(payload[1], equals(0x10));
      expect(payload[2], equals(0x00));
      expect(payload[3], equals(0x57));
      expect(payload[4], equals(0x23));

      // Contatore pacchetto uint8
      expect(payload[5], equals(0x05));

      // Flag Allarme [0x42, 0x01] (0x0142)
      expect(payload[6], equals(0x42));
      expect(payload[7], equals(0x01));

      // Checksum CRC32 sui primi 16 byte
      final isValidCrc = WhoopCrc32.verify(payload);
      expect(isValidCrc, isTrue);
    });
  });
}
