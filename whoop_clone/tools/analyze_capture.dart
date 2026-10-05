import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:whoop_clone/data/ble/noop_protocol_decoder.dart';

/// Risultato di un buco di telemetria rilevato (> 10 secondi)
class TelemetryGapInfo {
  final DateTime startTime;
  final DateTime endTime;
  final Duration duration;
  final int startIndex;
  final int endIndex;

  TelemetryGapInfo({
    required this.startTime,
    required this.endTime,
    required this.duration,
    required this.startIndex,
    required this.endIndex,
  });

  @override
  String toString() {
    final startStr = startTime.toUtc().toIso8601String();
    final endStr = endTime.toUtc().toIso8601String();
    final durSec = (duration.inMilliseconds / 1000.0).toStringAsFixed(2);
    return 'Gap [$startIndex -> $endIndex]: $startStr a $endStr ($durSec s)';
  }
}

/// Report strutturato generato dall'analisi forense della cattura NDJSON
class CaptureAnalysisReport {
  final String filePath;
  final int totalLines;
  final int validPackets;
  final int malformedLines;
  final DateTime? firstTimestamp;
  final DateTime? lastTimestamp;
  final Duration totalDuration;

  // Istogramma lunghezze byte
  final Map<int, int> lengthHistogram;

  // Distribuzione primo byte (Frame Sync)
  final Map<int, int> firstByteDistribution;

  // % Validità CRC sotto varie ipotesi
  final int totalFramed0xAa;
  final int validHeaderCrc8;
  final int validTailCrc32;
  final int total20Byte;
  final int valid20ByteCrc32Ieee;
  final int valid20ByteCrc32Legacy;
  final int validCrc16Modbus;

  // Statistiche intervalli temporali pacchetti (ms)
  final double meanIntervalMs;
  final double medianIntervalMs;
  final double p95IntervalMs;
  final double p99IntervalMs;
  final int minIntervalMs;
  final int maxIntervalMs;

  // Buchi di trasmissione (> 10s)
  final List<TelemetryGapInfo> gaps;

  CaptureAnalysisReport({
    required this.filePath,
    required this.totalLines,
    required this.validPackets,
    required this.malformedLines,
    required this.firstTimestamp,
    required this.lastTimestamp,
    required this.totalDuration,
    required this.lengthHistogram,
    required this.firstByteDistribution,
    required this.totalFramed0xAa,
    required this.validHeaderCrc8,
    required this.validTailCrc32,
    required this.total20Byte,
    required this.valid20ByteCrc32Ieee,
    required this.valid20ByteCrc32Legacy,
    required this.validCrc16Modbus,
    required this.meanIntervalMs,
    required this.medianIntervalMs,
    required this.p95IntervalMs,
    required this.p99IntervalMs,
    required this.minIntervalMs,
    required this.maxIntervalMs,
    required this.gaps,
  });

  /// Genera output testuale formattato con tabelle e grafici ASCII
  String formatReport() {
    final sb = StringBuffer();
    final sep = '=' * 75;
    final subSep = '-' * 75;

    sb.writeln(sep);
    sb.writeln('  REPORT ANALISI FORENSE CATTURA RAW BLE (NDJSON)');
    sb.writeln(sep);
    sb.writeln('  File: $filePath');
    sb.writeln('  Righe totali: $totalLines (Validi: $validPackets, Malformati: $malformedLines)');
    if (firstTimestamp != null && lastTimestamp != null) {
      sb.writeln('  Inizio cattura: ${firstTimestamp!.toUtc().toIso8601String()}');
      sb.writeln('  Fine cattura:   ${lastTimestamp!.toUtc().toIso8601String()}');
      sb.writeln('  Durata totale:  ${_formatDuration(totalDuration)}');
    }
    sb.writeln(subSep);

    // 1. Istogramma lunghezze pacchetti
    sb.writeln('\n[1] ISTOGRAMMA DELLE LUNGHEZZE DEI PACCHETTI (BYTE)');
    final sortedLengths = lengthHistogram.keys.toList()..sort();
    final maxCount = lengthHistogram.values.isEmpty ? 1 : lengthHistogram.values.reduce(math.max);

    for (final len in sortedLengths) {
      final count = lengthHistogram[len]!;
      final pct = (count / validPackets * 100.0).toStringAsFixed(1);
      final barLen = ((count / maxCount) * 24).round();
      final bar = '█' * barLen;
      sb.writeln('  ${len.toString().padLeft(3)} bytes | ${bar.padRight(25)} $count ($pct%)');
    }

    // 2. Distribuzione primi byte
    sb.writeln('\n[2] DISTRIBUZIONE DEI PRIMI BYTE / TIPI DI FRAME');
    final sortedFirstBytes = firstByteDistribution.keys.toList()..sort();
    for (final fb in sortedFirstBytes) {
      final count = firstByteDistribution[fb]!;
      final pct = (count / validPackets * 100.0).toStringAsFixed(1);
      final hexStr = '0x${fb.toRadixString(16).padLeft(2, '0').toUpperCase()}';
      final desc = _describeFirstByte(fb);
      sb.writeln('  $hexStr ($desc): $count ($pct%)');
    }

    // 3. Verifica CRC sotto varie ipotesi
    sb.writeln('\n[3] ANALISI INTEGRITÀ E VALIDITÀ DEI CHECKSUM (CRC)');
    if (totalFramed0xAa > 0) {
      final hCrcPct = (validHeaderCrc8 / totalFramed0xAa * 100.0).toStringAsFixed(1);
      final tCrcPct = (validTailCrc32 / totalFramed0xAa * 100.0).toStringAsFixed(1);
      sb.writeln('  * Ipotesi 1: Framing WHOOP 0xAA (Totale frame 0xAA: $totalFramed0xAa)');
      sb.writeln('    - Header CRC-8 valido (byte 3): $validHeaderCrc8 / $totalFramed0xAa ($hCrcPct%)');
      sb.writeln('    - Tail CRC-32 IEEE 802.3 valido: $validTailCrc32 / $totalFramed0xAa ($tCrcPct%)');
    } else {
      sb.writeln('  * Ipotesi 1: Framing WHOOP 0xAA -> Nessun frame 0xAA rilevato');
    }

    if (total20Byte > 0) {
      final ieeePct = (valid20ByteCrc32Ieee / total20Byte * 100.0).toStringAsFixed(1);
      final legacyPct = (valid20ByteCrc32Legacy / total20Byte * 100.0).toStringAsFixed(1);
      sb.writeln('  * Ipotesi 2: Frame 20-byte Comandi/Allarme (Totale pacchetti: $total20Byte)');
      sb.writeln('    - CRC-32 IEEE 802.3 sui primi 16 byte: $valid20ByteCrc32Ieee / $total20Byte ($ieeePct%)');
      sb.writeln('    - CRC-32 Legacy proprietario:        $valid20ByteCrc32Legacy / $total20Byte ($legacyPct%)');
    }

    final crc16Pct = validPackets > 0
        ? (validCrc16Modbus / validPackets * 100.0).toStringAsFixed(1)
        : '0.0';
    sb.writeln('  * Ipotesi 3: CRC-16 Modbus (ultimi 2 byte su tutti i pacchetti): $validCrc16Modbus / $validPackets ($crc16Pct%)');

    // 4. Statistiche intervalli temporali
    sb.writeln('\n[4] INTERVALLO TEMPORALE TRA PACCHETTI CONSECUTIVI (DELTA MS)');
    sb.writeln('  * Minimo:  $minIntervalMs ms');
    sb.writeln('  * Medio:   ${meanIntervalMs.toStringAsFixed(1)} ms');
    sb.writeln('  * Mediano: ${medianIntervalMs.toStringAsFixed(1)} ms');
    sb.writeln('  * 95° perc (P95): ${p95IntervalMs.toStringAsFixed(1)} ms');
    sb.writeln('  * 99° perc (P99): ${p99IntervalMs.toStringAsFixed(1)} ms');
    sb.writeln('  * Massimo: $maxIntervalMs ms');

    // 5. Buchi di trasmissione (> 10s)
    sb.writeln('\n[5] RILEVAMENTO BUCHI DI TRASMISSIONE (> 10 SECONDI)');
    if (gaps.isEmpty) {
      sb.writeln('  ✅ [OK] Nessun buco di trasmissione (> 10s) rilevato!');
    } else {
      sb.writeln('  ⚠️  Rilevati ${gaps.length} buchi di trasmissione critici:');
      for (int i = 0; i < gaps.length; i++) {
        final g = gaps[i];
        final durSec = (g.duration.inMilliseconds / 1000.0).toStringAsFixed(2);
        sb.writeln('    ${i + 1}. Inizio: ${g.startTime.toUtc().toIso8601String()} -> Fine: ${g.endTime.toUtc().toIso8601String()} (Durata: ${durSec}s, indice: ${g.startIndex} -> ${g.endIndex})');
      }
    }
    sb.writeln(sep);

    return sb.toString();
  }

  static String _formatDuration(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    final ms = (d.inMilliseconds % 1000).toString().padLeft(3, '0');
    return '$h:$m:$s.$ms (${d.inMilliseconds} ms)';
  }

  static String _describeFirstByte(int byte) {
    switch (byte) {
      case 0xAA:
        return '0xAA WHOOP Sync / Framed / Sensor';
      case 0x55:
        return '0x55 Alternative Sensor Sync';
      case 0x16:
        return '0x16 Heart Rate 0x2A37 Format';
      case 0x10:
        return '0x10 Command Opcode / Length';
      case 0x23:
        return '0x23 Command Type Body';
      default:
        return 'Generico / Dati grezzi';
    }
  }
}

/// Motore di analisi per i file di cattura NDJSON
class CaptureAnalyzer {
  static Uint8List hexToBytes(String hex) {
    final clean = hex.replaceAll(' ', '').trim();
    final len = clean.length ~/ 2;
    final bytes = Uint8List(len);
    for (int i = 0; i < len; i++) {
      bytes[i] = int.parse(clean.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return bytes;
  }

  /// Esegue l'analisi completa su un file NDJSON
  static Future<CaptureAnalysisReport> analyzeFile(File file) async {
    if (!await file.exists()) {
      throw ArgumentError('File non trovato: ${file.path}');
    }
    final lines = await file.readAsLines();
    return analyzeLines(lines, filePath: file.path);
  }

  /// Esegue l'analisi su una lista di righe NDJSON
  static CaptureAnalysisReport analyzeLines(
    List<String> lines, {
    String filePath = 'in-memory.ndjson',
  }) {
    int validPackets = 0;
    int malformedLines = 0;

    final Map<int, int> lengthHistogram = {};
    final Map<int, int> firstByteDistribution = {};

    int totalFramed0xAa = 0;
    int validHeaderCrc8 = 0;
    int validTailCrc32 = 0;

    int total20Byte = 0;
    int valid20ByteCrc32Ieee = 0;
    int valid20ByteCrc32Legacy = 0;
    int validCrc16Modbus = 0;

    DateTime? firstTimestamp;
    DateTime? lastTimestamp;
    final List<int> timestampsMs = [];
    final List<TelemetryGapInfo> gaps = [];

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      try {
        final json = jsonDecode(line) as Map<String, dynamic>;
        final hex = (json['hexPayload'] as String? ?? '').trim();
        final tsMs = json['timestampUtcMs'] as int?;

        if (hex.isEmpty || tsMs == null) {
          malformedLines++;
          continue;
        }

        final bytes = hexToBytes(hex);
        validPackets++;
        timestampsMs.add(tsMs);

        final dt = DateTime.fromMillisecondsSinceEpoch(tsMs, isUtc: true);
        if (firstTimestamp == null || dt.isBefore(firstTimestamp)) {
          firstTimestamp = dt;
        }
        if (lastTimestamp == null || dt.isAfter(lastTimestamp)) {
          lastTimestamp = dt;
        }

        // 1. Istogramma lunghezza
        final len = bytes.length;
        lengthHistogram[len] = (lengthHistogram[len] ?? 0) + 1;

        // 2. Primo byte
        final fb = bytes[0];
        firstByteDistribution[fb] = (firstByteDistribution[fb] ?? 0) + 1;

        // 3. Ipotesi 1: Framing WHOOP 0xAA
        if (fb == 0xAA && len >= 8) {
          totalFramed0xAa++;
          final lenLo = bytes[1];
          final lenHi = bytes[2];
          final crc8 = bytes[3];
          final expectedCrc8 = WhoopCrc8.compute([lenLo, lenHi]);
          if (crc8 == expectedCrc8) {
            validHeaderCrc8++;
          }

          final bodyLen = lenLo | (lenHi << 8);
          if (len >= 4 + bodyLen && bodyLen >= 4) {
            final innerLen = bodyLen - 4;
            final innerBytes = bytes.sublist(4, 4 + innerLen);
            final expectedTailCrc = WhoopCrc32.compute(innerBytes);
            final tailOffset = 4 + innerLen;
            final actualTailCrc = (bytes[tailOffset] |
                    (bytes[tailOffset + 1] << 8) |
                    (bytes[tailOffset + 2] << 16) |
                    (bytes[tailOffset + 3] << 24)) &
                0xFFFFFFFF;
            if (expectedTailCrc == actualTailCrc) {
              validTailCrc32++;
            }
          }
        }

        // 4. Ipotesi 2: 20-byte Comandi/Allarme
        if (len == 20) {
          total20Byte++;
          final first16 = bytes.sublist(0, 16);
          final actualCrc = (bytes[16] |
                  (bytes[17] << 8) |
                  (bytes[18] << 16) |
                  (bytes[19] << 24)) &
              0xFFFFFFFF;
          if (WhoopCrc32.compute(first16) == actualCrc) {
            valid20ByteCrc32Ieee++;
          }
          if (WhoopCrc32.computeLegacy(first16) == actualCrc) {
            valid20ByteCrc32Legacy++;
          }
        }

        // 5. Ipotesi 3: CRC16-Modbus (ultimi 2 byte)
        if (len >= 3) {
          if (Crc16Modbus.verify(bytes)) {
            validCrc16Modbus++;
          }
        }
      } catch (_) {
        malformedLines++;
      }
    }

    // Calcolo intervalli consecutivi e buchi di trasmissione (> 10s)
    final List<int> deltas = [];
    for (int i = 1; i < timestampsMs.length; i++) {
      final delta = timestampsMs[i] - timestampsMs[i - 1];
      if (delta >= 0) {
        deltas.add(delta);
        if (delta > 10000) {
          // Buco di trasmissione > 10 secondi
          final sTime = DateTime.fromMillisecondsSinceEpoch(timestampsMs[i - 1], isUtc: true);
          final eTime = DateTime.fromMillisecondsSinceEpoch(timestampsMs[i], isUtc: true);
          gaps.add(TelemetryGapInfo(
            startTime: sTime,
            endTime: eTime,
            duration: Duration(milliseconds: delta),
            startIndex: i - 1,
            endIndex: i,
          ));
        }
      }
    }

    deltas.sort();
    double meanMs = 0;
    double medianMs = 0;
    double p95Ms = 0;
    double p99Ms = 0;
    int minMs = deltas.isNotEmpty ? deltas.first : 0;
    int maxMs = deltas.isNotEmpty ? deltas.last : 0;

    if (deltas.isNotEmpty) {
      final sum = deltas.reduce((a, b) => a + b);
      meanMs = sum / deltas.length;
      medianMs = _percentile(deltas, 0.50);
      p95Ms = _percentile(deltas, 0.95);
      p99Ms = _percentile(deltas, 0.99);
    }

    final duration = (firstTimestamp != null && lastTimestamp != null)
        ? lastTimestamp.difference(firstTimestamp)
        : Duration.zero;

    return CaptureAnalysisReport(
      filePath: filePath,
      totalLines: lines.length,
      validPackets: validPackets,
      malformedLines: malformedLines,
      firstTimestamp: firstTimestamp,
      lastTimestamp: lastTimestamp,
      totalDuration: duration,
      lengthHistogram: lengthHistogram,
      firstByteDistribution: firstByteDistribution,
      totalFramed0xAa: totalFramed0xAa,
      validHeaderCrc8: validHeaderCrc8,
      validTailCrc32: validTailCrc32,
      total20Byte: total20Byte,
      valid20ByteCrc32Ieee: valid20ByteCrc32Ieee,
      valid20ByteCrc32Legacy: valid20ByteCrc32Legacy,
      validCrc16Modbus: validCrc16Modbus,
      meanIntervalMs: meanMs,
      medianIntervalMs: medianMs,
      p95IntervalMs: p95Ms,
      p99IntervalMs: p99Ms,
      minIntervalMs: minMs,
      maxIntervalMs: maxMs,
      gaps: gaps,
    );
  }

  static double _percentile(List<int> sortedValues, double p) {
    if (sortedValues.isEmpty) return 0.0;
    final index = (p * (sortedValues.length - 1)).round();
    return sortedValues[index.clamp(0, sortedValues.length - 1)].toDouble();
  }
}

void main(List<String> args) async {
  if (args.isEmpty) {
    stdout.writeln('Uso: dart run tools/analyze_capture.dart <percorso_file.ndjson>');
    exit(0);
  }

  final filePath = args[0];
  final file = File(filePath);

  if (!await file.exists()) {
    stderr.writeln('Errore: Il file specificato non esiste: $filePath');
    exit(1);
  }

  stdout.writeln('Analisi del file di cattura in corso: $filePath ...\n');
  try {
    final report = await CaptureAnalyzer.analyzeFile(file);
    stdout.writeln(report.formatReport());
  } catch (e, st) {
    stderr.writeln('Errore durante l\'analisi: $e\n$st');
    exit(1);
  }
}
