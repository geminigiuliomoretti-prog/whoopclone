import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import '../models/allenamento.dart';
import '../models/ciclo_fisiologico.dart';
import '../models/sonno.dart';
import '../repositories/sqlite_whoop_repository.dart';

/// Servizio I/O per esportazione, importazione e parsing file (StrandImport da ryanbr/noop)
class NoopImportExportService {
  final SqliteWhoopRepository repository;

  NoopImportExportService({required this.repository});

  // ==========================================
  // 1. ESPORTAZIONE WHOOP CSV (WhoopCsvExporter)
  // ==========================================

  /// Esporta i cicli fisiologici in formato WHOOP CSV standard
  Future<String> exportPhysiologicalCyclesCsv() async {
    final cicli = await repository.getCicliFisiologici();
    final StringBuffer buffer = StringBuffer();
    buffer.writeln('Cycle start time,Cycle end time,Cycle timezone,Cycle Strain,Recovery score,Resting heart rate (bpm),Heart rate variability (ms),Skin temp (celsius)');

    for (var c in cicli) {
      buffer.writeln([
        '${c.dataIso} 00:00:00',
        '${c.dataIso} 23:59:59',
        c.fusoOrario,
        c.sforzoGiornaliero?.toStringAsFixed(1) ?? '',
        c.punteggioRecuperoPct?.toStringAsFixed(0) ?? '',
        c.fcrBpm?.toString() ?? '',
        c.vfcMs?.toStringAsFixed(1) ?? '',
        c.tempCutaneaC?.toStringAsFixed(1) ?? '',
      ].join(','));
    }
    return buffer.toString();
  }

  /// Esporta gli allenamenti in formato WHOOP CSV standard
  Future<String> exportWorkoutsCsv() async {
    final allenamenti = await repository.getAllenamenti();
    final StringBuffer buffer = StringBuffer();
    buffer.writeln('Activity name,Start time,End time,Duration (min),Activity Strain,Average HR (bpm),Max HR (bpm),Kilocalories');

    for (var a in allenamenti) {
      buffer.writeln([
        a.nomeAttivita,
        a.oraInizioAllenamento.toIso8601String(),
        a.oraFineAllenamento.toIso8601String(),
        a.durataMin.toString(),
        a.strainAttivita?.toStringAsFixed(1) ?? '0.0',
        a.hrMedia?.toString() ?? '',
        a.hrMax?.toString() ?? '',
        a.calorie?.toString() ?? '',
      ].join(','));
    }
    return buffer.toString();
  }

  /// Esporta le sessioni di sonno in formato WHOOP CSV standard
  Future<String> exportSleepsCsv() async {
    final cicli = await repository.getCicliFisiologici();
    final StringBuffer buffer = StringBuffer();
    buffer.writeln('Cycle date,Sleep performance %,Deep sleep (min),REM sleep (min),Light sleep (min),Awake (min),Sleep efficiency %');

    for (var c in cicli) {
      buffer.writeln([
        c.dataIso,
        c.andamentoSonnoPct?.toStringAsFixed(0) ?? '',
        c.sonnoProfondoMin?.toStringAsFixed(0) ?? '',
        c.sonnoRemMin?.toStringAsFixed(0) ?? '',
        c.sonnoLeggeroMin?.toStringAsFixed(0) ?? '',
        c.durataRisveglioMin?.toStringAsFixed(0) ?? '',
        c.efficienzaSonnoPct?.toStringAsFixed(0) ?? '',
      ].join(','));
    }
    return buffer.toString();
  }

  // ==========================================
  // 2. IMPORTAZIONE WHOOP CSV & BASELINE BOOTSTRAP
  // ==========================================

  /// Bootstrap del profilo e della cronologia da export CSV WHOOP
  Future<BootstrapResult> bootstrapFromCsv(String csvContent) async {
    final lines = const LineSplitter().convert(csvContent);
    if (lines.length <= 1) {
      return const BootstrapResult(success: false, message: 'File CSV vuoto o privo di righe dati');
    }

    final header = lines.first.toLowerCase();
    final headers = header.split(',').map((h) => h.trim()).toList();

    int idxStart = headers.indexWhere((h) => h.contains('start') || h.contains('date') || h.contains('giorno'));
    int idxStrain = headers.indexWhere((h) => h.contains('strain') || h.contains('sforzo'));
    int idxRecovery = headers.indexWhere((h) => h.contains('recovery') || h.contains('recupero'));
    int idxRhr = headers.indexWhere((h) => h.contains('resting heart') || h.contains('rhr') || h.contains('fcr'));
    int idxHrv = headers.indexWhere((h) => h.contains('variability') || h.contains('hrv') || h.contains('vfc'));
    int idxTemp = headers.indexWhere((h) => h.contains('skin temp') || h.contains('temperature') || h.contains('temp'));
    int idxResp = headers.indexWhere((h) => h.contains('respiratory') || h.contains('resp') || h.contains('rpm'));

    if (idxStart == -1) idxStart = 0;
    if (idxStrain == -1 && headers.length > 3) idxStrain = 3;
    if (idxRecovery == -1 && headers.length > 4) idxRecovery = 4;
    if (idxRhr == -1 && headers.length > 5) idxRhr = 5;
    if (idxHrv == -1 && headers.length > 6) idxHrv = 6;
    if (idxTemp == -1 && headers.length > 7) idxTemp = 7;

    final List<double> hrvSamples = [];
    final List<double> rhrSamples = [];
    final List<String> dates = [];
    int importedCycles = 0;

    for (int i = 1; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;
      final cols = line.split(',');
      if (cols.length <= idxStart) continue;

      final startStr = cols[idxStart].trim();
      if (startStr.isEmpty) continue;
      final dateKey = startStr.contains(' ')
          ? startStr.split(' ')[0]
          : (startStr.contains('T') ? startStr.split('T')[0] : startStr);
      if (dateKey.length < 10) continue;

      double? strain = idxStrain != -1 && cols.length > idxStrain ? double.tryParse(cols[idxStrain].trim()) : null;
      double? recovery = idxRecovery != -1 && cols.length > idxRecovery ? double.tryParse(cols[idxRecovery].trim()) : null;
      double? rhr = idxRhr != -1 && cols.length > idxRhr ? double.tryParse(cols[idxRhr].trim()) : null;
      double? hrv = idxHrv != -1 && cols.length > idxHrv ? double.tryParse(cols[idxHrv].trim()) : null;
      double? temp = idxTemp != -1 && cols.length > idxTemp ? double.tryParse(cols[idxTemp].trim()) : null;
      double? resp = idxResp != -1 && cols.length > idxResp ? double.tryParse(cols[idxResp].trim()) : null;

      if (hrv != null && hrv > 0) hrvSamples.add(hrv);
      if (rhr != null && rhr > 0) rhrSamples.add(rhr);
      dates.add(dateKey);

      final ciclo = CicloFisiologico(
        dataIso: dateKey,
        strainGiornaliero: strain,
        recoveryScore: recovery,
        rhrNotte: rhr,
        hrvNotte: hrv,
        tempCutaneaC: temp,
        frequenzaRespiratoriaRpm: resp,
        provenance: 'BOOTSTRAP',
      );

      await repository.insertCicloFisiologico(ciclo);
      importedCycles++;
    }

    if (importedCycles == 0) {
      return const BootstrapResult(success: false, message: 'Nessun record valido trovato nel CSV');
    }

    dates.sort();
    final earliest = dates.first;
    final latest = dates.last;

    // Calcolo e persistenza baseline personale dell'utente da dati storici
    final currentProfile = await repository.userRepository.getProfile();
    if (currentProfile != null && hrvSamples.length >= 3 && rhrSamples.length >= 3) {
      final hrvMean = hrvSamples.reduce((a, b) => a + b) / hrvSamples.length;
      final hrvVariance = hrvSamples.map((x) => (x - hrvMean) * (x - hrvMean)).reduce((a, b) => a + b) / hrvSamples.length;
      final hrvStd = math.sqrt(hrvVariance).clamp(5.0, 50.0);

      final rhrMean = rhrSamples.reduce((a, b) => a + b) / rhrSamples.length;
      final rhrVariance = rhrSamples.map((x) => (x - rhrMean) * (x - rhrMean)).reduce((a, b) => a + b) / rhrSamples.length;
      final rhrStd = math.sqrt(rhrVariance).clamp(1.0, 20.0);

      final updatedProfile = currentProfile.copyWith(
        hrvBaselineMean: double.parse(hrvMean.toStringAsFixed(1)),
        hrvBaselineStd: double.parse(hrvStd.toStringAsFixed(1)),
        rhrBaselineMean: double.parse(rhrMean.toStringAsFixed(1)),
        rhrBaselineStd: double.parse(rhrStd.toStringAsFixed(1)),
        hrRestBaseline: rhrMean.round(),
        isBootstrapCompleted: true,
        bootstrapTimestamp: DateTime.now().toIso8601String(),
        bootstrapVersion: '1.0',
        baselineSource: 'WHOOP_CSV_EXPORT',
        baselineSampleCount: hrvSamples.length,
        baselineCalcPeriod: '$earliest - $latest',
      );
      await repository.userRepository.updateProfile(updatedProfile);
    }

    return BootstrapResult(
      success: true,
      importedCycles: importedCycles,
      sampleCount: hrvSamples.length,
      period: '$earliest - $latest',
      message: 'Bootstrap completato: $importedCycles cicli importati ($earliest - $latest)',
    );
  }

  /// Importa dati da stringa CSV di cicli fisiologici (retrocompatibile)
  Future<int> importPhysiologicalCyclesCsv(String csvContent) async {
    final result = await bootstrapFromCsv(csvContent);
    return result.importedCycles;
  }

  /// Importa dati da stringa CSV di sessioni di sonno (sleeps.csv)
  Future<int> importSleepsCsv(String csvContent) async {
    final lines = const LineSplitter().convert(csvContent);
    if (lines.length <= 1) return 0;

    final header = lines.first.toLowerCase();
    final headers = header.split(',').map((h) => h.trim()).toList();

    int idxDate = headers.indexWhere((h) => h.contains('cycle date') || h.contains('date') || h.contains('giorno'));
    int idxOnset = headers.indexWhere((h) => h.contains('sleep onset') || h.contains('onset') || h.contains('start time') || h.contains('inizio'));
    int idxWake = headers.indexWhere((h) => h.contains('wake time') || h.contains('wake') || h.contains('end time') || h.contains('fine'));
    int idxDuration = headers.indexWhere((h) => h.contains('asleep duration') || h.contains('duration (min)') || h.contains('durata'));
    int idxDeep = headers.indexWhere((h) => h.contains('deep') || h.contains('sws'));
    int idxRem = headers.indexWhere((h) => h.contains('rem'));
    int idxPerf = headers.indexWhere((h) => h.contains('performance'));
    int idxEff = headers.indexWhere((h) => h.contains('efficiency') || h.contains('efficienza'));
    int idxResp = headers.indexWhere((h) => h.contains('respiratory') || h.contains('resp') || h.contains('rpm'));

    if (idxDate == -1) idxDate = 0;

    int importedCount = 0;

    for (int i = 1; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;
      final cols = line.split(',');
      if (cols.length <= idxDate) continue;

      final dateRaw = cols[idxDate].trim();
      if (dateRaw.isEmpty) continue;
      final dateKey = dateRaw.contains(' ')
          ? dateRaw.split(' ')[0]
          : (dateRaw.contains('T') ? dateRaw.split('T')[0] : dateRaw);
      if (dateKey.length < 10) continue;

      String onsetStr = idxOnset != -1 && cols.length > idxOnset ? cols[idxOnset].trim() : '';
      String wakeStr = idxWake != -1 && cols.length > idxWake ? cols[idxWake].trim() : '';

      final onsetDt = DateTime.tryParse(onsetStr) ?? DateTime.tryParse('${dateKey}T23:00:00.000Z') ?? DateTime.now();
      final wakeDt = DateTime.tryParse(wakeStr) ?? DateTime.tryParse('${dateKey}T07:00:00.000Z') ?? DateTime.now();

      int durationMin = idxDuration != -1 && cols.length > idxDuration ? (double.tryParse(cols[idxDuration].trim())?.round() ?? 0) : 0;
      if (durationMin <= 0 && wakeDt.isAfter(onsetDt)) {
        durationMin = wakeDt.difference(onsetDt).inMinutes;
      }

      int deepMin = idxDeep != -1 && cols.length > idxDeep ? (double.tryParse(cols[idxDeep].trim())?.round() ?? 0) : 0;
      int remMin = idxRem != -1 && cols.length > idxRem ? (double.tryParse(cols[idxRem].trim())?.round() ?? 0) : 0;
      double? perfPct = idxPerf != -1 && cols.length > idxPerf ? double.tryParse(cols[idxPerf].trim()) : null;
      double? effPct = idxEff != -1 && cols.length > idxEff ? double.tryParse(cols[idxEff].trim()) : null;
      double? respRate = idxResp != -1 && cols.length > idxResp ? double.tryParse(cols[idxResp].trim()) : null;

      final sonno = Sonno(
        dataIso: dateKey,
        oraInizio: onsetDt.toIso8601String(),
        oraFine: wakeDt.toIso8601String(),
        durataTotMin: durationMin,
        sonnoProfondoMin: deepMin,
        sonnoRemMin: remMin,
        efficienzaPct: effPct,
        sleepPerformancePct: perfPct,
        provenance: 'BOOTSTRAP',
      );

      await repository.insertSonno(sonno);

      // Se disponibile frequenza respiratoria, aggiorna il ciclo fisiologico corrispondente
      if (respRate != null && respRate > 0) {
        final existingCiclo = await repository.getCicloPerData(dateKey);
        if (existingCiclo != null) {
          final updatedCiclo = CicloFisiologico(
            dataIso: existingCiclo.dataIso,
            strainGiornaliero: existingCiclo.strainGiornaliero,
            recoveryScore: existingCiclo.recoveryScore,
            rhrNotte: existingCiclo.rhrNotte,
            hrvNotte: existingCiclo.hrvNotte,
            tempCutaneaC: existingCiclo.tempCutaneaCVal,
            frequenzaRespiratoriaRpm: respRate,
            sleepNeedMin: existingCiclo.sleepNeedMin,
            spo2Pct: existingCiclo.spo2PctVal,
            calorieTot: existingCiclo.calorieTot,
            provenance: existingCiclo.provenance,
          );
          await repository.insertCicloFisiologico(updatedCiclo);
        }
      }

      importedCount++;
    }

    if (importedCount > 0) {
      await recalculateBaselineFromHistory();
    }
    return importedCount;
  }

  /// Importa dati da stringa CSV di allenamenti (workouts.csv)
  Future<int> importWorkoutsCsv(String csvContent) async {
    final lines = const LineSplitter().convert(csvContent);
    if (lines.length <= 1) return 0;

    final header = lines.first.toLowerCase();
    final headers = header.split(',').map((h) => h.trim()).toList();

    int idxName = headers.indexWhere((h) => h.contains('activity name') || h.contains('name') || h.contains('sport'));
    int idxStart = headers.indexWhere((h) => h.contains('activity start time') || h.contains('start time') || h.contains('inizio'));
    int idxEnd = headers.indexWhere((h) => h.contains('activity end time') || h.contains('end time') || h.contains('fine'));
    int idxDur = headers.indexWhere((h) => h.contains('duration (min)') || h.contains('duration') || h.contains('durata'));
    int idxStrain = headers.indexWhere((h) => h.contains('strain'));
    int idxAvgHr = headers.indexWhere((h) => h.contains('average hr') || h.contains('avg hr') || h.contains('media hr'));
    int idxMaxHr = headers.indexWhere((h) => h.contains('max hr') || h.contains('massima hr'));
    int idxCals = headers.indexWhere((h) => h.contains('kilocalories') || h.contains('calories') || h.contains('calorie') || h.contains('energy burned'));

    if (idxName == -1) idxName = 0;

    int importedCount = 0;

    for (int i = 1; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;
      final cols = line.split(',');
      if (cols.length <= idxName) continue;

      final name = cols[idxName].trim();
      if (name.isEmpty) continue;

      String startStr = idxStart != -1 && cols.length > idxStart ? cols[idxStart].trim() : '';
      String endStr = idxEnd != -1 && cols.length > idxEnd ? cols[idxEnd].trim() : '';

      final startDt = DateTime.tryParse(startStr) ?? DateTime.now();
      final endDt = DateTime.tryParse(endStr) ?? startDt.add(const Duration(minutes: 45));
      final dateIso = startDt.toIso8601String().substring(0, 10);

      int durMin = idxDur != -1 && cols.length > idxDur ? (double.tryParse(cols[idxDur].trim())?.round() ?? 0) : 0;
      if (durMin <= 0) {
        durMin = endDt.difference(startDt).inMinutes.clamp(1, 1440);
      }

      double? strain = idxStrain != -1 && cols.length > idxStrain ? double.tryParse(cols[idxStrain].trim()) : null;
      int? avgHr = idxAvgHr != -1 && cols.length > idxAvgHr ? double.tryParse(cols[idxAvgHr].trim())?.round() : null;
      int? maxHr = idxMaxHr != -1 && cols.length > idxMaxHr ? double.tryParse(cols[idxMaxHr].trim())?.round() : null;
      int? cals = idxCals != -1 && cols.length > idxCals ? double.tryParse(cols[idxCals].trim())?.round() : null;

      final workout = Allenamento(
        dataIso: dateIso,
        nomeAttivita: name,
        oraInizioAllenamento: startDt,
        oraFineAllenamento: endDt,
        durataMin: durMin,
        strainAttivita: strain,
        hrMedia: avgHr,
        hrMax: maxHr,
        calorie: cals,
      );

      await repository.insertAllenamento(workout);
      importedCount++;
    }

    return importedCount;
  }

  /// Ricalcola progressivamente la baseline utente sui cicli e sonni presenti nel DB
  Future<void> recalculateBaselineFromHistory() async {
    final cicli = await repository.getCicliFisiologici();
    final sonni = await repository.getSonnoLogs();
    final currentProfile = await repository.userRepository.getProfile();
    if (currentProfile == null) return;

    final hrvList = cicli.map((c) => c.vfcMs).where((v) => v != null && v > 0).map((v) => v!).toList();
    final rhrList = cicli.map((c) => c.fcrBpm).where((r) => r != null && r > 0).map((r) => r!.toDouble()).toList();
    final sleepDurations = sonni.map((s) => s.durataTotMin).where((d) => d > 120).toList();

    if (hrvList.length >= 3 && rhrList.length >= 3) {
      final hrvMean = hrvList.reduce((a, b) => a + b) / hrvList.length;
      final hrvVariance = hrvList.map((x) => (x - hrvMean) * (x - hrvMean)).reduce((a, b) => a + b) / hrvList.length;
      final hrvStd = math.sqrt(hrvVariance).clamp(5.0, 50.0);

      final rhrMean = rhrList.reduce((a, b) => a + b) / rhrList.length;
      final rhrVariance = rhrList.map((x) => (x - rhrMean) * (x - rhrMean)).reduce((a, b) => a + b) / rhrList.length;
      final rhrStd = math.sqrt(rhrVariance).clamp(1.0, 20.0);

      final avgSleepMin = sleepDurations.isNotEmpty
          ? (sleepDurations.reduce((a, b) => a + b) / sleepDurations.length).round().clamp(360, 600)
          : currentProfile.sleepBaselineMin;

      final updatedProfile = currentProfile.copyWith(
        hrvBaselineMean: double.parse(hrvMean.toStringAsFixed(1)),
        hrvBaselineStd: double.parse(hrvStd.toStringAsFixed(1)),
        rhrBaselineMean: double.parse(rhrMean.toStringAsFixed(1)),
        rhrBaselineStd: double.parse(rhrStd.toStringAsFixed(1)),
        hrRestBaseline: rhrMean.round(),
        sleepBaselineMin: avgSleepMin,
        isBootstrapCompleted: true,
        baselineSampleCount: hrvList.length,
      );
      await repository.userRepository.updateProfile(updatedProfile);
    }
  }

  /// Importa un archivio WHOOP completo (cicli, sonni, workout)
  Future<BootstrapResult> importFullWhoopArchive({
    String? cyclesCsv,
    String? sleepsCsv,
    String? workoutsCsv,
  }) async {
    int cyclesCount = 0;
    int sleepsCount = 0;
    int workoutsCount = 0;

    if (cyclesCsv != null && cyclesCsv.isNotEmpty) {
      final res = await bootstrapFromCsv(cyclesCsv);
      cyclesCount = res.importedCycles;
    }

    if (sleepsCsv != null && sleepsCsv.isNotEmpty) {
      sleepsCount = await importSleepsCsv(sleepsCsv);
    }

    if (workoutsCsv != null && workoutsCsv.isNotEmpty) {
      workoutsCount = await importWorkoutsCsv(workoutsCsv);
    }

    await recalculateBaselineFromHistory();

    final totalImported = cyclesCount + sleepsCount + workoutsCount;
    return BootstrapResult(
      success: totalImported > 0,
      importedCycles: cyclesCount,
      sampleCount: totalImported,
      message: 'Import completato: $cyclesCount cicli, $sleepsCount sonni, $workoutsCount workout importati con successo.',
    );
  }

  // ==========================================
  // 3. PARSER GPX / FIT / TCX (ActivityFileImporter)
  // ==========================================

  /// Parser semplificato GPX per estrarre attività da traccia GPS
  static Allenamento? parseGpxTrack(String gpxXmlContent, {String defaultActivityName = 'Corsa GPS'}) {
    try {
      final timeMatches = RegExp(r'<time>(.*?)</time>').allMatches(gpxXmlContent).toList();
      if (timeMatches.length < 2) return null;

      final startTime = DateTime.parse(timeMatches.first.group(1)!);
      final endTime = DateTime.parse(timeMatches.last.group(1)!);
      final durationMin = endTime.difference(startTime).inMinutes.clamp(1, 1440);

      final dateIso = startTime.toIso8601String().substring(0, 10);

      // Estrai frequenza cardiaca se presente nella traccia GPX (es. estensione Garmin/TrackPointExtension)
      final hrMatches = RegExp(r'<(?:gpxtpx:)?hr>(\d+)</(?:gpxtpx:)?hr>').allMatches(gpxXmlContent).toList();
      int? hrAvg;
      int? hrMax;
      if (hrMatches.isNotEmpty) {
        final hrValues = hrMatches.map((m) => int.parse(m.group(1)!)).toList();
        if (hrValues.isNotEmpty) {
          hrAvg = (hrValues.reduce((a, b) => a + b) / hrValues.length).round();
          hrMax = hrValues.reduce((a, b) => a > b ? a : b);
        }
      }

      return Allenamento(
        dataIso: dateIso,
        nomeAttivita: defaultActivityName,
        oraInizioAllenamento: startTime,
        oraFineAllenamento: endTime,
        durataMin: durationMin,
        hrMedia: hrAvg,
        hrMax: hrMax,
        strainAttivita: null,
        calorie: null,
      );
    } catch (e) {
      debugPrint('Errore parsing GPX: $e');
      return null;
    }
  }

  // ==========================================
  // 4. BACKUP & RESTORE DATABASE JSON
  // ==========================================

  /// Esporta l'intero database SQLite in una stringa JSON
  Future<String> backupDatabaseToJson() async {
    final cicli = await repository.getCicliFisiologici();
    final allenamenti = await repository.getAllenamenti();
    final diario = await repository.getVociDiarioPerCiclo(DateTime.now().toIso8601String().substring(0, 10));

    final map = {
      'exported_at': DateTime.now().toIso8601String(),
      'version': '5.2.0',
      'cicli': cicli.map((c) => c.toMap()).toList(),
      'allenamenti': allenamenti.map((a) => a.toMap()).toList(),
      'diario': diario.map((d) => d.toMap()).toList(),
    };

    return const JsonEncoder.withIndent('  ').convert(map);
  }
}

/// Risultato del processo di bootstrap da CSV
class BootstrapResult {
  final bool success;
  final int importedCycles;
  final int sampleCount;
  final String period;
  final String message;

  const BootstrapResult({
    required this.success,
    this.importedCycles = 0,
    this.sampleCount = 0,
    this.period = '',
    required this.message,
  });
}
