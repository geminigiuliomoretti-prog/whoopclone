import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:whoop_clone/data/ble/noop_protocol_decoder.dart';

void main() {
  group('WHOOP CRC Frame Validation Unit Tests', () {
    test('WhoopCrc8 calcola e valida il checksum dell\'Header di telemetria', () {
      final headerBytes = [0x01, 0x00, 0x16];
      final crc = WhoopCrc8.compute(headerBytes);

      expect(crc, isA<int>());
      expect(WhoopCrc8.verify(headerBytes, crc), isTrue);
      expect(WhoopCrc8.verify(headerBytes, crc ^ 0xFF), isFalse);

      // Verifica indici corretti 248-255 (poly 0x07)
      expect(WhoopCrc8.compute([0xF8]), equals(0xE6));
      expect(WhoopCrc8.compute([0xFF]), equals(0xF3));
    });

    test('WhoopCrc32 valida i pacchetti da 20 byte con checksum corretto', () {
      final nowUtc = 1700000000;
      final alarmPayload = HapticClockEncoder.buildAlarmCommandPayload(
        targetTimestampUtc: nowUtc,
        packetCounter: 0x01,
        alarmFlags: 0x0142,
      );

      expect(alarmPayload.length, equals(20));
      expect(WhoopCrc32.verify(alarmPayload), isTrue);

      // Modifica un byte del payload e verifica lo scarto
      final corruptPayload = Uint8List.fromList(alarmPayload);
      corruptPayload[5] ^= 0xFF;
      expect(WhoopCrc32.verify(corruptPayload), isFalse);
    });

    test('Crc16Modbus calcola e valida i pacchetti legacy BLE', () {
      final dataBytes = [0x01, 0x05, 0x01, 0x02, 0x00, 0x00];
      final crc16 = Crc16Modbus.calculate(dataBytes);

      final fullFrame = [...dataBytes, crc16 & 0xFF, (crc16 >> 8) & 0xFF];
      expect(Crc16Modbus.verify(fullFrame), isTrue);

      fullFrame[2] ^= 0xAB;
      expect(Crc16Modbus.verify(fullFrame), isFalse);
    });
  });
}
