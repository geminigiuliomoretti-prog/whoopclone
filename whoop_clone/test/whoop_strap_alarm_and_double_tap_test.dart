import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:whoop_clone/data/database/database_helper.dart';
import 'package:whoop_clone/data/ble/ble_connection_manager.dart';
import 'package:whoop_clone/data/ble/strap_double_tap_detector.dart';
import 'package:whoop_clone/data/services/haptic_alarm_service.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    DatabaseHelper.isTestMode = true;
  });

  group('WHOOP Strap Alarm & Double-Tap Dismissal Tests', () {
    late BleConnectionManager bleManager;
    late HapticAlarmService alarmService;

    setUp(() {
      bleManager = BleConnectionManager();
      alarmService = HapticAlarmService(bleManager: bleManager);
    });

    tearDown(() {
      alarmService.dispose();
      bleManager.dispose();
    });

    test('1. StrapDoubleTapDetector rileva sequenza di doppio tocco tramite accelerometro', () {
      final detector = StrapDoubleTapDetector();
      final t0 = DateTime(2026, 10, 17, 8, 0, 0, 0);

      // Campione a riposo (1g su Z, ENMO 0)
      bool detected = detector.processSample(ax: 0.0, ay: 0.0, az: 1.0, enmo: 0.0, timestamp: t0);
      expect(detected, isFalse);

      // Primo tocco: picco di impatto a t0 + 100ms
      final t1 = t0.add(const Duration(milliseconds: 100));
      detected = detector.processSample(ax: 0.5, ay: 0.4, az: 1.5, enmo: 0.6, timestamp: t1);
      expect(detected, isFalse, reason: 'Il primo tocco da solo non deve far scattare il double-tap');

      // Campione intermedio tra i due tocchi (rimbalzo a t0 + 200ms)
      final tBounce = t0.add(const Duration(milliseconds: 200));
      detected = detector.processSample(ax: 0.0, ay: 0.1, az: 1.0, enmo: 0.05, timestamp: tBounce);
      expect(detected, isFalse);

      // Secondo tocco valido a t0 + 400ms (delta t = 300ms, entro 150-1500ms)
      final t2 = t0.add(const Duration(milliseconds: 400));
      detected = detector.processSample(ax: 0.6, ay: 0.5, az: 1.6, enmo: 0.7, timestamp: t2);
      expect(detected, isTrue, reason: 'Due tocchi ravvicinati devono confermare il Double-Tap');
    });

    test('2. StrapDoubleTapDetector ignora tocchi troppo distanti (> 1500ms)', () {
      final detector = StrapDoubleTapDetector();
      final t0 = DateTime(2026, 10, 17, 8, 0, 0, 0);

      // Primo tocco
      detector.processSample(ax: 0.6, ay: 0.4, az: 1.5, enmo: 0.6, timestamp: t0);

      // Tocco successivo dopo 2500ms (> 1500ms maxInterTapIntervalMs)
      final tLate = t0.add(const Duration(milliseconds: 2500));
      final detected = detector.processSample(ax: 0.6, ay: 0.4, az: 1.5, enmo: 0.6, timestamp: tLate);
      expect(detected, isFalse, reason: 'Due tocchi separati da > 1.5s non devono essere considerati doppio tocco');
    });

    test('3. StrapDoubleTapDetector riconosce eventi fisici su caratteristica 0004 (EVENTS_FROM_STRAP)', () {
      final detector = StrapDoubleTapDetector();
      final dummyEventBytes = Uint8List.fromList([0x01, 0x02, 0x0A]);
      expect(detector.processStrapEvent(dummyEventBytes), isTrue);
    });

    test('4. Quando la sveglia suona, il doppio tocco sul cinturino la spegne immediatamente', () async {
      await alarmService.triggerAlarm(reason: 'Test Sveglia');
      expect(alarmService.isRinging, isTrue);

      // Simula doppio tocco sul cinturino WHOOP
      bleManager.triggerDoubleTapEvent();
      // Concedi un microtask per il listener dello stream
      await Future.delayed(const Duration(milliseconds: 50));

      expect(alarmService.isRinging, isFalse, reason: 'Il doppio tocco deve spegnere immediatamente la sveglia');
    });

    test('5. sendHapticVibrationCommand e sendTestVibrationPulseNow non vibrano il telefono per default', () async {
      // Disconnesso: senza vibratePhone, deve restituire notConnected (non phoneHapticOnly)
      final status = await bleManager.sendHapticVibrationCommand(pattern: 1);
      expect(status, equals(HapticResultStatus.notConnected));

      final statusWithPhone = await bleManager.sendHapticVibrationCommand(pattern: 1, vibratePhone: true);
      expect(statusWithPhone, equals(HapticResultStatus.phoneHapticOnly));
    });

    test('6. Spegnimento sveglia con dismissAlarm invia cancellazione alla strap e resetta isRinging', () async {
      await alarmService.triggerAlarm(reason: 'Test Sveglia');
      expect(alarmService.isRinging, isTrue);

      await alarmService.dismissAlarm();
      expect(alarmService.isRinging, isFalse);
    });
  });
}
