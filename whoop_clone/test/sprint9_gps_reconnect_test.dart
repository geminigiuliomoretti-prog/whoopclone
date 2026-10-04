import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:whoop_clone/data/database/database_helper.dart';
import 'package:whoop_clone/data/services/gps_tracking_service.dart';
import 'package:whoop_clone/data/ble/ble_connection_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('Sprint 9 — Real GPS Tracking & Persistent BLE Auto-Reconnect Tests', () {
    late DatabaseHelper dbHelper;

    setUp(() async {
      DatabaseHelper.isTestMode = true;
      dbHelper = DatabaseHelper();
      await dbHelper.clearAllTables();
    });

    test('1. Database Schema v8: Tabella attivita_tracce e salvataggio coordinate GPS', () async {
      final gpsService = GpsTrackingService();

      final workoutId = await dbHelper.insertAllenamento({
        'data_iso': '2026-08-10',
        'nome_attivita': 'Corsa Outdoor',
        'ora_inizio': '2026-08-10T10:00:00.000Z',
        'ora_fine': '2026-08-10T10:30:00.000Z',
        'durata_min': 30,
        'hr_media': 152,
        'hr_max': 176,
        'strain_attivita': 14.2,
        'calorie': 350,
      });

      expect(workoutId, greaterThan(0));

      await gpsService.saveRouteToDatabase(workoutId);

      // Inserimento manuale punto traccia GPS per testare la persistenza SQLite
      await dbHelper.insertTracciaPoint(
        workoutId: workoutId,
        latitude: 45.4642,
        longitude: 9.1900,
        altitude: 120.5,
        speedKmh: 12.4,
      );

      final savedPoints = await dbHelper.getTracciaPoints(workoutId);
      expect(savedPoints.length, equals(1));
      expect(savedPoints.first['latitude'], equals(45.4642));
      expect(savedPoints.first['longitude'], equals(9.1900));
    });

    test('2. Persistent BLE Auto-Reconnect: SharedPreferences Device ID & BleConnectionManager', () async {
      final bleManager = BleConnectionManager();
      
      final pairedId = await bleManager.getPairedDeviceId();
      expect(pairedId, isNull);

      final reconnected = await bleManager.connectSavedDevice();
      expect(reconnected, isFalse);
      expect(bleManager.state, anyOf(BleState.disconnected, BleState.error));
    });

    test('3. Calcolo Distanza Haversine e Generazione GPX Export XML', () {
      final testWaypoints = [
        {'latitude': 45.4642, 'longitude': 9.1900, 'altitude': 120.0, 'timestamp': '2026-08-10T10:00:00Z'},
        {'latitude': 45.4680, 'longitude': 9.1950, 'altitude': 125.0, 'timestamp': '2026-08-10T10:05:00Z'},
        {'latitude': 45.4720, 'longitude': 9.2000, 'altitude': 128.0, 'timestamp': '2026-08-10T10:10:00Z'},
      ];

      final distMeters = GpsTrackingService.calculateCumulativeDistanceMeters(testWaypoints);
      expect(distMeters, greaterThan(500.0));

      final gpxXml = GpsTrackingService.generateGpxString(testWaypoints, 'Corsa Outdoor');
      expect(gpxXml, contains('<?xml version="1.0"'));
      expect(gpxXml, contains('<gpx version="1.1"'));
      expect(gpxXml, contains('<trkpt lat="45.4642" lon="9.19"'));
      expect(gpxXml, contains('<name>Corsa Outdoor</name>'));
    });
  });
}
