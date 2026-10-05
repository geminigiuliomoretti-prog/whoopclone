import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:whoop_clone/data/ble/frame_stream_parser.dart';
import 'package:whoop_clone/data/ble/noop_protocol_decoder.dart';
import 'package:whoop_clone/data/models/telemetry_sample.dart';

void main() {
  group('FrameStreamParser Tests', () {
    late FrameStreamParser parser;

    setUp(() {
      parser = FrameStreamParser();
    });

    tearDown(() {
      parser.dispose();
    });

    test('Riassembla un pacchetto frammentato su 3 chunk MTU', () async {
      // Costruiamo un frame framed standard:
      // [0xAA, lenLo, lenHi, crc8(len), ...payload..., crc32(payload)]
      final payload = <int>[0x01, 0x42, 0x16, 0x50, 0x00, 0x01]; // len = 6
      final lenLo = payload.length & 0xFF;
      final lenHi = (payload.length >> 8) & 0xFF;
      final crc8 = WhoopCrc8.compute([lenLo, lenHi]);
      final crc32 = WhoopCrc32.compute(payload);

      final fullFrame = <int>[
        0xAA,
        lenLo,
        lenHi,
        crc8,
        ...payload,
        crc32 & 0xFF,
        (crc32 >> 8) & 0xFF,
        (crc32 >> 16) & 0xFF,
        (crc32 >> 24) & 0xFF,
      ];

      expect(fullFrame.length, 14);

      // Dividiamo fullFrame in 3 chunk (es. 5, 5, 4 byte)
      final chunk1 = fullFrame.sublist(0, 5);
      final chunk2 = fullFrame.sublist(5, 10);
      final chunk3 = fullFrame.sublist(10, 14);

      final decodedFrames = <WhoopFrame>[];
      final decodedSamples = <TelemetrySample>[];

      parser.frameStream.listen(decodedFrames.add);
      parser.sampleStream.listen(decodedSamples.add);

      parser.addChunk(chunk1);
      expect(decodedFrames.isEmpty, isTrue);
      expect(parser.fragmentsReassembled, 1);

      parser.addChunk(chunk2);
      expect(decodedFrames.isEmpty, isTrue);
      expect(parser.fragmentsReassembled, 2);

      parser.addChunk(chunk3);
      await Future.delayed(const Duration(milliseconds: 10));

      expect(decodedFrames.length, 1);
      expect(decodedSamples.length, 1);
      expect(parser.framesDecoded, 1);
      expect(parser.crcErrors, 0);

      final frame = decodedFrames.first;
      expect(frame.type, FrameType.framedCommand);
      expect(frame.sequenceNumber, 0x42);
      expect(frame.commandOpcode, 0x16);
      expect(frame.payload, payload);

      final sample = decodedSamples.first;
      expect(sample.sequenceNumber, 0x42);
      expect(sample.hr, 0x50); // 80 bpm
    });

    test('Rifiuta frame con CRC-8 header errato', () async {
      final payload = <int>[0x01, 0x01, 0x16, 0x45];
      final lenLo = payload.length & 0xFF;
      final lenHi = (payload.length >> 8) & 0xFF;
      const invalidCrc8 = 0x00; // Errato apposta

      final frameWithBadCrc8 = <int>[
        0xAA,
        lenLo,
        lenHi,
        invalidCrc8,
        ...payload,
        0x12, 0x34, 0x56, 0x78,
      ];

      final decoded = <WhoopFrame>[];
      parser.frameStream.listen(decoded.add);

      parser.addChunk(frameWithBadCrc8);
      await Future.delayed(const Duration(milliseconds: 10));

      expect(decoded.isEmpty, isTrue);
      expect(parser.bytesDiscarded, greaterThanOrEqualTo(1));
    });

    test('Rifiuta frame con CRC-32 payload errato', () async {
      final payload = <int>[0x01, 0x10, 0x16, 0x45];
      final lenLo = payload.length & 0xFF;
      final lenHi = (payload.length >> 8) & 0xFF;
      final crc8 = WhoopCrc8.compute([lenLo, lenHi]);
      const badCrc32 = 0xDEADBEEF;

      final frameWithBadCrc32 = <int>[
        0xAA,
        lenLo,
        lenHi,
        crc8,
        ...payload,
        badCrc32 & 0xFF,
        (badCrc32 >> 8) & 0xFF,
        (badCrc32 >> 16) & 0xFF,
        (badCrc32 >> 24) & 0xFF,
      ];

      final decoded = <WhoopFrame>[];
      parser.frameStream.listen(decoded.add);

      parser.addChunk(frameWithBadCrc32);
      await Future.delayed(const Duration(milliseconds: 10));

      expect(decoded.isEmpty, isTrue);
      expect(parser.crcErrors, 1);
    });

    test('Decodifica frame flat a 96 byte senza framing 0xAA', () async {
      final flatBytes = Uint8List(96);
      // Imposta byte specifici: seq = 123 (bytes 0..1), hr = 72 (byte 4)
      flatBytes[0] = 123;
      flatBytes[1] = 0;
      flatBytes[4] = 72;

      final samples = <TelemetrySample>[];
      parser.sampleStream.listen(samples.add);

      parser.addChunk(flatBytes);
      await Future.delayed(const Duration(milliseconds: 10));

      expect(samples.length, 1);
      expect(samples.first.source, TelemetrySource.strapRealtime);
      expect(samples.first.hr, 72);
      expect(samples.first.sequenceNumber, 123);
    });
  });

  group('TelemetrySample & ENMO Tests', () {
    test('Calcola ENMO corretto = max(0.0, |accel| - 1.0) senza floor sintetico', () {
      // Caso 1: sensore fermo a 1g: ax=0, ay=0, az=1.0 -> mag = 1.0 -> ENMO = 0.0 esatto
      final restSample = TelemetrySample(
        timestamp: DateTime.now().toUtc(),
        accelX: 0.0,
        accelY: 0.0,
        accelZ: 1.0,
      );
      expect(restSample.enmo, 0.0); // Nessun floor 0.002 fittizio!

      // Caso 2: movimento sostenuto: ax=0.6, ay=0.8, az=0.0 -> mag = 1.0 -> ENMO = 0.0
      // Caso 3: movimento attivo: ax=1.0, ay=1.0, az=1.0 -> mag = sqrt(3) ~ 1.732 -> ENMO ~ 0.732
      final activeSample = TelemetrySample(
        timestamp: DateTime.now().toUtc(),
        accelX: 1.0,
        accelY: 1.0,
        accelZ: 1.0,
      );
      expect(activeSample.enmo, closeTo(0.732, 0.001));

      // Caso 4: sensore privo di assi accelerometro -> ENMO deve essere null
      final noAccelSample = TelemetrySample(
        timestamp: DateTime.now().toUtc(),
        hr: 60,
      );
      expect(noAccelSample.enmo, isNull);
    });

    test('Calcola rMSSD su intervalli RR reali', () {
      final sample = TelemetrySample(
        timestamp: DateTime.now().toUtc(),
        rrIntervalsMs: const [800.0, 850.0, 820.0, 860.0],
      );
      // diffs: +50, -30, +40
      // diff^2: 2500 + 900 + 1600 = 5000
      // mean: 5000 / 3 = 1666.67
      // sqrt(1666.67) ~ 40.82 ms
      expect(sample.rmssdFromRr, closeTo(40.82, 0.01));

      final singleRrSample = TelemetrySample(
        timestamp: DateTime.now().toUtc(),
        rrIntervalsMs: const [800.0],
      );
      expect(singleRrSample.rmssdFromRr, isNull);
    });
  });
}
