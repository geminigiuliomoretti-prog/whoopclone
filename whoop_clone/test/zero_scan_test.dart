import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:whoop_clone/data/ble/ble_connection_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WHOOP Zero-Scan Reconnection Unit Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({
        'whoop_paired_device_id': 'AA:BB:CC:DD:EE:FF',
      });
    });

    test('getPairedDeviceId recupera l\'ID del dispositivo memorizzato nelle SharedPreferences', () async {
      final bleManager = BleConnectionManager();
      final pairedId = await bleManager.getPairedDeviceId();

      expect(pairedId, equals('AA:BB:CC:DD:EE:FF'));
    });

    test('Zero-Scan con ID salvato non restituisce errore di ID mancante', () async {
      final bleManager = BleConnectionManager();
      final pairedId = await bleManager.getPairedDeviceId();

      expect(pairedId, isNotNull);
      expect(pairedId!.isNotEmpty, isTrue);
    });

    test('Zero-Scan con SharedPreferences vuote restituisce null', () async {
      SharedPreferences.setMockInitialValues({});
      final bleManager = BleConnectionManager();
      final pairedId = await bleManager.getPairedDeviceId();

      expect(pairedId, isNull);
    });
  });
}
