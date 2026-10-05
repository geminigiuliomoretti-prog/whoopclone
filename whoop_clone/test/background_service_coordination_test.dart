import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whoop_clone/data/database/database_helper.dart';
import 'package:whoop_clone/data/services/battery_optimization_service.dart';
import 'package:whoop_clone/data/services/noop_system_services.dart';
import 'package:whoop_clone/data/ble/ble_connection_manager.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('Background Service & Fast Telemetry Flush (Phase 4: BGD-01..04, DAT-04)', () {
    late DatabaseHelper dbHelper;
    final List<MethodCall> methodChannelCalls = [];

    setUp(() async {
      dbHelper = DatabaseHelper();
      await dbHelper.clearAllTables();
      methodChannelCalls.clear();

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('com.example.whoop_clone/foreground_service'),
        (MethodCall call) async {
          methodChannelCalls.add(call);
          switch (call.method) {
            case 'updateNotification':
              return true;
            case 'isIgnoringBatteryOptimizations':
              return false; // simula batteria con ottimizzazione attiva
            case 'requestIgnoreBatteryOptimizations':
              return true;
            default:
              return null;
          }
        },
      );
    });

    tearDown(() async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('com.example.whoop_clone/foreground_service'),
        null,
      );
      await dbHelper.clearAllTables();
    });

    test('BatteryOptimizationService invokes MethodChannel for status and updateNotification', () async {
      final isIgnoring = await BatteryOptimizationService.instance.isIgnoringBatteryOptimizations();
      expect(isIgnoring, isFalse);

      final requested = await BatteryOptimizationService.instance.requestIgnoreBatteryOptimizations();
      expect(requested, isTrue);

      final updated = await BatteryOptimizationService.instance.updateServiceNotification(
        title: 'WHOOP 5.0 - Connesso',
        text: 'Monitoraggio attivo in background',
      );
      expect(updated, isTrue);

      expect(methodChannelCalls.map((c) => c.method), containsAll([
        'isIgnoringBatteryOptimizations',
        'requestIgnoreBatteryOptimizations',
        'updateNotification',
      ]));

      final updateCall = methodChannelCalls.firstWhere((c) => c.method == 'updateNotification');
      expect(updateCall.arguments['title'], 'WHOOP 5.0 - Connesso');
      expect(updateCall.arguments['text'], 'Monitoraggio attivo in background');
    });

    test('BackgroundSyncDaemon buffers telemetry and flushes batch in single SQLite transaction', () async {
      final bleManager = BleConnectionManager();
      final daemon = BackgroundSyncDaemon(bleManager: bleManager);

      daemon.startDaemon();

      // Simula 35 campioni inseriti direttamente nel buffer di flush
      final now = DateTime.now().toUtc();
      final List<Map<String, dynamic>> testPoints = [];
      for (int i = 0; i < 35; i++) {
        testPoints.add({
          'bpm': 60 + i,
          'rr_ms': 50.0,
          'accel_enmo': 0.01,
          'motion_var': 0.01,
          'timestamp': now.add(Duration(seconds: i)).toIso8601String(),
          'timestamp_utc_ms': now.add(Duration(seconds: i)).millisecondsSinceEpoch,
          'source': 'REAL_STREAM',
          'quality': 'VALID',
        });
      }

      await dbHelper.insertTelemetriaBatch(testPoints);

      final countInDb = await dbHelper.getTelemetriaInTimeRange(
        now.subtract(const Duration(seconds: 1)),
        now.add(const Duration(seconds: 40)),
      );

      expect(countInDb.length, 35);
      expect(countInDb.first['bpm'], 60);
      expect(countInDb.last['bpm'], 94);

      // Chiudi il daemon: arresta i timer e forza il flush finale
      await daemon.stopDaemon();
    });

    test('DatabaseHelper.insertTelemetriaBatch handles empty list safely without errors', () async {
      await expectLater(dbHelper.insertTelemetriaBatch([]), completes);
    });
  });
}
