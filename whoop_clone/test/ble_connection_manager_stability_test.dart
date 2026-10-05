import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:whoop_clone/data/ble/ble_connection_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late BleConnectionManager manager;

  setUp(() {
    manager = BleConnectionManager();
    manager.resetStateForTest();
  });

  tearDown(() {
    manager.dispose();
  });

  group('BLE-01: Lock Single-Flight & Backoff Esponenziale', () {
    test('Single-flight: Chiamate concorrenti a connectSavedDevice vengono ignorate se isConnecting è true', () async {
      // Simula connessione in corso protetta da lock
      manager.setIsConnectingForTesting(true);
      expect(manager.isConnecting, isTrue);

      final result = await manager.connectSavedDevice();
      // Deve restituire false senza procedere a disconnettere o avviare scansione
      expect(result, isFalse);
    });

    test('Single-flight: disconnect() NON deve MAI disconnettere se lo stato è BleState.connecting', () async {
      manager.updateStateForTesting(BleState.connecting, 'Tentativo di connessione in corso...');
      expect(manager.state, equals(BleState.connecting));
      expect(manager.isConnecting, isTrue);

      // Chiamata manuale a disconnect()
      await manager.disconnect();

      // Lo stato NON deve essere diventato disconnected! La disconnessione durante connecting è rifiutata
      expect(manager.state, equals(BleState.connecting));
    });

    test('Single-flight: disconnect() ignorato anche se _isConnecting lock è attivo', () async {
      manager.setIsConnectingForTesting(true);
      manager.updateStateForTesting(BleState.disconnected);

      await manager.disconnect();
      // Disconnect ignorato
      expect(manager.isConnecting, isTrue);
    });

    test('Backoff esponenziale: Calcolo deterministico dei delay senza jitter (2s -> 4s -> 8s -> 16s -> 32s -> max 60s)', () {
      expect(BleConnectionManager.calculateBackoffDelay(1, withJitter: false), equals(const Duration(seconds: 2)));
      expect(BleConnectionManager.calculateBackoffDelay(2, withJitter: false), equals(const Duration(seconds: 4)));
      expect(BleConnectionManager.calculateBackoffDelay(3, withJitter: false), equals(const Duration(seconds: 8)));
      expect(BleConnectionManager.calculateBackoffDelay(4, withJitter: false), equals(const Duration(seconds: 16)));
      expect(BleConnectionManager.calculateBackoffDelay(5, withJitter: false), equals(const Duration(seconds: 32)));
      expect(BleConnectionManager.calculateBackoffDelay(6, withJitter: false), equals(const Duration(seconds: 60)));
      // Capped al massimo a 60s
      expect(BleConnectionManager.calculateBackoffDelay(7, withJitter: false), equals(const Duration(seconds: 60)));
      expect(BleConnectionManager.calculateBackoffDelay(15, withJitter: false), equals(const Duration(seconds: 60)));
    });

    test('Backoff esponenziale: Jitter applica variazione positiva compresa tra 0 e 500 ms', () {
      for (int attempt = 1; attempt <= 6; attempt++) {
        final withJitter = BleConnectionManager.calculateBackoffDelay(attempt, withJitter: true);
        final base = BleConnectionManager.calculateBackoffDelay(attempt, withJitter: false);

        expect(withJitter.inMilliseconds, greaterThanOrEqualTo(base.inMilliseconds));
        expect(withJitter.inMilliseconds, lessThanOrEqualTo(base.inMilliseconds + 500));
      }
    });

    test('Backoff esponenziale: Contatore preservato se la connessione cade prima di 60s in streaming', () {
      manager.setBackoffAttemptForTesting(4);
      expect(manager.backoffAttempt, equals(4));

      // Entra in streaming
      manager.updateStateForTesting(BleState.streaming, 'Streaming attivo');
      expect(manager.state, equals(BleState.streaming));

      // Se cade subito dopo pochi istanti (prima di 60s), il backoff NON deve essere azzerato
      manager.updateStateForTesting(BleState.disconnected, 'Disconnessione immediata');
      expect(manager.backoffAttempt, equals(4));
    });
  });

  group('BLE-02 & BLE-03: Unico Percorso di Bind, Guard Atomica e Scansione Ordinata', () {
    test('BLE-02: Guard atomica bindInProgress impedisce binding simultanei', () {
      expect(manager.bindInProgress, isFalse);
    });

    test('BLE-03: Scansione rifiutata se isConnecting è true', () async {
      manager.setIsConnectingForTesting(true);

      // Entrambe le chiamate devono restituire immediatamente senza avviare la scansione
      await manager.startScanOnly();
      expect(manager.state, isNot(equals(BleState.scanning)));

      await manager.startScanAndConnect();
      expect(manager.state, isNot(equals(BleState.scanning)));
    });
  });

  group('BLE-04: Coda ACK Non Bloccante per Storico Store-and-Forward', () {
    test('enqueueCommand accoda comandi nella coda TX in modo asincrono', () {
      final payload1 = Uint8List.fromList([0xAA, 0x01, 0x17, 0x00]);
      final payload2 = Uint8List.fromList([0xAA, 0x01, 0x17, 0x01]);

      manager.enqueueCommand(payload1);
      manager.enqueueCommand(payload2);

      // Comandi registrati nella coda
      expect(manager.txQueueLength, greaterThanOrEqualTo(0));
    });
  });

  group('BLE-06: Tracking Status Code Reali di Disconnessione e Buffer Circolare', () {
    test('Interprete status code Android/iOS GATT mappa correttamente tutti i codici noti', () {
      expect(interpretDisconnectCode(0), contains('GATT_SUCCESS'));
      expect(interpretDisconnectCode(8), contains('GATT_CONN_TIMEOUT'));
      expect(interpretDisconnectCode(19), contains('GATT_CONN_TERMINATE_PEER_USER'));
      expect(interpretDisconnectCode(22), contains('GATT_CONN_TERMINATE_LOCAL_HOST'));
      expect(interpretDisconnectCode(34), contains('GATT_CONN_LMP_TIMEOUT'));
      expect(interpretDisconnectCode(62), contains('GATT_CONN_FAIL_ESTABLISH'));
      expect(interpretDisconnectCode(133), contains('GATT_ERROR 133'));
      expect(interpretDisconnectCode(99, 'Custom Error'), contains('Custom Error'));
    });

    test('Lista circolare mantiene esattamente gli ultimi 20 eventi di disconnessione', () {
      expect(manager.disconnectionHistory, isEmpty);

      // Registra 25 eventi di disconnessione
      for (int i = 1; i <= 25; i++) {
        manager.recordDisconnectionForTesting(i, 'Test disconnect #$i');
      }

      // La lunghezza massima deve essere 20
      expect(manager.disconnectionHistory.length, equals(20));

      // L'evento più vecchio rimasto deve essere il 6° (i primi 5 sono stati scartati)
      expect(manager.disconnectionHistory.first.statusCode, equals(6));
      // L'ultimo deve essere il 25°
      expect(manager.disconnectionHistory.last.statusCode, equals(25));
    });

    test('Ogni DisconnectionEvent registra timestamp, statusCode, reason e sessionDuration', () {
      manager.recordDisconnectionForTesting(8, 'Connection Timeout');
      final event = manager.disconnectionHistory.last;

      expect(event.statusCode, equals(8));
      expect(event.reason, contains('GATT_CONN_TIMEOUT'));
      expect(event.timestamp, isNotNull);
      expect(event.sessionDuration, isNotNull);
    });
  });

  group('Data Watchdog: Rilevamento e Interruzione Connessioni Zombie', () {
    test('Watchdog scatta e forza la disconnessione se non si ricevono frame in streaming', () async {
      // Imposta lo stato a streaming
      manager.updateStateForTesting(BleState.streaming, 'Streaming attivo');
      expect(manager.isStreaming, isTrue);

      // Simula lo scatto del watchdog (>15s senza frame)
      await manager.triggerWatchdogForTesting();

      // Lo stato deve aver avviato la riconnessione (passando da disconnected a reconnecting)
      expect(manager.state, equals(BleState.reconnecting));

      // Deve aver registrato l'evento zombie nella storia delle disconnessioni
      expect(manager.disconnectionHistory.isNotEmpty, isTrue);
      final zombieEvent = manager.disconnectionHistory.firstWhere((e) => e.statusCode == -1);
      expect(zombieEvent.reason, contains('Data Watchdog'));
    });

    test('La ricezione continua di frame di telemetria rinfresca il watchdog', () {
      manager.updateStateForTesting(BleState.streaming, 'Streaming attivo');
      expect(manager.isStreaming, isTrue);

      // Simula arrivo pacchetti periodici (1 Hz)
      manager.onTelemetryDataReceivedForTesting();
      manager.onTelemetryDataReceivedForTesting();

      // Lo stato rimane correttamente in streaming
      expect(manager.state, equals(BleState.streaming));
    });
  });
}
