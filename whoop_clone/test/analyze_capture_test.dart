import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import '../tools/analyze_capture.dart';

void main() {
  group('CaptureAnalyzer Unit Tests', () {
    test('Analizza correttamente istogramma, primo byte, intervalli e buchi di trasmissione', () {
      final lines = [
        jsonEncode({
          'charUuid': '61080005',
          'timestampUtcMs': 1000,
          'byteLength': 4,
          'hexPayload': 'aa010203',
        }),
        jsonEncode({
          'charUuid': '61080005',
          'timestampUtcMs': 2000,
          'byteLength': 4,
          'hexPayload': 'aa040506',
        }),
        jsonEncode({
          'charUuid': '2a37',
          'timestampUtcMs': 18000, // Gap di 16s (>10s)
          'byteLength': 2,
          'hexPayload': '164b',
        }),
      ];

      final report = CaptureAnalyzer.analyzeLines(lines, filePath: 'test.ndjson');

      expect(report.totalLines, equals(3));
      expect(report.validPackets, equals(3));
      expect(report.malformedLines, equals(0));

      // Lunghezze
      expect(report.lengthHistogram[4], equals(2));
      expect(report.lengthHistogram[2], equals(1));

      // Primo byte
      expect(report.firstByteDistribution[0xAA], equals(2));
      expect(report.firstByteDistribution[0x16], equals(1));

      // Gap
      expect(report.gaps.length, equals(1));
      expect(report.gaps.first.duration.inSeconds, equals(16));

      // Report formattato
      final formatted = report.formatReport();
      expect(formatted, contains('REPORT ANALISI FORENSE'));
      expect(formatted, contains('Rilevati 1 buchi di trasmissione critici'));
    });
  });
}
