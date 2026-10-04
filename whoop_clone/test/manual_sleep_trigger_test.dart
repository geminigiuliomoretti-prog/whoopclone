import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:whoop_clone/data/database/database_helper.dart';
import 'package:whoop_clone/viewmodels/whoop_viewmodel.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    DatabaseHelper.isTestMode = true;
  });

  tearDown(() async {
    await DatabaseHelper().clearAllTables();
  });

  test('Trigger Engine on Manual Sleep Execution - Telemetria Grezza 8 Ore', () async {
    final dbHelper = DatabaseHelper();
    final now = DateTime.now();
    final startTime = DateTime(now.year, now.month, now.day, 23, 0).subtract(const Duration(days: 1));
    final endTime = DateTime(now.year, now.month, now.day, 7, 0);
    final dateIso = startTime.toIso8601String().substring(0, 10);

    // 1. Popola telemetria_grezza con 960 campioni realistici (8 ore a intervalli di 30s)
    const int sampleCount = 960;
    for (int i = 0; i < sampleCount; i++) {
      final sampleTime = startTime.add(Duration(seconds: i * 30));
      double motion = 0.002;
      int bpm = 54;
      double rr = 68.0;

      if (i < 20 || i > 940) {
        motion = 0.08;
        bpm = 72;
        rr = 52.0;
      } else if ((i >= 100 && i < 250) || (i >= 400 && i < 500)) {
        motion = 0.001;
        bpm = 50;
        rr = 78.0;
      } else if ((i >= 300 && i < 380) || (i >= 600 && i < 720)) {
        motion = 0.003;
        bpm = 58;
        rr = 62.0;
      }

      await dbHelper.insertTelemetriaPoint(
        bpm: bpm,
        rrMs: rr,
        motionVar: motion,
        timestamp: sampleTime,
      );
    }

    // 2. Esegue la pipeline via WhoopViewModel
    final viewModel = WhoopViewModel();
    final result = await viewModel.processAndAddManualSleep(
      startTime: startTime,
      endTime: endTime,
      dateIso: dateIso,
      allowFallback: false,
    );

    // 3. Verifiche via Assert / Expect
    expect(result['success'], isTrue);
    expect(result['hasRealBleData'], isTrue);
    expect(result['recoveryScore'], isNotNull);

    final double recScore = (result['recoveryScore'] as num).toDouble();
    expect(recScore, greaterThan(1.0));
    expect(recScore, lessThan(100.0));

    // Verifica persistenza su SQLite per la tabella sonno
    final sonnoMap = await dbHelper.getSonnoByDate(dateIso);
    expect(sonnoMap, isNotNull);
    expect(sonnoMap!['data_iso'], equals(dateIso));
    expect(sonnoMap['durata_tot_min'], greaterThan(0));
    expect(sonnoMap['sonno_profondo_min'], greaterThan(0));

    // Verifica persistenza su SQLite per la tabella cicli_fisiologici
    final cicloMap = await dbHelper.getCicloByDate(dateIso);
    expect(cicloMap, isNotNull);
    expect(cicloMap!['recovery_score'], equals(recScore));

    // Verifica che l'ultimo ciclo del ViewModel rifletta il recovery ricalcolato
    expect(viewModel.ultimoCiclo, isNotNull);
    expect(viewModel.ultimoCiclo!.punteggioRecuperoPct, equals(recScore));
  });
}
