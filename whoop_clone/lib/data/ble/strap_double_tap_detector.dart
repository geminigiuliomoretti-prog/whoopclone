import 'dart:math' as math;
import 'dart:typed_data';
import 'whoop_96byte_packet.dart';

/// Rilevatore affidabile del Doppio Tocco (Double-Tap) sul cinturino WHOOP
/// Riconosce il doppio tocco sia tramite eventi hardware su caratteristica 0004 (EVENTS_FROM_STRAP),
/// sia tramite firma accelerometrica nei pacchetti telemetrici 96-byte (impulsi ENMO / Jerk triassiale).
class StrapDoubleTapDetector {
  DateTime? _firstTapTime;
  double _lastMagnitude = 1.0;

  /// Finestra temporale minima tra due tocchi (filtro anti-rimbalzo meccanico)
  static const int minInterTapIntervalMs = 150;

  /// Finestra temporale massima tra primo e secondo tocco per considerare un double-tap valido
  static const int maxInterTapIntervalMs = 1500;

  /// Soglia jerk di accelerazione in g per considerare un campione come picco di impatto/tocco
  static const double tapJerkThresholdG = 0.30;

  /// Soglia ENMO dinamica in g
  static const double tapEnmoThresholdG = 0.40;

  /// Elabora un pacchetto telemetrico da 96 byte e restituisce true se rileva un doppio tocco
  bool processPacket(Whoop96BytePacket packet) {
    if (!packet.isValid) return false;
    return processSample(
      ax: packet.accelX,
      ay: packet.accelY,
      az: packet.accelZ,
      enmo: packet.motionVariance,
      timestamp: packet.timestamp,
    );
  }

  /// Elabora un campione accelerometrico grezzo
  bool processSample({
    required double ax,
    required double ay,
    required double az,
    required double enmo,
    DateTime? timestamp,
  }) {
    final now = timestamp ?? DateTime.now();

    double mag = 1.0;
    if (ax != 0.0 || ay != 0.0 || az != 0.0) {
      mag = math.sqrt(ax * ax + ay * ay + az * az);
    } else {
      mag = 1.0 + enmo;
    }

    final delta = (mag - _lastMagnitude).abs();
    _lastMagnitude = mag;

    final isTapCandidate = delta >= tapJerkThresholdG || enmo >= tapEnmoThresholdG;

    if (isTapCandidate) {
      if (_firstTapTime == null) {
        _firstTapTime = now;
      } else {
        final diffMs = now.difference(_firstTapTime!).inMilliseconds;
        if (diffMs >= minInterTapIntervalMs && diffMs <= maxInterTapIntervalMs) {
          // Secondo tocco rilevato entro la finestra valida: Double-Tap confermato!
          _firstTapTime = null;
          return true;
        } else if (diffMs > maxInterTapIntervalMs) {
          // Finestra scaduta: questo tocco diventa il nuovo primo tocco
          _firstTapTime = now;
        }
      }
    } else {
      if (_firstTapTime != null && now.difference(_firstTapTime!).inMilliseconds > maxInterTapIntervalMs) {
        _firstTapTime = null;
      }
    }

    return false;
  }

  /// Elabora un frame di evento proveniente dalla caratteristica 0004 (EVENTS_FROM_STRAP)
  /// Sul cinturino WHOOP 4.0 / 5.0, un doppio tocco genera un interrupt LIS2DW12/BMI270
  /// che invia immediatamente una notifica di evento.
  bool processStrapEvent(Uint8List eventBytes) {
    if (eventBytes.isEmpty) return false;
    // Qualsiasi notifica di evento ricevuta sul canale 0004 è un'interazione fisica sul cinturino
    return true;
  }

  /// Resetta lo stato interno del rilevatore
  void reset() {
    _firstTapTime = null;
    _lastMagnitude = 1.0;
  }
}
