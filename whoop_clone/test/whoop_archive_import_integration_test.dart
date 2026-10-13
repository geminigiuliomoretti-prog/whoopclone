import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:whoop_clone/data/database/database_helper.dart';
import 'package:whoop_clone/data/repositories/sqlite_whoop_repository.dart';
import 'package:whoop_clone/data/repositories/user_repository.dart';
import 'package:whoop_clone/data/services/whoop_archive_importer.dart';
import 'package:whoop_clone/viewmodels/whoop_viewmodel.dart';
import 'package:archive/archive.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  DatabaseHelper.isTestMode = true;

  group('WHOOP Archive Importer & Personal Baselines Integration Tests', () {
    late DatabaseHelper dbHelper;
    late SqliteWhoopRepository whoopRepo;
    late UserRepository userRepo;
    const realZipPath = r'c:\Users\costa\Downloads\my_whoop_data_2026_05_03.zip';

    setUp(() async {
      dbHelper = DatabaseHelper();
      await dbHelper.clearAllTables();
      whoopRepo = SqliteWhoopRepository();
      userRepo = UserRepository();
    });

    test('1. Import real WHOOP ZIP export preserves full historical dataset and initializes baselines', () async {
      final realFile = File(realZipPath);
      expect(realFile.existsSync(), isTrue, reason: 'Real ZIP file must exist at $realZipPath');

      final importer = WhoopArchiveImporter(
        repository: whoopRepo,
        userRepository: userRepo,
      );

      final stagesRecorded = <WhoopImportStage>[];
      final result = await importer.importArchive(
        filePath: realZipPath,
        onProgress: (progress) {
          if (!stagesRecorded.contains(progress.stage)) {
            stagesRecorded.add(progress.stage);
          }
        },
      );

      expect(result.success, isTrue);
      expect(stagesRecorded, contains(WhoopImportStage.validating));
      expect(stagesRecorded, contains(WhoopImportStage.savingHistory));
      expect(stagesRecorded, contains(WhoopImportStage.calculatingBaselines));
      expect(stagesRecorded, contains(WhoopImportStage.finalizing));

      // 1. Exact record counts
      expect(result.cyclesCount, 130, reason: 'Must parse and preserve exactly 130 cycles');
      expect(result.sleepsCount, 133, reason: 'Must parse and preserve exactly 133 sleeps (128 main + 5 naps)');
      expect(result.workoutsCount, 226, reason: 'Must parse and preserve exactly 226 workouts');
      expect(result.journalCount, 4667, reason: 'Must parse and preserve exactly 4,667 diary entries');

      // 2. Date interval
      expect(result.startDate, '2025-12-25');
      expect(result.endDate, '2026-05-03');

      // 3. Verify SQLite persistence of full history
      final cyclesInDb = await whoopRepo.getCicliFisiologici();
      expect(cyclesInDb.length, 130);
      final sleepsInDb = await whoopRepo.getSonnoLogs();
      expect(sleepsInDb.length, 133);
      final workoutsInDb = await whoopRepo.getAllenamenti();
      expect(workoutsInDb.length, 226);
      final journalInDb = await whoopRepo.getVociDiario();
      expect(journalInDb.length, 4667);

      // 4. Verify Personal Baselines computed & persisted (Rolling 30-day excluding current day)
      final baselines = await whoopRepo.getPersonalBaselines();
      expect(baselines.isNotEmpty, isTrue);
      final baselineMap = {for (final b in baselines) b.metricKey: b};
      // Check HRV baseline (30-day rolling preceding 2026-05-03)
      expect(baselineMap.containsKey('hrv'), isTrue);
      final hrvBaseline = baselineMap['hrv']!;
      expect(hrvBaseline.sampleCount, 30);
      expect(hrvBaseline.mean, closeTo(69.10, 0.5));
      expect(hrvBaseline.extraStats['meanLnRmssd'], isNotNull);
      expect(hrvBaseline.extraStats['stdDevLnRmssd'], isNotNull);

      // Check RHR baseline
      expect(baselineMap.containsKey('rhr'), isTrue);
      final rhrBaseline = baselineMap['rhr']!;
      expect(rhrBaseline.sampleCount, 30);
      expect(rhrBaseline.mean, closeTo(55.20, 0.5));

      // Check Respiratory Rate baseline
      expect(baselineMap.containsKey('respiratory_rate'), isTrue);
      final respBaseline = baselineMap['respiratory_rate']!;
      expect(respBaseline.sampleCount, 30);
      expect(respBaseline.mean, closeTo(14.07, 0.5));

      // Check Skin Temperature baseline
      expect(baselineMap.containsKey('skin_temp'), isTrue);
      final tempBaseline = baselineMap['skin_temp']!;
      expect(tempBaseline.sampleCount, 30);
      expect(tempBaseline.mean, closeTo(34.40, 0.5));

      // Check SpO2 baseline
      expect(baselineMap.containsKey('spo2'), isTrue);
      final spo2Baseline = baselineMap['spo2']!;
      expect(spo2Baseline.sampleCount, 30);
      expect(spo2Baseline.mean, closeTo(95.43, 0.5));

      // Check Sleep metrics baselines
      expect(baselineMap.containsKey('sleep_duration'), isTrue);
      expect(baselineMap['sleep_duration']!.sampleCount, 30);
      expect(baselineMap.containsKey('sleep_efficiency'), isTrue);
      expect(baselineMap.containsKey('deep_sleep_duration'), isTrue);
      expect(baselineMap.containsKey('rem_sleep_duration'), isTrue);

      // 5. Verify User Profile baselines updated with the rolling 30-day baseline
      final profile = await userRepo.getProfile();
      expect(profile, isNotNull);
      expect(profile!.baselineSampleCount, 30);
      expect(profile.hrvBaselineMean, closeTo(69.10, 0.5));
      expect(profile.rhrBaselineMean, closeTo(55.20, 0.5));
      expect(profile.hrRestBaseline, 55); // Rounded from 55.20
    });

    test('2. Importer is idempotent: Re-importing the same ZIP does not create duplicates', () async {
      final importer = WhoopArchiveImporter(
        repository: whoopRepo,
        userRepository: userRepo,
      );

      // First run
      final firstResult = await importer.importArchive(filePath: realZipPath);
      expect(firstResult.success, isTrue);

      // Second run with the same file
      final secondResult = await importer.importArchive(filePath: realZipPath);
      expect(secondResult.success, isTrue);

      // Verify zero duplicate records in SQLite
      final cycles = await whoopRepo.getCicliFisiologici();
      expect(cycles.length, 130, reason: 'Duplicate cycles must not be inserted');
      final sleeps = await whoopRepo.getSonnoLogs();
      expect(sleeps.length, 133, reason: 'Duplicate sleeps must not be inserted');
      final workouts = await whoopRepo.getAllenamenti();
      expect(workouts.length, 226, reason: 'Duplicate workouts must not be inserted');
      final journal = await whoopRepo.getVociDiario();
      expect(journal.length, 4667, reason: 'Duplicate journal entries must not be inserted');

      final baselines = await whoopRepo.getPersonalBaselines();
      expect(baselines.length, firstResult.baselines.length);
    });

    test('3. WhoopViewModel loads personal baselines and passes them to vitalEvaluations and engines', () async {
      final importer = WhoopArchiveImporter(
        repository: whoopRepo,
        userRepository: userRepo,
      );
      await importer.importArchive(filePath: realZipPath);

      final viewModel = WhoopViewModel(
        repository: whoopRepo,
        userRepository: userRepo,
      );

      // Set to the latest imported date
      viewModel.setSelectedDate(DateTime.parse('2026-05-03'), triggerAutoSync: false);
      await viewModel.loadData(triggerAutoSync: false);

      expect(viewModel.personalBaselines.isNotEmpty, isTrue);
      expect(viewModel.personalBaselinesMap.containsKey('hrv'), isTrue);
      expect(viewModel.personalBaselinesMap['hrv']!.mean, closeTo(69.10, 0.5));

      // Test vital evaluations
      final vitals = viewModel.vitalEvaluations;
      expect(vitals.length, 5);

      final hrvVital = vitals.firstWhere((v) => v.key == 'vfc');
      expect(hrvVital.currentValue, 67.0); // Value on 2026-05-03
      expect(hrvVital.baselineValue, closeTo(69.10, 0.5));
      expect(hrvVital.isBaselinePersonal, isTrue);

      final rhrVital = vitals.firstWhere((v) => v.key == 'fcr');
      expect(rhrVital.currentValue, 55.0); // Value on 2026-05-03
      expect(rhrVital.baselineValue, closeTo(55.20, 0.5));
      expect(rhrVital.isBaselinePersonal, isTrue);

      final tempVital = vitals.firstWhere((v) => v.key == 'temp');
      // On 2026-05-03, raw temp is 34.19 °C. Rolling 30-day baseline is 34.42 °C.
      // Delta = 34.19 - 34.42 = -0.23 °C
      expect(tempVital.currentValue, closeTo(-0.23, 0.05));
      expect(tempVital.isBaselinePersonal, isTrue);

      // Verify WHOOP recovery score is preserved for history without overriding app logic
      expect(viewModel.ultimoCiclo?.punteggioRecuperoPct, 68.0);
    });

    test('4. Importer validates missing files and non-zip archives gracefully', () async {
      final importer = WhoopArchiveImporter(
        repository: whoopRepo,
        userRepository: userRepo,
      );

      // Test with non-existent file
      final notFoundResult = await importer.importArchive(filePath: 'non_existent_file.zip');
      expect(notFoundResult.success, isFalse);
      expect(notFoundResult.message, contains('non trovato'));

      // Test with invalid zip bytes
      final badBytesResult = await importer.importArchive(fileBytes: [1, 2, 3, 4, 5]);
      expect(badBytesResult.success, isFalse);
      expect(badBytesResult.message, anyOf(contains('ZIP non valido'), contains('Nessun file CSV')));

      // Test with zip containing no recognizable Whoop CSVs
      final archive = Archive();
      final dummyContent = 'test content'.codeUnits;
      archive.addFile(ArchiveFile('random_file.txt', dummyContent.length, dummyContent));
      final zipEncoder = ZipEncoder();
      final emptyZipBytes = zipEncoder.encode(archive);

      final noWhoopResult = await importer.importArchive(fileBytes: emptyZipBytes);
      expect(noWhoopResult.success, isFalse);
      expect(noWhoopResult.message, contains('Nessun file CSV'));
    });
  });
}
