import 'package:flutter/foundation.dart';

/// Interfaccia Clock per rendere iniettabile la gestione temporale e del fuso orario nell'intera app.
abstract class Clock {
  const Clock();

  static Clock _current = const SystemClock();

  /// Istanza corrente di Clock attiva nell'applicazione.
  static Clock get current => _current;

  /// Permette di iniettare un'istanza alternativa di Clock (es. TestClock).
  static set current(Clock clock) {
    _current = clock;
  }

  /// Imposta un'istanza di Clock
  static void setClock(Clock clock) {
    _current = clock;
  }

  /// Reimposta Clock all'orologio di sistema (SystemClock).
  static void reset() {
    _current = const SystemClock();
  }

  /// Restituisce l'orario corrente.
  DateTime now();

  /// Restituisce l'orario corrente in formato UTC.
  DateTime nowUtc() => now().toUtc();

  /// Restituisce l'offset di fuso orario corrente.
  Duration get timeZoneOffset => now().timeZoneOffset;

  /// Restituisce il fuso orario formattato dinamico (es: '+02:00', '+01:00', '-05:00').
  String get formattedTimeZoneOffset => formatOffset(timeZoneOffset);

  /// Utility per formattare una Duration di offset in formato standard ISO "+HH:mm" o "-HH:mm".
  static String formatOffset(Duration offset) {
    final sign = offset.isNegative ? '-' : '+';
    final totalMinutes = offset.inMinutes.abs();
    final hours = (totalMinutes ~/ 60).toString().padLeft(2, '0');
    final minutes = (totalMinutes % 60).toString().padLeft(2, '0');
    return '$sign$hours:$minutes';
  }
}

/// Implementazione standard di Clock basata sull'orologio di sistema del dispositivo.
class SystemClock extends Clock {
  const SystemClock();

  @override
  DateTime now() => DateTime.now();

  @override
  Duration get timeZoneOffset => DateTime.now().timeZoneOffset;

  @override
  String get formattedTimeZoneOffset => Clock.formatOffset(timeZoneOffset);
}

/// Implementazione configurabile di Clock per test deterministici su fusi orari,
/// passaggi ora solare/legale e scorrimento temporale.
class TestClock extends Clock {
  DateTime _currentTime;
  Duration? _customOffset;

  TestClock(DateTime initialTime, {Duration? timeZoneOffset})
      : _currentTime = initialTime,
        _customOffset = timeZoneOffset;

  @override
  DateTime now() => _currentTime;

  @override
  Duration get timeZoneOffset => _customOffset ?? _currentTime.timeZoneOffset;

  @override
  String get formattedTimeZoneOffset => Clock.formatOffset(timeZoneOffset);

  /// Imposta un orario specifico
  void setTime(DateTime newTime) {
    _currentTime = newTime;
  }

  /// Fa avanzare il tempo
  void advance(Duration duration) {
    _currentTime = _currentTime.add(duration);
  }

  /// Imposta un fuso orario specifico
  void setTimeZoneOffset(Duration offset) {
    _customOffset = offset;
  }
}

/// Accesso rapido globale a Clock
Clock get appClock => Clock.current;
set appClock(Clock c) => Clock.current = c;

/// Calcola il fuso orario dinamico attuale (o a partire da un offset fornito).
String getDynamicTimeZoneOffset([Duration? offset]) {
  return Clock.formatOffset(offset ?? Clock.current.timeZoneOffset);
}
