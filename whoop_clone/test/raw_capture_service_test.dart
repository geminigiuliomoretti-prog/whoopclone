import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:whoop_clone/data/services/raw_capture_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late RawCaptureService service;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    tempDir = Directory.systemTemp.createTempSync('raw_capture_test_');
    service = RawCaptureService(
      capturesDirectory: tempDir,
      maxBufferSize: 5, // Piccolo per testare facilmente la soglia
      flushInterval: const Duration(seconds: 1),
    );
  });

  tearDown(() async {
    await service.dispose();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('RawCaptureService Unit Tests', () {
    test('1. startCapture() crea il file NDJSON e aggiorna lo stato di cattura e SharedPreferences', () async {
      expect(service.isCapturing, isFalse);
      expect(service.currentCapturePath, isNull);

      final filePath = await service.startCapture();

      expect(service.isCapturing, isTrue);
      expect(filePath, isNotEmpty);
      expect(File(filePath).existsSync(), isTrue);
      expect(filePath, contains('whoop_raw_capture_'));
      expect(filePath.endsWith('.ndjson'), isTrue);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(RawCaptureService.prefCaptureEnabledKey), isTrue);
    });

    test('2. recordNotification() ignora i pacchetti se la cattura è disabilitata', () async {
      final sampleBytes = Uint8List.fromList([0xAA, 0x10, 0x00, 0x57]);
      service.recordNotification('61080005-8d6d-82b8-614a-1c8cb0f8dcc6', sampleBytes);

      expect(service.bufferedCount, equals(0));
      expect(service.totalPacketsCaptured, equals(0));
    });

    test('3. recordNotification() e flush() salvano correttamente pacchetti in formato NDJSON bit-perfect', () async {
      final filePath = await service.startCapture();
      const charUuid = '61080005-8d6d-82b8-614a-1c8cb0f8dcc6';
      final packetBytes = Uint8List.fromList([0xAA, 0x05, 0x00, 0x12, 0x34, 0x56, 0x78]);

      service.recordNotification(charUuid, packetBytes);

      expect(service.bufferedCount, equals(1));
      expect(service.totalPacketsCaptured, equals(1));

      // Flush su disco
      await service.flush();
      expect(service.bufferedCount, equals(0));

      // Lettura file NDJSON
      final file = File(filePath);
      final lines = await file.readAsLines();
      expect(lines.length, equals(1));

      final json = jsonDecode(lines.first) as Map<String, dynamic>;
      expect(json['charUuid'], equals(charUuid));
      expect(json['byteLength'], equals(packetBytes.length));
      expect(json['hexPayload'], equals('aa050012345678'));
      expect(json['timestampUtcMs'], isA<int>());
    });

    test('4. Auto-flush scatta automaticamente quando viene raggiunta la soglia maxBufferSize', () async {
      final filePath = await service.startCapture();
      const charUuid = 'fd4b0005-8d6d-82b8-614a-1c8cb0f8dcc6';

      // maxBufferSize impostato a 5 in setUp()
      for (int i = 0; i < 5; i++) {
        service.recordNotification(charUuid, Uint8List.fromList([0xAA, i]));
      }

      // Il 5° pacchetto deve innescare l'auto-flush
      await Future.delayed(const Duration(milliseconds: 50));
      expect(service.bufferedCount, equals(0));
      expect(service.totalPacketsCaptured, equals(5));

      final lines = await File(filePath).readAsLines();
      expect(lines.length, equals(5));
    });

    test('5. stopCapture() svuota i byte residui, chiude il file e aggiorna SharedPreferences', () async {
      final filePath = await service.startCapture();
      service.recordNotification('2a37', Uint8List.fromList([0x16, 75]));
      expect(service.bufferedCount, equals(1));

      await service.stopCapture();

      expect(service.isCapturing, isFalse);
      expect(service.bufferedCount, equals(0));

      final lines = await File(filePath).readAsLines();
      expect(lines.length, equals(1));

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(RawCaptureService.prefCaptureEnabledKey), isFalse);
    });

    test('6. listCaptureFiles() e getLatestCapturePath() ordinano correttamente i file registrati', () async {
      // Crea file 1
      await service.startCapture();
      await service.stopCapture();

      await Future.delayed(const Duration(milliseconds: 1100));

      // Crea file 2
      final service2 = RawCaptureService(capturesDirectory: tempDir);
      final path2 = await service2.startCapture();
      await service2.stopCapture();

      final files = await service.listCaptureFiles();
      expect(files.length, equals(2));

      final latestPath = await service.getLatestCapturePath();
      expect(latestPath, equals(path2));
    });

    test('7. exportCaptureFile() esporta correttamente il file di cattura nella destinazione richiesta', () async {
      await service.startCapture();
      service.recordNotification('61080003', Uint8List.fromList([0x01, 0x02, 0x03]));
      await service.stopCapture();

      final exportDir = Directory('${tempDir.path}/custom_exports');
      final exportedFile = await service.exportCaptureFile(destinationDir: exportDir.path);

      expect(exportedFile.existsSync(), isTrue);
      expect(exportedFile.path, contains('custom_exports'));
      final content = await exportedFile.readAsString();
      expect(content, contains('010203'));
    });

    test('8. init() riprende automaticamente la registrazione se abilitata in SharedPreferences', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(RawCaptureService.prefCaptureEnabledKey, true);

      final autoService = RawCaptureService(capturesDirectory: tempDir, prefs: prefs);
      expect(autoService.isCapturing, isFalse);

      await autoService.init();
      expect(autoService.isCapturing, isTrue);

      await autoService.stopCapture();
    });
  });
}
