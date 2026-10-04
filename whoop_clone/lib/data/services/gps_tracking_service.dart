import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../database/database_helper.dart';

/// Servizio di Tracciamento GPS Reale con Geolocator & Esportazione GPX
class GpsTrackingService extends ChangeNotifier {
  final DatabaseHelper _dbHelper;
  StreamSubscription<Position>? _positionSubscription;

  bool _isTracking = false;
  double _totalDistanceMeters = 0.0;
  double _currentSpeedKmh = 0.0;
  double _elevationGainMeters = 0.0;
  DateTime? _startTime;

  Position? _lastPosition;
  final List<Map<String, dynamic>> _routePoints = [];

  GpsTrackingService({DatabaseHelper? dbHelper})
      : _dbHelper = dbHelper ?? DatabaseHelper();

  bool get isTracking => _isTracking;
  double get totalDistanceMeters => _totalDistanceMeters;
  double get totalDistanceKm => _totalDistanceMeters / 1000.0;
  double get currentSpeedKmh => _currentSpeedKmh;
  double get elevationGainMeters => _elevationGainMeters;
  List<Map<String, dynamic>> get routePoints => List.unmodifiable(_routePoints);

  double get averagePaceMinKm {
    if (_totalDistanceMeters <= 5 || _startTime == null) return 0.0;
    final elapsedSec = DateTime.now().difference(_startTime!).inSeconds;
    final km = _totalDistanceMeters / 1000.0;
    return (elapsedSec / 60.0) / km;
  }

  String get formattedAveragePace {
    final pace = averagePaceMinKm;
    if (pace <= 0 || pace.isInfinite || pace.isNaN) return "--'--\"";
    final min = pace.floor();
    final sec = ((pace - min) * 60).round();
    return "$min'${sec.toString().padLeft(2, '0')}\"";
  }

  /// Calcola la distanza cumulativa Haversine in metri fra una lista di coordinate GPS
  static double calculateCumulativeDistanceMeters(List<Map<String, dynamic>> points) {
    if (points.length < 2) return 0.0;
    double totalMeters = 0.0;

    for (int i = 0; i < points.length - 1; i++) {
      final lat1 = (points[i]['latitude'] ?? points[i]['lat']) as double;
      final lon1 = (points[i]['longitude'] ?? points[i]['lon']) as double;
      final lat2 = (points[i + 1]['latitude'] ?? points[i + 1]['lat']) as double;
      final lon2 = (points[i + 1]['longitude'] ?? points[i + 1]['lon']) as double;

      totalMeters += Geolocator.distanceBetween(lat1, lon1, lat2, lon2);
    }
    return totalMeters;
  }

  /// Genera un file/stringa XML GPX v1.1 standard dai punti della traccia
  static String generateGpxString(List<Map<String, dynamic>> points, String activityName) {
    final buffer = StringBuffer();
    buffer.writeln('<?xml version="1.0" encoding="UTF-8"?>');
    buffer.writeln('<gpx version="1.1" creator="WHOOP 5.0 Clone" xmlns="http://www.topografix.com/GPX/1/1">');
    buffer.writeln('  <metadata>');
    buffer.writeln('    <name>${activityName.replaceAll('&', '&amp;')}</name>');
    buffer.writeln('    <time>${DateTime.now().toUtc().toIso8601String()}</time>');
    buffer.writeln('  </metadata>');
    buffer.writeln('  <trk>');
    buffer.writeln('    <name>${activityName.replaceAll('&', '&amp;')}</name>');
    buffer.writeln('    <trkseg>');

    for (final pt in points) {
      final lat = (pt['latitude'] ?? pt['lat'] ?? 0.0) as double;
      final lon = (pt['longitude'] ?? pt['lon'] ?? 0.0) as double;
      final ele = (pt['altitude'] ?? pt['ele'] ?? 0.0) as double;
      final time = (pt['timestamp'] ?? DateTime.now().toIso8601String()) as String;

      buffer.writeln('      <trkpt lat="$lat" lon="$lon">');
      buffer.writeln('        <ele>$ele</ele>');
      buffer.writeln('        <time>$time</time>');
      buffer.writeln('      </trkpt>');
    }

    buffer.writeln('    </trkseg>');
    buffer.writeln('  </trk>');
    buffer.writeln('</gpx>');

    return buffer.toString();
  }

  /// Verificare ed accedere ai permessi di localizzazione hardware
  Future<bool> checkAndRequestPermissions() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      debugPrint('GpsTrackingService: Servizio GPS disabilitato sul dispositivo');
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        debugPrint('GpsTrackingService: Permesso GPS negato dall\'utente');
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      debugPrint('GpsTrackingService: Permesso GPS negato permanentemente');
      return false;
    }

    return true;
  }

  /// Avvia il tracciamento GPS in tempo reale per un'attività outdoor
  Future<bool> startTracking() async {
    final hasPerm = await checkAndRequestPermissions();
    if (!hasPerm) return false;

    _isTracking = true;
    _totalDistanceMeters = 0.0;
    _currentSpeedKmh = 0.0;
    _elevationGainMeters = 0.0;
    _lastPosition = null;
    _routePoints.clear();
    _startTime = DateTime.now();

    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 3, // Aggiorna ogni 3 metri
    );

    try {
      _positionSubscription = Geolocator.getPositionStream(locationSettings: locationSettings).listen(
        (Position position) {
          _onNewPosition(position);
        },
        onError: (err) {
          debugPrint('GpsTrackingService Error: $err');
        },
      );
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('GpsTrackingService Exception: $e');
      _isTracking = false;
      return false;
    }
  }

  void _onNewPosition(Position position) {
    if (_lastPosition != null) {
      final deltaDist = Geolocator.distanceBetween(
        _lastPosition!.latitude,
        _lastPosition!.longitude,
        position.latitude,
        position.longitude,
      );

      // Ignora micro-fluttuazioni GPS sotto 1.0m
      if (deltaDist >= 1.0) {
        _totalDistanceMeters += deltaDist;

        // Dislivello positivo aggregato
        final deltaAlt = position.altitude - _lastPosition!.altitude;
        if (deltaAlt > 0) {
          _elevationGainMeters += deltaAlt;
        }
      }
    }

    _currentSpeedKmh = (position.speed * 3.6).clamp(0.0, 100.0);
    _lastPosition = position;

    final pt = {
      'timestamp': DateTime.now().toIso8601String(),
      'latitude': position.latitude,
      'longitude': position.longitude,
      'altitude': position.altitude,
      'speedKmh': _currentSpeedKmh,
    };
    _routePoints.add(pt);

    notifyListeners();
  }

  /// Ferma il tracciamento GPS
  Future<List<Map<String, dynamic>>> stopTracking() async {
    await _positionSubscription?.cancel();
    _positionSubscription = null;
    _isTracking = false;
    notifyListeners();
    return List.from(_routePoints);
  }

  /// Salva i punti del percorso reali nel DB SQLite per il workout specificato
  Future<void> saveRouteToDatabase(int workoutId) async {
    for (final pt in _routePoints) {
      await _dbHelper.insertTracciaPoint(
        workoutId: workoutId,
        latitude: pt['latitude'] as double,
        longitude: pt['longitude'] as double,
        altitude: pt['altitude'] as double,
        speedKmh: pt['speedKmh'] as double,
      );
    }
  }
}
