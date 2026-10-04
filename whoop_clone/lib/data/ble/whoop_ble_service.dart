import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'ble_connection_manager.dart';
import 'noop_protocol_decoder.dart';

/// Service BLE WHOOP per la gestione avanzata dei comandi GATT e Smart Alarm Engine
///
/// 1. Scrittura comandi Allarme a 20-byte su CMD_TO_STRAP (0x0010 / 61080002...) in modalità writeWithoutResponse
/// 2. Ascolto notifiche ACK su CMD_FROM_STRAP (0x0012 / 61080003...)
/// 3. Architettura Smart Alarm (Doppia Logica: Fail-Safe Locale + Innesco Dinamico via Telemetria Live)
class WhoopBleService {
  final BleConnectionManager bleManager;

  static const String cmdToStrapUuid = '61080002-8d6d-82b8-614a-1c8cb0f8dcc6';
  static const String cmdFromStrapUuid = '61080003-8d6d-82b8-614a-1c8cb0f8dcc6';
  static const String dataFromStrapUuid = '61080005-8d6d-82b8-614a-1c8cb0f8dcc6';

  final StreamController<List<int>> _ackStreamController =
      StreamController<List<int>>.broadcast();

  Stream<List<int>> get ackStream => _ackStreamController.stream;

  WhoopBleService({required this.bleManager});

  /// Invia il comando di programmazione allarme di 20 byte a CMD_TO_STRAP in modalità writeWithoutResponse
  Future<bool> sendAlarmCommandPayload(Uint8List payload) async {
    return await bleManager.writeAlarmCommand(payload);
  }

  /// Programma un allarme con un timestamp UTC target
  Future<bool> setHapticAlarm({
    required int targetTimestampUtc,
    int packetCounter = 0x01,
    int alarmFlags = 0x0142,
  }) async {
    final payload = HapticClockEncoder.buildAlarmCommandPayload(
      targetTimestampUtc: targetTimestampUtc,
      packetCounter: packetCounter,
      alarmFlags: alarmFlags,
    );
    return await sendAlarmCommandPayload(payload);
  }

  /// Gestione dell'Esecuzione dello Smart Alarm sull'Host (Doppia Logica)
  ///
  /// 1. Programmazione del Fail-Safe Locale (Offline fallback): invia allo strap il timestamp limite ("Latest Wake Time")
  /// 2. Innesco Dinamico via Telemetria Live: se BLE è connesso nella finestra di 30-60 min prima,
  ///    ascolta lo streaming da DATA_FROM_STRAP. Quando rileva sonno leggero o target raggiunto,
  ///    invia l'innesco immediato (T_attuale + 2s).
  Future<void> processSmartAlarmSession({
    required int latestWakeUtc,
    int windowMinutes = 30,
    required bool Function(Map<String, dynamic> telemetryData) isLightSleepOrTargetReached,
  }) async {
    // 1. Programmazione Fail-Safe locale sul firmware dello strap
    final fallbackPayload = HapticClockEncoder.buildAlarmCommandPayload(
      targetTimestampUtc: latestWakeUtc,
      packetCounter: 0x01,
      alarmFlags: 0x0142,
    );
    await sendAlarmCommandPayload(fallbackPayload);

    final int windowStartUtc = latestWakeUtc - (windowMinutes * 60);

    // 2. Innesco Dinamico via Telemetria Live (se connesso)
    StreamSubscription? telemetrySub;
    telemetrySub = bleManager.packet96ByteStream.listen((packet) async {
      final nowUtc = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
      if (nowUtc >= windowStartUtc && nowUtc < latestWakeUtc) {
        final telemetry = {
          'bpm': packet.bpm,
          'hrvMs': packet.hrvMs,
          'accelG': {'x': packet.accelX, 'y': packet.accelY, 'z': packet.accelZ},
        };

        if (isLightSleepOrTargetReached(telemetry)) {
          // Innesco immediato: programmato al secondo corrente + 2
          final triggerUtc = nowUtc + 2;
          final triggerPayload = HapticClockEncoder.buildAlarmCommandPayload(
            targetTimestampUtc: triggerUtc,
            packetCounter: 0x02,
            alarmFlags: 0x0142,
          );
          await sendAlarmCommandPayload(triggerPayload);
          await telemetrySub?.cancel();
        }
      } else if (nowUtc >= latestWakeUtc) {
        await telemetrySub?.cancel();
      }
    });
  }
}
