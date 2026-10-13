import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import '../models/allenamento.dart';
import '../models/ciclo_fisiologico.dart';
import '../models/personal_baseline.dart';
import '../models/sonno.dart';
import '../models/utente_profilo.dart';
import '../models/voce_diario.dart';
import '../repositories/sqlite_whoop_repository.dart';
import '../repositories/user_repository.dart';
import 'baseline_calculator.dart';
import 'whoop_csv_parser.dart';
import '../database/database_helper.dart';

/// Callback per monitorare il reale progresso dell'importazione
typedef OnImportProgress = void Function(WhoopImportProgress progress);

/// Fasi di importazione reali
enum ImportStage {
  validating,
  validatingZip,
  extracting,
  readingCsv,
  parsing,
  importingCycles,
  importingSleeps,
  importingWorkouts,
  importingDiary,
  savingHistory,
  calculatingBaselines,
  finalizing,
  completed,
  failed,
}

typedef WhoopImportStage = ImportStage;

/// Modello di stato del progresso reale
class WhoopImportProgress {
  final ImportStage stage;
  final String message;
  final double fraction; // 0.0 - 1.0
  final int currentCount;
  final int totalCount;

  const WhoopImportProgress({
    required this.stage,
    required this.message,
    required this.fraction,
    this.currentCount = 0,
    this.totalCount = 0,
  });

  double get progressPct => fraction;
}

/// Risultato finale dettagliato dell'importazione
class WhoopImportResult {
  final bool success;
  final int cyclesCount;
  final int sleepsCount;
  final int workoutsCount;
  final int diaryCount;
  final String periodStart;
  final String periodEnd;
  final Map<String, PersonalBaseline> baselines;
  final String message;
  final String? errorMessage;

  const WhoopImportResult({
    required this.success,
    this.cyclesCount = 0,
    this.sleepsCount = 0,
    this.workoutsCount = 0,
    this.diaryCount = 0,
    this.periodStart = '',
    this.periodEnd = '',
    this.baselines = const {},
    required this.message,
    this.errorMessage,
  });

  int get journalCount => diaryCount;
  String? get startDate => periodStart.isNotEmpty ? periodStart : null;
  String? get endDate => periodEnd.isNotEmpty ? periodEnd : null;
  List<String> get errors => errorMessage != null ? [errorMessage!] : const [];
  List<String> get warnings => const [];
}

/// Servizio per l'importazione, validazione, normalizzazione e inizializzazione baseline
/// da archivio ZIP esportato da WHOOP.
class WhoopArchiveImporter {
  final SqliteWhoopRepository repository;
  final UserRepository? userRepository;

  WhoopArchiveImporter({
    required this.repository,
    this.userRepository,
  });

  /// Importa l'archivio da percorso file o byte in memoria
  Future<WhoopImportResult> importArchive({
    String? filePath,
    List<int>? fileBytes,
    OnImportProgress? onProgress,
  }) async {
    if (filePath != null) {
      return importArchiveFromFile(filePath, onProgress: onProgress);
    }
    if (fileBytes != null) {
      return importArchiveFromBytes(fileBytes, onProgress: onProgress);
    }
    return const WhoopImportResult(
      success: false,
      message: 'Nessun file o byte specificato per l\'importazione',
      errorMessage: 'Neither filePath nor fileBytes was provided',
    );
  }

  /// Importa l'archivio da percorso file su disco
  Future<WhoopImportResult> importArchiveFromFile(
    String zipFilePath, {
    OnImportProgress? onProgress,
  }) async {
    try {
      final file = File(zipFilePath);
      if (!await file.exists()) {
        return WhoopImportResult(
          success: false,
          message: 'File ZIP non trovato al percorso specificato',
          errorMessage: 'File does not exist: $zipFilePath',
        );
      }
      final bytes = await file.readAsBytes();
      return await importArchiveFromBytes(bytes, onProgress: onProgress);
    } catch (e, st) {
      debugPrint('[WhoopArchiveImporter] Error reading file: $e\n$st');
      return WhoopImportResult(
        success: false,
        message: 'Errore durante la lettura del file ZIP: $e',
        errorMessage: e.toString(),
      );
    }
  }

  /// Importa l'archivio da byte memorizzati in memoria
  Future<WhoopImportResult> importArchiveFromBytes(
    List<int> zipBytes, {
    OnImportProgress? onProgress,
  }) async {
    try {
      // 1. Validazione e apertura dello ZIP
      onProgress?.call(const WhoopImportProgress(
        stage: ImportStage.validating,
        message: 'Analisi export...',
        fraction: 0.10,
      ));

      if (zipBytes.isEmpty) {
        return const WhoopImportResult(
          success: false,
          message: 'Archivio ZIP vuoto o danneggiato',
          errorMessage: 'Empty zip bytes',
        );
      }

      final Archive archive;
      try {
        archive = ZipDecoder().decodeBytes(zipBytes);
      } catch (e) {
        return WhoopImportResult(
          success: false,
          message: 'Impossibile estrarre i dati: formato ZIP non valido o corrotto',
          errorMessage: e.toString(),
        );
      }

      // 2. Identificazione e lettura dei file CSV
      onProgress?.call(const WhoopImportProgress(
        stage: ImportStage.readingCsv,
        message: 'Identificazione e lettura file CSV...',
        fraction: 0.20,
      ));

      String? cyclesCsv;
      String? sleepsCsv;
      String? workoutsCsv;
      String? diaryCsv;

      for (final file in archive) {
        if (!file.isFile) continue;
        final name = file.name.toLowerCase().replaceAll('\\', '/').split('/').last;

        if (name == 'cicli_fisiologici.csv' || name == 'physiological_cycles.csv') {
          cyclesCsv = utf8.decode(file.content as List<int>, allowMalformed: true);
        } else if (name == 'sonno.csv' || name == 'sleeps.csv') {
          sleepsCsv = utf8.decode(file.content as List<int>, allowMalformed: true);
        } else if (name == 'allenamenti.csv' || name == 'workouts.csv') {
          workoutsCsv = utf8.decode(file.content as List<int>, allowMalformed: true);
        } else if (name == 'voci_diario.csv' || name == 'journal_entries.csv') {
          diaryCsv = utf8.decode(file.content as List<int>, allowMalformed: true);
        }
      }

      // Validazione presenza file minimi
      if (cyclesCsv == null && sleepsCsv == null && workoutsCsv == null && diaryCsv == null) {
        return const WhoopImportResult(
          success: false,
          message: 'Nessun file CSV valido riconosciuto all\'interno dello ZIP (attesi cicli_fisiologici.csv, sonno.csv, allenamenti.csv, voci_diario.csv)',
          errorMessage: 'No recognized CSV files in zip',
        );
      }

      // 3. Parsing e Normalizzazione
      List<CicloFisiologico> cycles = [];
      Map<String, String> cycleStartToDateIsoMap = {};

      if (cyclesCsv != null) {
        cycles = WhoopCsvParser.parseCicliFisiologici(cyclesCsv);
        // Costruisci mappa cycleStart -> dateIso per correlare gli altri file
        final rawRows = WhoopCsvParser.parseCsv(cyclesCsv);
        if (rawRows.length > 1) {
          final normHeaders = rawRows.first.map(WhoopCsvParser.normalizeHeader).toList();
          final idxStart = WhoopCsvParser.findColumnIndex(normHeaders, ['iniziociclo', 'cyclestart', 'start', 'data']);
          if (idxStart != -1) {
            for (int i = 0; i < cycles.length && i + 1 < rawRows.length; i++) {
              final startRaw = rawRows[i + 1][idxStart].trim();
              if (startRaw.isNotEmpty) {
                cycleStartToDateIsoMap[startRaw] = cycles[i].dataIso;
              }
            }
          }
        }
      }

      List<Sonno> sleeps = [];
      if (sleepsCsv != null) {
        sleeps = WhoopCsvParser.parseSonno(sleepsCsv, cycleStartToDateIsoMap: cycleStartToDateIsoMap);
      }

      List<Allenamento> workouts = [];
      if (workoutsCsv != null) {
        workouts = WhoopCsvParser.parseAllenamenti(workoutsCsv, cycleStartToDateIsoMap: cycleStartToDateIsoMap);
      }

      List<VoceDiario> diary = [];
      if (diaryCsv != null) {
        diary = WhoopCsvParser.parseVociDiario(diaryCsv, cycleStartToDateIsoMap: cycleStartToDateIsoMap);
      }

      // 4. Salvataggio Storico Cicli Fisiologici (Idempotente)
      onProgress?.call(const WhoopImportProgress(
        stage: ImportStage.savingHistory,
        message: 'Importazione storico...',
        fraction: 0.30,
      ));

      // Cross-populate sleepNeed and sleepDebt between cycles and sleeps if missing
      final cycleNeedMap = {for (final c in cycles) if (c.sleepNeedMin != null) c.dataIso: c.sleepNeedMin!};
      final cycleDebtMap = {for (final c in cycles) if (c.sonnoArretratoMinVal != null) c.dataIso: c.sonnoArretratoMinVal!};
      final sleepNeedMap = {for (final s in sleeps) if (s.sleepNeedMin != null) s.dataIso: s.sleepNeedMin!};
      final sleepDebtMap = {for (final s in sleeps) if (s.sleepDebtMin != null) s.dataIso: s.sleepDebtMin!};

      final enrichedCycles = cycles.map((c) {
        final need = c.sleepNeedMin ?? sleepNeedMap[c.dataIso];
        final debt = c.sonnoArretratoMinVal ?? sleepDebtMap[c.dataIso];
        if (need != c.sleepNeedMin || debt != c.sonnoArretratoMinVal) {
          return c.copyWith(
            sleepNeedMin: need,
            sonnoArretratoMin: debt,
          );
        }
        return c;
      }).toList();

      final enrichedSleeps = sleeps.map((s) {
        final need = s.sleepNeedMin ?? cycleNeedMap[s.dataIso];
        final debt = s.sleepDebtMin ?? cycleDebtMap[s.dataIso];
        if (need != s.sleepNeedMin || debt != s.sleepDebtMin) {
          return s.copyWith(
            sleepNeedMin: need,
            sleepDebtMin: debt,
          );
        }
        return s;
      }).toList();

      if (enrichedCycles.isNotEmpty) {
        onProgress?.call(WhoopImportProgress(
          stage: ImportStage.importingCycles,
          message: 'Importazione storico cicli fisiologici (${enrichedCycles.length} cicli)...',
          fraction: 0.35,
          currentCount: enrichedCycles.length,
          totalCount: enrichedCycles.length,
        ));

        final cycleMaps = enrichedCycles.map((c) => c.toMap()).toList();
        await repository.userRepository.getProfile(); // Assicura che DB sia aperto
        await _saveCyclesBatch(cycleMaps);
      }

      // 5. Salvataggio Storico Sonno (Idempotente)
      if (enrichedSleeps.isNotEmpty) {
        onProgress?.call(WhoopImportProgress(
          stage: ImportStage.importingSleeps,
          message: 'Importazione sessioni di sonno (${enrichedSleeps.length} sessioni)...',
          fraction: 0.50,
          currentCount: enrichedSleeps.length,
          totalCount: enrichedSleeps.length,
        ));

        final sleepMaps = enrichedSleeps.map((s) => s.toMap()).toList();
        await _saveSleepsBatch(sleepMaps);
      }

      // 6. Salvataggio Storico Allenamenti (Idempotente)
      if (workouts.isNotEmpty) {
        onProgress?.call(WhoopImportProgress(
          stage: ImportStage.importingWorkouts,
          message: 'Importazione allenamenti (${workouts.length} allenamenti)...',
          fraction: 0.65,
          currentCount: workouts.length,
          totalCount: workouts.length,
        ));

        final workoutMaps = workouts.map((w) => w.toMap()).toList();
        await _saveWorkoutsBatch(workoutMaps);
      }

      // 7. Salvataggio Storico Voci Diario (Idempotente)
      if (diary.isNotEmpty) {
        onProgress?.call(WhoopImportProgress(
          stage: ImportStage.importingDiary,
          message: 'Importazione risposte diario (${diary.length} voci)...',
          fraction: 0.80,
          currentCount: diary.length,
          totalCount: diary.length,
        ));

        final diaryMaps = diary.map((d) => d.toMap()).toList();
        await _saveDiaryBulk(diaryMaps);
      }

      // 8. Calcolo e Inizializzazione Baseline Personali
      onProgress?.call(const WhoopImportProgress(
        stage: ImportStage.calculatingBaselines,
        message: 'Calcolo e inizializzazione baseline personali...',
        fraction: 0.90,
      ));

      // Recupera tutti i cicli e sonni ora salvati nel DB per calcolo completo
      final allCycles = await repository.getCicliFisiologici();
      final allSleeps = await repository.getSonnoLogs();

      final dates = <String>{
        ...allCycles.map((c) => c.dataIso),
        ...allSleeps.map((s) => s.dataIso),
      }.where((d) => d.isNotEmpty).toList()..sort();

      final periodStart = dates.isNotEmpty ? dates.first : '';
      final periodEnd = dates.isNotEmpty ? dates.last : '';
      final calcPeriod = periodStart.isNotEmpty ? '$periodStart → $periodEnd' : '';

      // WHOOP-STYLE ROLLING BASELINE:
      // Calcola la baseline personale sui 30 giorni precedenti l'ultima data disponibile (periodEnd),
      // ESCLUDENDO il giorno di riferimento stesso e rigettando l'intero export di 10 mesi.
      final baselines = BaselineCalculator.calculateRollingBaselines(
        cycles: allCycles,
        sleeps: allSleeps,
        referenceDateIso: periodEnd,
        rollingDays: 30,
      );

      // Persistenza baseline nella tabella personal_baselines
      if (baselines.isNotEmpty) {
        await repository.savePersonalBaselines(baselines.values.toList());
      }

      // 9. Aggiornamento Profilo Utente (Consistenza con Motori Esistenti)
      onProgress?.call(const WhoopImportProgress(
        stage: ImportStage.finalizing,
        message: 'Finalizzazione e aggiornamento profilo...',
        fraction: 0.98,
      ));

      final effectiveUserRepo = userRepository ?? repository.userRepository;
      final currentProfile = await effectiveUserRepo.getProfile() ?? const UtenteProfilo(
        nome: 'Utente WHOOP',
        eta: 30,
        hrMax: 190,
        hrRestBaseline: 55,
        hrvBaselineMean: 65.0,
        hrvBaselineStd: 15.0,
        rhrBaselineMean: 55.0,
        rhrBaselineStd: 3.5,
        sleepBaselineMin: 480,
      );

      final hrvBase = baselines['hrv'];
      final rhrBase = baselines['rhr'];
      final sleepBase = baselines['sleep_duration'];

      final updatedProfile = currentProfile.copyWith(
        hrvBaselineMean: hrvBase != null ? hrvBase.mean : currentProfile.hrvBaselineMean,
        hrvBaselineStd: hrvBase != null ? hrvBase.stdDev : currentProfile.hrvBaselineStd,
        rhrBaselineMean: rhrBase != null ? rhrBase.mean : currentProfile.rhrBaselineMean,
        rhrBaselineStd: rhrBase != null ? rhrBase.stdDev : currentProfile.rhrBaselineStd,
        hrRestBaseline: rhrBase != null ? rhrBase.mean.round() : currentProfile.hrRestBaseline,
        sleepBaselineMin: sleepBase != null ? sleepBase.mean.round().clamp(300, 720) : currentProfile.sleepBaselineMin,
        isBootstrapCompleted: true,
        bootstrapTimestamp: DateTime.now().toIso8601String(),
        bootstrapVersion: 'WHOOP_ARCHIVE_2.0',
        baselineSource: 'WHOOP_EXPORT_ZIP',
        baselineSampleCount: hrvBase?.sampleCount ?? 0,
        baselineCalcPeriod: hrvBase?.calcPeriod ?? calcPeriod,
      );

      await effectiveUserRepo.updateProfile(updatedProfile);

      onProgress?.call(const WhoopImportProgress(
        stage: ImportStage.completed,
        message: 'Importazione completata con successo!',
        fraction: 1.0,
      ));

      return WhoopImportResult(
        success: true,
        cyclesCount: cycles.length,
        sleepsCount: sleeps.length,
        workoutsCount: workouts.length,
        diaryCount: diary.length,
        periodStart: periodStart,
        periodEnd: periodEnd,
        baselines: baselines,
        message: 'Importazione completata:\n'
            '${cycles.length} cicli fisiologici\n'
            '${sleeps.length} sessioni di sonno\n'
            '${workouts.length} allenamenti\n'
            '${diary.length} voci diario\n\n'
            'Periodo importato: $periodStart → $periodEnd\n'
            'Baseline personali inizializzate.',
      );
    } catch (e, st) {
      debugPrint('[WhoopArchiveImporter] Import exception: $e\n$st');
      onProgress?.call(WhoopImportProgress(
        stage: ImportStage.failed,
        message: 'Errore durante l\'importazione: $e',
        fraction: 0.0,
      ));
      return WhoopImportResult(
        success: false,
        message: 'Errore durante l\'importazione dei dati: $e',
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> _saveCyclesBatch(List<Map<String, dynamic>> items) async {
    await DatabaseHelper().saveCicliFisiologiciBatch(items);
  }

  Future<void> _saveSleepsBatch(List<Map<String, dynamic>> items) async {
    await DatabaseHelper().saveSonnoBatch(items);
  }

  Future<void> _saveWorkoutsBatch(List<Map<String, dynamic>> items) async {
    await DatabaseHelper().saveAllenamentiBatch(items);
  }

  Future<void> _saveDiaryBulk(List<Map<String, dynamic>> items) async {
    await DatabaseHelper().saveVociDiarioBulk(items);
  }
}
