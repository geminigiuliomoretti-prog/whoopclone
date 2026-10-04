import 'dart:math';

/// Buffer circolare (FIFO Queue) per la memorizzazione e lo streaming
/// continuo degli intervalli R-R in ms. Previene la perdita di dati
/// durante micro-disconnessioni BLE e fornisce metriche HRV live.
class RRCircularBuffer {
  final int capacity;
  final List<double> _buffer = [];

  RRCircularBuffer({this.capacity = 500});

  /// Aggiunge un singolo intervallo R-R in millisecondi (filtrando valori non fisiologici)
  void add(double rrMs) {
    // Intervallo cardiaco umano fisiologico: tra 300 ms (200 bpm) e 1500 ms (40 bpm)
    if (rrMs < 300.0 || rrMs > 1500.0) return;
    if (_buffer.length >= capacity) {
      _buffer.removeAt(0);
    }
    _buffer.add(rrMs);
  }

  /// Aggiunge una lista di intervalli R-R in millisecondi
  void addAll(Iterable<double> rrList) {
    for (final val in rrList) {
      add(val);
    }
  }

  /// Svuota il buffer
  void clear() {
    _buffer.clear();
  }

  /// Restituisce tutti gli elementi presenti nel buffer
  List<double> get samples => List.unmodifiable(_buffer);

  int get length => _buffer.length;
  bool get isEmpty => _buffer.isEmpty;

  /// Restituisce gli ultimi N campioni R-R
  List<double> getLastNSamples(int n) {
    if (n >= _buffer.length) return List.from(_buffer);
    return _buffer.sublist(_buffer.length - n);
  }

  /// Calcola la media R-R in ms
  double get meanRrMs {
    if (_buffer.isEmpty) return 0.0;
    final sum = _buffer.reduce((a, b) => a + b);
    return sum / _buffer.length;
  }

  /// Calcola l'rMSSD in ms per la VFC con rigetto dei salti ectopici (>250ms)
  double get rmssdMs {
    if (_buffer.length < 2) return 0.0;
    double sumSuccessiveDiffSq = 0.0;
    int count = 0;
    for (int i = 0; i < _buffer.length - 1; i++) {
      final diff = (_buffer[i + 1] - _buffer[i]).abs();
      // Scarta artefatti da scatto improvviso o battiti ectopici
      if (diff <= 250.0) {
        sumSuccessiveDiffSq += diff * diff;
        count++;
      }
    }
    if (count == 0) return 0.0;
    final meanSq = sumSuccessiveDiffSq / count;
    return sqrt(meanSq);
  }
}
