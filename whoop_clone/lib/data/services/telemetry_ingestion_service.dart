import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import '../ble/ble_diagnostic_service.dart';
import '../ble/hr_data_packet.dart';
import '../ble/noop_protocol_decoder.dart';
import '../ble/whoop_96byte_packet.dart';
import '../database/database_helper.dart';
import '../../core/logging/structured_logger.dart';

/// Qualità fisiologica e integrità del pacchetto telemetrico
enum TelemetryQuality {
  valid,
  lowConfidence,
  invalid,
}

/// Modello tipizzato per i pacchetti telemetrici validati e ingeriti dalla pipeline
@immutable
class IngestedTelemetry {
  final int? id;
  final DateTime timestamp;
  final int? sequenceNumber;
  final String source; // 'REAL_STREAM' | 'STORE_FORWARD'
  final String quality; // 'VALID' | 'LOW_CONFIDENCE' | 'INVALID'
  final bool isValid;
  final int? bpm;
  final double? rmssdMs;
  final double? rrMs;
  final String? rrIntervalsJson;
  final double? accelEnmo;
  final double? motionVar;
  final double? skinTempCelsius;
  final double? spo2Pct;
  final double? respRate;
  final double? respPower;
  final int? latencyMs;
  final List<int> rawBytes;

  const IngestedTelemetry({
    this.id,
    required this.timestamp,
    this.sequenceNumber,
    this.source = 'REAL_STREAM',
    this.quality = 'VALID',
    this.isValid = true,
    this.bpm,
    this.rmssdMs,
    this.rrMs,
    this.rrIntervalsJson,
    this.accelEnmo,
    this.motionVar,
    this.skinTempCelsius,
    this.spo2Pct,
    this.respRate,
    this.respPower,
    this.latencyMs,
    this.rawBytes = const [],
  });
}

/// Risultato dettagliato dell'ingestione di un singolo pacchetto
class IngestionResult {
  final bool accepted;
  final bool isDuplicate;
  final bool isValidCrc;
  final bool isValidPhysiology;
  final int? missingGap;
  final String? dropReason;
  final IngestedTelemetry? telemetry;

  const IngestionResult({
    required this.accepted,
    this.isDuplicate = false,
    this.isValidCrc = true,
    this.isValidPhysiology = true,
    this.missingGap,
    this.dropReason,
    this.telemetry,
  });

  factory IngestionResult.dropped({
    required String reason,
    bool isDuplicate = false,
    bool isValidCrc = true,
    bool isValidPhysiology = true,
  }) {
    return IngestionResult(
      accepted: false,
      isDuplicate: isDuplicate,
      isValidCrc: isValidCrc,
      isValidPhysiology: isValidPhysiology,
      dropReason: reason,
    );
  }

  factory IngestionResult.success(IngestedTelemetry telemetry, {int? missingGap}) {
    return IngestionResult(
      accepted: true,
      telemetry: telemetry,
      missingGap: missingGap,
    );
  }
}

/// Risultato dell'ingestione batch (tipico per Store-and-Forward da flash memory)
class BatchIngestionResult {
  final int totalReceived;
  final int saved;
  final int duplicates;
  final int invalid;
  final int gapsDetected;

  const BatchIngestionResult({
    required this.totalReceived,
    required this.saved,
    required this.duplicates,
    required this.invalid,
    required this.gapsDetected,
  });
}

/// Servizio centrale per l'ingestione streaming e batch dei dati telemetrici WHOOP.
/// Implementa la pipeline forense a 9 stadi:
/// RECEIVE -> TIMESTAMP -> SEQUENCE VALIDATION -> CRC/FRAME CHECK -> DECODE ->
/// PHYSIOLOGICAL RANGE FILTER -> DEDUPLICATION -> PERSISTENCE -> EMIT/ACK
class TelemetryIngestionService {
  final DatabaseHelper _dbHelper;
  final StreamController<IngestedTelemetry> _telemetryController =
      StreamController<IngestedTelemetry>.broadcast();

  // Sliding window per deduplicazione (ultimi 100 hash di pacchetti)
  static const int _dedupWindowSize = 100;
  final List<int> _recentPacketHashes = [];

  // Tracciamento Sequenze e Gap
  int? _lastSequenceNumber;
  static const int _maxSeq16Bit = 65536;

  // Rolling RR buffer per calcolare RMSSD continuo anche su stream BLE a 1 Hz (0x2A37)
  // dove ogni singolo pacchetto contiene solo 0 o 1 intervallo R-R.
  final List<double> _rollingRrBuffer = [];
  static const int _maxRollingRrCount = 30;

  // Contatori diagnostici obbligatori
  int _packetsReceived = 0;
  int _packetsSaved = 0;
  int _packetsDuplicate = 0;
  int _packetsInvalid = 0;
  int _packetsMissing = 0;

  static TelemetryIngestionService? _instance;
  static TelemetryIngestionService get instance =>
      _instance ??= TelemetryIngestionService();

  static void setMockInstance(TelemetryIngestionService mock) {
    _instance?.dispose();
    _instance = mock;
  }

  TelemetryIngestionService({DatabaseHelper? dbHelper})
      : _dbHelper = dbHelper ?? DatabaseHelper();

  // Getters diagnostici
  int get packetsReceived => _packetsReceived;
  int get packetsSaved => _packetsSaved;
  int get packetsDuplicate => _packetsDuplicate;
  int get packetsInvalid => _packetsInvalid;
  int get packetsMissing => _packetsMissing;
  int? get lastSequenceNumber => _lastSequenceNumber;

  /// Stream broadcast di telemetria validata per la UI, Live Tracker e Motori Biometrici
  Stream<IngestedTelemetry> get telemetryStream => _telemetryController.stream;

  /// Resetta tutti i contatori diagnostici e la finestra di deduplicazione
  void resetDiagnostics() {
    _packetsReceived = 0;
    _packetsSaved = 0;
    _packetsDuplicate = 0;
    _packetsInvalid = 0;
    _packetsMissing = 0;
    _recentPacketHashes.clear();
    _rollingRrBuffer.clear();
    _lastSequenceNumber = null;
  }

  /// Ingerisce ed elabora un pacchetto di byte grezzi attraverso la pipeline rigorosa
  Future<IngestionResult> ingestRawPacket(
    List<int> rawBytes, {
    String source = 'REAL_STREAM',
    String? deviceId,
    String? sessionId,
    DateTime? customTimestamp,
  }) async {
    _packetsReceived++;
    final rxAt = DateTime.now().toUtc();

    if (rawBytes.isEmpty) {
      _packetsInvalid++;
      return IngestionResult.dropped(reason: 'EMPTY_PAYLOAD', isValidCrc: false);
    }

    // ─────────────────────────────────────────────────────────────
    // 1. FRAME & CRC VALIDATION
    // ─────────────────────────────────────────────────────────────
    bool crcValid = true;
    final bool isFramed = rawBytes[0] == 0xAA;
    final bool isWhoop5 = rawBytes.length >= 8 && rawBytes[0] == 0xAA && rawBytes[1] == 0x01;
    final bool is96ByteSensor = rawBytes.length >= 96;

    if (isWhoop5) {
      // Formato WHOOP 5.0 Format-1:
      // Byte 0..5: [0xAA, 0x01, declLenLo, declLenHi, 0x00, 0x01]
      // Byte 6..7: CRC16-Modbus over bytes 0..5 (little-endian)
      final expectedHeaderCrc16 = Crc16Modbus.calculate(rawBytes.sublist(0, 6));
      final actualHeaderCrc16 = rawBytes[6] | (rawBytes[7] << 8);
      if (expectedHeaderCrc16 != actualHeaderCrc16) {
        _packetsInvalid++;
        BleDiagnosticService.instance.recordCrcError(discardedBytesCount: rawBytes.length);
        StructuredLogger.instance.warn(LogTag.ingest, 'WHOOP 5.0 Header CRC16 mismatch');
        return IngestionResult.dropped(reason: 'HEADER_CRC16_MISMATCH', isValidCrc: false);
      }
      final int declLen = rawBytes[2] | (rawBytes[3] << 8);
      final int expectedTotalLen = 8 + declLen;
      if (declLen >= 4 && rawBytes.length >= expectedTotalLen) {
        final int innerLen = declLen - 4;
        final innerBytes = rawBytes.sublist(8, 8 + innerLen);
        final tailCrcOffset = 8 + innerLen;
        final actualTailCrc = (rawBytes[tailCrcOffset] |
                (rawBytes[tailCrcOffset + 1] << 8) |
                (rawBytes[tailCrcOffset + 2] << 16) |
                (rawBytes[tailCrcOffset + 3] << 24)) &
            0xFFFFFFFF;
        final expectedTailCrc = WhoopCrc32.compute(innerBytes);
        if (actualTailCrc != expectedTailCrc) {
          _packetsInvalid++;
          BleDiagnosticService.instance.recordCrcError(discardedBytesCount: rawBytes.length);
          StructuredLogger.instance.warn(LogTag.ingest, 'WHOOP 5.0 Payload CRC32 mismatch');
          return IngestionResult.dropped(reason: 'PAYLOAD_CRC32_MISMATCH', isValidCrc: false);
        }
      }
    } else if (isFramed) {
      if (rawBytes.length < 4) {
        _packetsInvalid++;
        return IngestionResult.dropped(reason: 'TRUNCATED_HEADER', isValidCrc: false);
      }
      final lenLo = rawBytes[1];
      final lenHi = rawBytes[2];
      final headerCrc = rawBytes[3];
      final expectedHeaderCrc = WhoopCrc8.compute([lenLo, lenHi]);
      final int bodyLen = lenLo | (lenHi << 8);
      final int expectedTotalLen = 4 + bodyLen;
      if (headerCrc == expectedHeaderCrc && bodyLen >= 4 && rawBytes.length >= expectedTotalLen) {
        // Verifica CRC-32 di coda (IEEE 802.3 standard sui byte interni)
        final int innerLen = bodyLen - 4;
        final innerBytes = rawBytes.sublist(4, 4 + innerLen);
        final tailCrcOffset = 4 + innerLen;
        final actualTailCrc = (rawBytes[tailCrcOffset] |
                (rawBytes[tailCrcOffset + 1] << 8) |
                (rawBytes[tailCrcOffset + 2] << 16) |
                (rawBytes[tailCrcOffset + 3] << 24)) &
            0xFFFFFFFF;
        final expectedTailCrc = WhoopCrc32.compute(innerBytes);

        if (actualTailCrc != expectedTailCrc) {
          _packetsInvalid++;
          BleDiagnosticService.instance.recordCrcError(discardedBytesCount: rawBytes.length);
          StructuredLogger.instance.warn(LogTag.ingest, 'Payload CRC32 mismatch');
          return IngestionResult.dropped(reason: 'PAYLOAD_CRC32_MISMATCH', isValidCrc: false);
        }
      } else if (rawBytes.length < 20) {
        _packetsInvalid++;
        BleDiagnosticService.instance.recordCrcError(discardedBytesCount: rawBytes.length);
        StructuredLogger.instance.warn(LogTag.ingest, 'Header CRC8 mismatch');
        return IngestionResult.dropped(reason: 'HEADER_CRC8_MISMATCH', isValidCrc: false);
      } else if (rawBytes.length >= 96) {
        final sync = rawBytes[0];
        if (sync != 0xAA && sync != 0x55) {
          _packetsInvalid++;
          BleDiagnosticService.instance.recordDiscardedBytes(rawBytes.length);
          return IngestionResult.dropped(reason: 'INVALID_96BYTE_SYNC_BYTE', isValidCrc: false);
        }
      }
    } else if (is96ByteSensor) {
      final sync = rawBytes[0];
      if (sync != 0xAA && sync != 0x55) {
        _packetsInvalid++;
        BleDiagnosticService.instance.recordDiscardedBytes(rawBytes.length);
        return IngestionResult.dropped(reason: 'INVALID_96BYTE_SYNC_BYTE', isValidCrc: false);
      }
    }

    // ─────────────────────────────────────────────────────────────
    // 2. DEDUPLICATION (Sliding hash window)
    // ─────────────────────────────────────────────────────────────
    final packetHash = _computePacketHash(rawBytes);
    if (_recentPacketHashes.contains(packetHash)) {
      _packetsDuplicate++;
      return IngestionResult.dropped(reason: 'DUPLICATE_PACKET', isDuplicate: true);
    }
    _addPacketHash(packetHash);

    // ─────────────────────────────────────────────────────────────
    // 3. SEQUENCE TRACKING & GAP DETECTION
    // ─────────────────────────────────────────────────────────────
    int? seqNum;
    int? detectedGap;

    if (rawBytes.length >= 4) {
      if (isWhoop5 && rawBytes.length >= 10) {
        seqNum = rawBytes[9];
      } else if (isFramed && rawBytes.length >= 6) {
        // Frame Whoop: byte 4 è type, byte 5 è seq uint8 (oppure uint16 al byte 2 se 96byte)
        if (rawBytes.length >= 96) {
          final bd = ByteData.sublistView(Uint8List.fromList(rawBytes));
          seqNum = bd.getUint16(2, Endian.little);
        } else {
          seqNum = rawBytes[5];
        }
      } else if (rawBytes.length >= 2) {
        final bd = ByteData.sublistView(Uint8List.fromList(rawBytes));
        seqNum = bd.getUint16(0, Endian.little);
      }

      if (seqNum != null && _lastSequenceNumber != null) {
        final int expected = (_lastSequenceNumber! + 1) % _maxSeq16Bit;
        if (seqNum != expected) {
          final int gap = (seqNum - expected) % _maxSeq16Bit;
          if (gap > 0 && gap < 2000) {
            detectedGap = gap;
            _packetsMissing += gap;
            debugPrint('[TelemetryIngestionService] GAP RILEVATO: atteso $expected, ricevuto $seqNum (saltati $gap pacchetti)');
          }
        }
      }
      if (seqNum != null) {
        _lastSequenceNumber = seqNum;
      }
    }

    // ─────────────────────────────────────────────────────────────
    // 4. DECODE METRICS (Whoop 96-byte o Custom Packet)
    // ─────────────────────────────────────────────────────────────
    DateTime deviceTs = customTimestamp ?? rxAt;
    int? bpm;
    double? rmssdMs;
    double? rrMs;
    String? rrIntervalsJson;
    double? accelEnmo;
    double? motionVar;
    double? skinTempC;
    int? skinTempRaw;
    double? spo2Pct;
    double? spo2RatioR;
    double? respRate;
    double? respPower;

    if (rawBytes.length >= 20) {
      final packet96 = Whoop96BytePacket.fromBytes(rawBytes);
      deviceTs = packet96.timestamp;
      bpm = packet96.heartRateBpm > 0 ? packet96.heartRateBpm : null;
      rmssdMs = packet96.hrvRmssdMs > 0 ? packet96.hrvRmssdMs : null;
      if (packet96.rrIntervalsMs.isNotEmpty) {
        final validRr = packet96.rrIntervalsMs.where((r) => r >= 300.0 && r <= 2000.0).toList();
        if (validRr.isNotEmpty) {
          rrMs = validRr.last;
          rrIntervalsJson = jsonEncode(packet96.rrIntervalsMs);
          for (final rr in validRr) {
            _rollingRrBuffer.add(rr);
            if (_rollingRrBuffer.length > _maxRollingRrCount) {
              _rollingRrBuffer.removeAt(0);
            }
          }
        }
      }
      accelEnmo = packet96.enmo;
      motionVar = packet96.motionVariance;
      skinTempRaw = packet96.skinTempRaw;
      skinTempC = packet96.skinTempCelsius;
      spo2Pct = packet96.spo2Pct;
      spo2RatioR = packet96.spo2Ratio > 0 ? packet96.spo2Ratio : null;
      respRate = packet96.respiratoryRate > 0 ? packet96.respiratoryRate : null;
      respPower = packet96.respiratoryPower > 0 ? packet96.respiratoryPower : null;
    } else if (isFramed) {
      if (rawBytes.length >= 7) {
        final potentialBpm = rawBytes[6];
        if (potentialBpm >= 30 && potentialBpm <= 250) {
          bpm = potentialBpm;
        }
      }
      if (bpm == null && rawBytes.length > 4 && rawBytes[4] >= 30 && rawBytes[4] <= 250) {
        bpm = rawBytes[4];
      }
    } else {
      // Standard BLE Heart Rate (0x2A37) or compact frame
      if (rawBytes.length >= 2) {
        final hrPacket = HrDataPacket.fromBytes(rawBytes);
        bpm = hrPacket.bpm > 0 ? hrPacket.bpm : null;
        if (hrPacket.rrIntervalsMs.isNotEmpty) {
          rrIntervalsJson = jsonEncode(hrPacket.rrIntervalsMs);
          final validRr = hrPacket.rrIntervalsMs.where((r) => r >= 300.0 && r <= 2000.0).toList();
          if (validRr.isNotEmpty) {
            rrMs = validRr.last;
            for (final rr in validRr) {
              _rollingRrBuffer.add(rr);
              if (_rollingRrBuffer.length > _maxRollingRrCount) {
                _rollingRrBuffer.removeAt(0);
              }
            }
          }
        }
        if (bpm == null || bpm <= 0) {
          final fallbackBpm = rawBytes[rawBytes.length > 4 ? 4 : 1];
          if (fallbackBpm >= 30 && fallbackBpm <= 250) bpm = fallbackBpm;
        }
      }
    }

    // Calcolo RMSSD continuo da rolling RR buffer se non fornito direttamente dal frame proprietario
    if ((rmssdMs == null || rmssdMs <= 0.0) && _rollingRrBuffer.length >= 2) {
      double sumDiffSq = 0.0;
      int count = 0;
      for (int i = 0; i < _rollingRrBuffer.length - 1; i++) {
        final diff = (_rollingRrBuffer[i + 1] - _rollingRrBuffer[i]).abs();
        if (diff <= 200.0) { // Ectopic rejection filter
          sumDiffSq += diff * diff;
          count++;
        }
      }
      if (count >= 1) {
        rmssdMs = math.sqrt(sumDiffSq / count);
      }
    }

    // ─────────────────────────────────────────────────────────────
    // 5. PHYSIOLOGICAL RANGE FILTERING
    // ─────────────────────────────────────────────────────────────
    bool isValidPhysiology = true;
    String quality = 'VALID';

    if (bpm != null) {
      if (bpm < 30 || bpm > 250) {
        isValidPhysiology = false;
        quality = 'INVALID';
        _packetsInvalid++;
      }
    }

    // Filtro rMSSD fisiologico [5..300 ms]
    if (rmssdMs != null && (rmssdMs < 5.0 || rmssdMs > 300.0)) {
      rmssdMs = null;
      quality = 'LOW_CONFIDENCE';
    }

    // Filtro R-R interval fisiologico [300..2000 ms]
    if (rrMs != null && (rrMs < 300.0 || rrMs > 2000.0)) {
      rrMs = null;
    }

    // Filtro SpO2 [70..100%]
    if (spo2Pct != null && (spo2Pct < 70.0 || spo2Pct > 100.0)) {
      spo2Pct = null;
    }

    // Filtro Skin Temp [25..45 °C]
    if (skinTempC != null && (skinTempC < 25.0 || skinTempC > 45.0)) {
      skinTempC = null;
    }

    // Filtro Frequenza Respiratoria [6..40 rpm]
    if (respRate != null && (respRate < 6.0 || respRate > 40.0)) {
      respRate = null;
    }

    // ─────────────────────────────────────────────────────────────
    // 6. PERSISTENCE TO SQLITE (Schema v15)
    // ─────────────────────────────────────────────────────────────
    final latencyMs = rxAt.difference(deviceTs.toUtc()).inMilliseconds.abs();

    int? insertedId;
    try {
      insertedId = await _dbHelper.insertTelemetriaPoint(
        bpm: bpm,
        rmssdMs: rmssdMs,
        rrMs: rrMs,
        rrIntervalsJson: rrIntervalsJson,
        motionVar: motionVar,
        accelEnmo: accelEnmo,
        skinTempCelsius: skinTempC,
        skinTempRaw: skinTempRaw,
        spo2Pct: spo2Pct,
        spo2RatioR: spo2RatioR,
        respRate: respRate,
        respPower: respPower,
        timestamp: deviceTs,
        timestampUtcMs: deviceTs.toUtc().millisecondsSinceEpoch,
        deviceId: deviceId,
        sessionId: sessionId,
        sequenceNumber: seqNum,
        packetType: is96ByteSensor ? 'WHOOP_96BYTE' : (isFramed ? 'WHOOP_FRAMED' : 'WHOOP_COMPACT'),
        rawPayload: rawBytes,
        decoderVersion: '1.0.0-v15',
        crcValid: crcValid,
        isValid: isValidPhysiology,
        receivedAt: rxAt,
        deviceTimestamp: deviceTs,
        ingestLatencyMs: latencyMs,
        duplicate: false,
        source: source,
        quality: quality,
      );
      _packetsSaved++;
      BleDiagnosticService.instance.recordDatabaseInsert();
      StructuredLogger.instance.debug(
        LogTag.db,
        'Inserito record telemetria_grezza id=$insertedId (seq=$seqNum)',
      );
    } catch (e) {
      debugPrint('[TelemetryIngestionService] Errore inserimento SQLite: $e');
      StructuredLogger.instance.error(
        LogTag.db,
        'Errore inserimento telemetria_grezza: $e',
      );
      return IngestionResult.dropped(reason: 'DB_COMMIT_FAILED: $e');
    }

    // ─────────────────────────────────────────────────────────────
    // 7. EMISSION TO STREAM
    // ─────────────────────────────────────────────────────────────
    final ingested = IngestedTelemetry(
      id: insertedId,
      timestamp: deviceTs,
      sequenceNumber: seqNum,
      source: source,
      quality: quality,
      isValid: isValidPhysiology,
      bpm: bpm,
      rmssdMs: rmssdMs,
      rrMs: rrMs,
      rrIntervalsJson: rrIntervalsJson,
      accelEnmo: accelEnmo,
      motionVar: motionVar,
      skinTempCelsius: skinTempC,
      spo2Pct: spo2Pct,
      respRate: respRate,
      respPower: respPower,
      latencyMs: latencyMs,
      rawBytes: rawBytes,
    );

    if (!_telemetryController.isClosed) {
      _telemetryController.add(ingested);
    }

    return IngestionResult.success(ingested, missingGap: detectedGap);
  }

  /// Ingestione atomica di un batch di frame (Store-and-Forward da flash memory)
  Future<BatchIngestionResult> ingestBatch(
    List<List<int>> batchBytes, {
    String source = 'STORE_FORWARD',
    String? deviceId,
    String? sessionId,
  }) async {
    int saved = 0;
    int duplicates = 0;
    int invalid = 0;
    int gaps = 0;

    for (final bytes in batchBytes) {
      final res = await ingestRawPacket(
        bytes,
        source: source,
        deviceId: deviceId,
        sessionId: sessionId,
      );
      if (res.accepted) {
        saved++;
        if (res.missingGap != null && res.missingGap! > 0) {
          gaps += res.missingGap!;
        }
      } else {
        if (res.isDuplicate) {
          duplicates++;
        } else {
          invalid++;
        }
      }
    }

    return BatchIngestionResult(
      totalReceived: batchBytes.length,
      saved: saved,
      duplicates: duplicates,
      invalid: invalid,
      gapsDetected: gaps,
    );
  }

  int _computePacketHash(List<int> bytes) {
    // Escludiamo il trailing CRC-32 (se presente su frame 0xAA) per evitare la convergenza del residuo ciclico costante
    final hashBytes = (bytes.length > 4 && bytes[0] == 0xAA)
        ? bytes.sublist(0, bytes.length - 4)
        : bytes;
    int h = 0x811c9dc5; // FNV-1a 32-bit offset basis
    for (final b in hashBytes) {
      h ^= (b & 0xFF);
      h = (h * 0x01000193) & 0xFFFFFFFF; // FNV-1a 32-bit prime
    }
    return h;
  }

  void _addPacketHash(int hash) {
    _recentPacketHashes.add(hash);
    if (_recentPacketHashes.length > _dedupWindowSize) {
      _recentPacketHashes.removeAt(0);
    }
  }

  void dispose() {
    _telemetryController.close();
  }
}
