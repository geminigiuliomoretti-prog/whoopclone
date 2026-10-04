import 'package:flutter/foundation.dart';

/// Parser per la caratteristica GATT standard Heart Rate Measurement (`0x2A37`)
/// Service `0x180D`. Estrae BPM live e intervalli R-R in millisecondi (ms).
@immutable
class HrDataPacket {
  final int bpm;
  final List<double> rrIntervalsMs;
  final bool sensorContact;
  final int? energyExpendedJoules;
  final DateTime timestamp;

  HrDataPacket({
    required this.bpm,
    required this.rrIntervalsMs,
    this.sensorContact = true,
    this.energyExpendedJoules,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Deserializzazione da byte array grezzo inviato via BLE dal servizio 0x2A37
  factory HrDataPacket.fromBytes(List<int> bytes) {
    if (bytes.isEmpty) {
      return HrDataPacket(bpm: 0, rrIntervalsMs: []);
    }

    final flags = bytes[0];
    final is16BitBpm = (flags & 0x01) != 0;
    final sensorContactSupported = (flags & 0x04) != 0;
    final sensorContactDetected = (flags & 0x02) != 0;
    final energyExpendedPresent = (flags & 0x08) != 0;
    final rrIntervalPresent = (flags & 0x10) != 0;

    int offset = 1;

    // Estrazione BPM (UINT8 vs UINT16)
    int bpm = 0;
    if (is16BitBpm) {
      if (bytes.length >= offset + 2) {
        bpm = bytes[offset] | (bytes[offset + 1] << 8);
        offset += 2;
      }
    } else {
      if (bytes.length >= offset + 1) {
        bpm = bytes[offset];
        offset += 1;
      }
    }

    int? energyExpended;
    if (energyExpendedPresent && bytes.length >= offset + 2) {
      energyExpended = bytes[offset] | (bytes[offset + 1] << 8);
      offset += 2;
    }

    final List<double> rrList = [];
    if (rrIntervalPresent) {
      while (bytes.length >= offset + 2) {
        final rawRr = bytes[offset] | (bytes[offset + 1] << 8);
        // Negli standard BLE GATT, l'intervallo R-R è espresso in unità di 1/1024 secondi.
        // Conversione in ms: (rawRr / 1024.0) * 1000.0
        final rrMs = (rawRr / 1024.0) * 1000.0;
        rrList.add(rrMs);
        offset += 2;
      }
    }

    return HrDataPacket(
      bpm: bpm,
      rrIntervalsMs: rrList,
      sensorContact: !sensorContactSupported || sensorContactDetected,
      energyExpendedJoules: energyExpended,
    );
  }

  @override
  String toString() {
    return 'HrDataPacket(bpm: $bpm, rrMs: $rrIntervalsMs, sensorContact: $sensorContact)';
  }
}
