import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../core/logging/structured_logger.dart';
import '../models/telemetry_sample.dart';
import 'noop_protocol_decoder.dart';
import 'whoop_96byte_packet.dart';

enum FrameType {
  framedCommand,
  framedTelemetry,
  flat96ByteSensor,
  hrServiceStandard,
}

/// Rappresentazione tipizzata di un frame grezzo validato (Fase 3: BLE-07, PRO-01)
@immutable
class WhoopFrame {
  final FrameType type;
  final int? sequenceNumber;
  final int? commandOpcode;
  final List<int> payload;
  final List<int> rawBytes;
  final bool isCrcValid;
  final DateTime timestamp;

  const WhoopFrame({
    required this.type,
    this.sequenceNumber,
    this.commandOpcode,
    required this.payload,
    required this.rawBytes,
    this.isCrcValid = true,
    required this.timestamp,
  });

  /// Converte il frame in un TelemetrySample tipizzato con campi nullable
  TelemetrySample toTelemetrySample({TelemetrySource source = TelemetrySource.strapRealtime}) {
    if (type == FrameType.flat96ByteSensor && rawBytes.length >= 96) {
      final p96 = Whoop96BytePacket.fromBytes(rawBytes);
      return TelemetrySample(
        timestamp: p96.timestamp,
        hr: p96.heartRateBpm > 0 ? p96.heartRateBpm : null,
        rrIntervalsMs: const [],
        accelX: p96.accelX != 0.0 ? p96.accelX : null,
        accelY: p96.accelY != 0.0 ? p96.accelY : null,
        accelZ: p96.accelZ != 0.0 ? p96.accelZ : null,
        skinTempCelsius: p96.skinTempRaw > 0 ? (p96.skinTempRaw * 0.0078125) : null,
        spo2Ratio: p96.spo2Ratio > 0.0 ? p96.spo2Ratio : null,
        respiratoryRate: p96.respiratoryRate > 0.0 ? p96.respiratoryRate : null,
        sequenceNumber: p96.sequenceNumber,
        source: source,
      );
    }

    // Se il frame è di tipo framedCommand/telemetry (Opcode 0x16, ecc.)
    int? hr;
    double? temp;
    double? spo2;
    int? seq = sequenceNumber;

    if (payload.length >= 4) {
      // Offset documentati in docs/PROTOCOL.md: [type, seq, cmd, hr, ...]
      hr = payload[3] > 0 && payload[3] < 255 ? payload[3] : null;
    }

    return TelemetrySample(
      timestamp: timestamp,
      hr: hr,
      sequenceNumber: seq,
      skinTempCelsius: temp,
      spo2Ratio: spo2,
      source: source,
    );
  }
}

/// Accumulatore e parser di stream a pacchetti BLE per WHOOP (Fase 3: 3.1)
/// Gestisce riassemblaggio MTU, validazione CRC-8 / CRC-32 e decodifica deterministica.
class FrameStreamParser {
  final List<int> _buffer = [];
  final StreamController<WhoopFrame> _frameController = StreamController<WhoopFrame>.broadcast();
  final StreamController<TelemetrySample> _sampleController = StreamController<TelemetrySample>.broadcast();

  int _crcErrors = 0;
  int _bytesDiscarded = 0;
  int _framesDecoded = 0;
  int _fragmentsReassembled = 0;

  int get crcErrors => _crcErrors;
  int get bytesDiscarded => _bytesDiscarded;
  int get framesDecoded => _framesDecoded;
  int get fragmentsReassembled => _fragmentsReassembled;

  Stream<WhoopFrame> get frameStream => _frameController.stream;
  Stream<TelemetrySample> get sampleStream => _sampleController.stream;

  /// Aggiunge un frammento o pacchetto grezzo ricevuto dalla caratteristica BLE
  void addChunk(List<int> chunk, {DateTime? rxTimestamp}) {
    if (chunk.isEmpty) return;
    final now = rxTimestamp ?? DateTime.now().toUtc();

    // Caso speciale: se il chunk è esattamente 96 byte e non ha l'header framed CRC-8 valido,
    // è un frame sensore flat a 96 byte ad alta frequenza (WHOOP 4.0 / 5.0)
    if (chunk.length == 96 && !_isValidFramedHeader(chunk)) {
      final frame = WhoopFrame(
        type: FrameType.flat96ByteSensor,
        payload: chunk,
        rawBytes: chunk,
        isCrcValid: true,
        timestamp: now,
      );
      _framesDecoded++;
      _frameController.add(frame);
      _sampleController.add(frame.toTelemetrySample(source: TelemetrySource.strapRealtime));
      return;
    }

    _buffer.addAll(chunk);
    _processBuffer(now);
  }

  bool _isValidFramedHeader(List<int> bytes) {
    if (bytes.length < 4 || bytes[0] != 0xAA) return false;
    final lenLo = bytes[1];
    final lenHi = bytes[2];
    final expectedCrc8 = bytes[3];
    return WhoopCrc8.verify([lenLo, lenHi], expectedCrc8);
  }

  void _processBuffer(DateTime now) {
    while (_buffer.isNotEmpty) {
      // 1. Cerca il primo byte di sync 0xAA
      final syncIdx = _buffer.indexOf(0xAA);
      if (syncIdx == -1) {
        // Nessun marker trovato, tutti i byte nel buffer sono rumore o scartati
        _bytesDiscarded += _buffer.length;
        _buffer.clear();
        break;
      }

      if (syncIdx > 0) {
        // Scarta i byte prima di 0xAA
        _bytesDiscarded += syncIdx;
        _buffer.removeRange(0, syncIdx);
      }

      // Servono almeno 4 byte per l'header [0xAA, lenLo, lenHi, crc8]
      if (_buffer.length < 4) {
        _fragmentsReassembled++;
        break; // Attendi il prossimo frammento MTU
      }

      final lenLo = _buffer[1];
      final lenHi = _buffer[2];
      final crc8Header = _buffer[3];

      final isCrc8Valid = WhoopCrc8.verify([lenLo, lenHi], crc8Header);
      if (!isCrc8Valid) {
        // Falso allarme 0xAA: scarta il singolo byte 0xAA e riprova
        _bytesDiscarded++;
        _buffer.removeAt(0);
        continue;
      }

      final declaredLen = lenLo | (lenHi << 8);
      // Lunghezza totale = 4 byte (header) + declaredLen + 4 byte (CRC-32)
      final totalFrameLen = 4 + declaredLen + 4;

      if (_buffer.length < totalFrameLen) {
        // Il frame è frammentato su più notifiche MTU: attendi i byte mancanti
        _fragmentsReassembled++;
        break;
      }

      // Abbiamo il frame completo
      final fullFrame = _buffer.sublist(0, totalFrameLen);
      final innerPayload = fullFrame.sublist(4, 4 + declaredLen);

      final tailCrc32 = (fullFrame[totalFrameLen - 4] & 0xFF) |
          ((fullFrame[totalFrameLen - 3] & 0xFF) << 8) |
          ((fullFrame[totalFrameLen - 2] & 0xFF) << 16) |
          ((fullFrame[totalFrameLen - 1] & 0xFF) << 24);

      final calculatedCrc32 = WhoopCrc32.compute(innerPayload);
      final calculatedLegacy = WhoopCrc32.computeLegacy(innerPayload);

      final isCrc32Valid = (calculatedCrc32 == tailCrc32) || (calculatedLegacy == tailCrc32);

      if (!isCrc32Valid) {
        _crcErrors++;
        StructuredLogger.instance.warning(
          'BLE',
          'FrameStreamParser: CRC-32 mismatch su frame len $declaredLen (tail: 0x${tailCrc32.toRadixString(16)}, atteso: 0x${calculatedCrc32.toRadixString(16)})',
        );
        // Scarta il marker 0xAA corrotto e riprendi la ricerca
        _buffer.removeAt(0);
        continue;
      }

      // Frame valido al 100%!
      int? seq;
      int? cmd;
      if (innerPayload.length >= 3) {
        seq = innerPayload[1];
        cmd = innerPayload[2];
      }

      final whoopFrame = WhoopFrame(
        type: FrameType.framedCommand,
        sequenceNumber: seq,
        commandOpcode: cmd,
        payload: innerPayload,
        rawBytes: fullFrame,
        isCrcValid: true,
        timestamp: now,
      );

      _framesDecoded++;
      _frameController.add(whoopFrame);
      _sampleController.add(whoopFrame.toTelemetrySample(source: TelemetrySource.strapRealtime));

      // Rimuovi il frame consumato dal buffer
      _buffer.removeRange(0, totalFrameLen);
    }
  }

  void dispose() {
    _frameController.close();
    _sampleController.close();
  }
}
