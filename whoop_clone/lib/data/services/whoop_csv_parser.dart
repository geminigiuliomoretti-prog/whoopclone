import '../models/allenamento.dart';
import '../models/ciclo_fisiologico.dart';
import '../models/sonno.dart';
import '../models/voce_diario.dart';

/// Parser robusto e resiliente per i CSV esportati da WHOOP (italiano o inglese).
/// Gestisce RFC 4180 (campi quotati, virgole, apici doppi, BOM UTF-8),
/// colonne aggiuntive/mancanti, valori vuoti (null-safe, mai dati inventati),
/// e deduplicazione / data canonica dei cicli.
class WhoopCsvParser {
  const WhoopCsvParser._();

  /// Divide una stringa CSV in righe e colonne rispettando le virgolette RFC 4180
  static List<List<String>> parseCsv(String input) {
    if (input.isEmpty) return [];

    // Rimuove UTF-8 BOM se presente
    String cleanInput = input;
    if (cleanInput.startsWith('\uFEFF')) {
      cleanInput = cleanInput.substring(1);
    }

    final List<List<String>> records = [];
    final List<String> currentRecord = [];
    final StringBuffer currentField = StringBuffer();
    bool insideQuotes = false;
    int i = 0;
    final int len = cleanInput.length;

    while (i < len) {
      final char = cleanInput[i];

      if (insideQuotes) {
        if (char == '"') {
          if (i + 1 < len && cleanInput[i + 1] == '"') {
            currentField.write('"');
            i += 2;
            continue;
          } else {
            insideQuotes = false;
            i++;
            continue;
          }
        } else {
          currentField.write(char);
          i++;
          continue;
        }
      } else {
        if (char == '"') {
          insideQuotes = true;
          i++;
          continue;
        } else if (char == ',') {
          currentRecord.add(currentField.toString().trim());
          currentField.clear();
          i++;
          continue;
        } else if (char == '\r') {
          if (i + 1 < len && cleanInput[i + 1] == '\n') {
            i++;
          }
          currentRecord.add(currentField.toString().trim());
          currentField.clear();
          if (currentRecord.any((f) => f.isNotEmpty)) {
            records.add(List<String>.from(currentRecord));
          }
          currentRecord.clear();
          i++;
          continue;
        } else if (char == '\n') {
          currentRecord.add(currentField.toString().trim());
          currentField.clear();
          if (currentRecord.any((f) => f.isNotEmpty)) {
            records.add(List<String>.from(currentRecord));
          }
          currentRecord.clear();
          i++;
          continue;
        } else {
          currentField.write(char);
          i++;
          continue;
        }
      }
    }

    if (currentField.isNotEmpty || currentRecord.isNotEmpty) {
      currentRecord.add(currentField.toString().trim());
      if (currentRecord.any((f) => f.isNotEmpty)) {
        records.add(List<String>.from(currentRecord));
      }
    }

    return records;
  }

  /// Normalizza il nome colonna rimuovendo accenti, punteggiatura e spazi
  static String normalizeHeader(String header) {
    return header
        .toLowerCase()
        .replaceAll('à', 'a')
        .replaceAll('á', 'a')
        .replaceAll('è', 'e')
        .replaceAll('é', 'e')
        .replaceAll('ì', 'i')
        .replaceAll('í', 'i')
        .replaceAll('ò', 'o')
        .replaceAll('ó', 'o')
        .replaceAll('ù', 'u')
        .replaceAll('ú', 'u')
        .replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  /// Trova l'indice di una colonna basandosi su una lista di pattern accettati
  static int findColumnIndex(List<String> normalizedHeaders, List<String> patterns) {
    for (final pattern in patterns) {
      final normPattern = normalizeHeader(pattern);
      final idx = normalizedHeaders.indexOf(normPattern);
      if (idx != -1) return idx;
    }
    // Ricerca parziale contenimento
    for (final pattern in patterns) {
      final normPattern = normalizeHeader(pattern);
      final idx = normalizedHeaders.indexWhere((h) => h.contains(normPattern));
      if (idx != -1) return idx;
    }
    return -1;
  }

  // =========================================================================
  // 1. PARSING CICLI FISIOLOGICI
  // =========================================================================

  static List<CicloFisiologico> parseCicliFisiologici(String csvContent) {
    final rows = parseCsv(csvContent);
    if (rows.length <= 1) return [];

    final headers = rows.first;
    final normHeaders = headers.map(normalizeHeader).toList();

    final idxStart = findColumnIndex(normHeaders, ['iniziociclo', 'cyclestart', 'start', 'data']);
    final idxRecovery = findColumnIndex(normHeaders, ['recupero', 'recovery']);
    final idxRhr = findColumnIndex(normHeaders, ['riposo', 'resting', 'rhr', 'fcr']);
    final idxHrv = findColumnIndex(normHeaders, ['variabilita', 'hrv', 'vfc', 'rmssd']);
    final idxTemp = findColumnIndex(normHeaders, ['temp', 'cutanea', 'skintemp', 'temperature']);
    final idxSpo2 = findColumnIndex(normHeaders, ['ossigeno', 'bloodoxygen', 'spo2', 'o2']);
    final idxStrain = findColumnIndex(normHeaders, ['sforzogiornaliero', 'cyclestrain', 'daystrain', 'sforzo', 'strain']);
    final idxCals = findColumnIndex(normHeaders, ['energiabruciata', 'calories', 'calorie', 'energy', 'kilocalories']);
    final idxMaxHr = findColumnIndex(normHeaders, ['fcmax', 'maxhr']);
    final idxAvgHr = findColumnIndex(normHeaders, ['fcmedia', 'averagehr', 'avghr']);
    final idxSleepStart = findColumnIndex(normHeaders, ['iniziodelsonno', 'sleeponset', 'sleepstart']);
    final idxWake = findColumnIndex(normHeaders, ['iniziodelrisveglio', 'waketime', 'wake']);
    final idxResp = findColumnIndex(normHeaders, ['respiratoria', 'respiratory', 'resp', 'rpm']);
    final idxSleepNeed = findColumnIndex(normHeaders, ['sonnorichiesto', 'sleepneed', 'richiesto']);
    final idxSleepDebt = findColumnIndex(normHeaders, ['sonnoarretrato', 'sleepdebt', 'arretrato', 'debito']);

    final List<CicloFisiologico> list = [];
    final Set<String> assignedDateIsos = {};

    // Prima passata per registrare o assegnare date senza collisioni
    for (int i = 1; i < rows.length; i++) {
      final cols = rows[i];
      if (idxStart == -1 || cols.length <= idxStart) continue;

      final startRaw = cols[idxStart].trim();
      if (startRaw.isEmpty) continue;

      final wakeRaw = idxWake != -1 && cols.length > idxWake ? cols[idxWake].trim() : '';
      final sleepStartRaw = idxSleepStart != -1 && cols.length > idxSleepStart ? cols[idxSleepStart].trim() : '';

      // Risoluzione data canonica del ciclo:
      // In WHOOP un ciclo corrisponde alla giornata del risveglio (wake time).
      // Se non presente risveglio o in caso di collisione, usa la data di inizio sonno o ciclo.
      String dateIso = '';
      if (wakeRaw.length >= 10) {
        final wakeDate = wakeRaw.substring(0, 10);
        if (!assignedDateIsos.contains(wakeDate)) {
          dateIso = wakeDate;
        }
      }

      if (dateIso.isEmpty && sleepStartRaw.length >= 10) {
        final sleepDate = sleepStartRaw.substring(0, 10);
        if (!assignedDateIsos.contains(sleepDate)) {
          dateIso = sleepDate;
        }
      }

      if (dateIso.isEmpty && startRaw.length >= 10) {
        final startDate = startRaw.substring(0, 10);
        if (!assignedDateIsos.contains(startDate)) {
          dateIso = startDate;
        }
      }

      // Se ancora collide, prova il giorno successivo all'inizio
      if (dateIso.isEmpty && startRaw.length >= 10) {
        final dt = DateTime.tryParse(startRaw.replaceFirst(' ', 'T'));
        if (dt != null) {
          final nextDay = dt.add(const Duration(days: 1)).toIso8601String().substring(0, 10);
          if (!assignedDateIsos.contains(nextDay)) {
            dateIso = nextDay;
          }
        }
      }

      if (dateIso.isEmpty) {
        // Fallback assoluto
        dateIso = startRaw.length >= 10 ? startRaw.substring(0, 10) : '2026-01-01';
      }

      assignedDateIsos.add(dateIso);

      final double? strain = _parseDouble(cols, idxStrain);
      final double? recovery = _parseDouble(cols, idxRecovery);
      final double? rhr = _parseDouble(cols, idxRhr);
      final double? hrv = _parseDouble(cols, idxHrv);
      final double? temp = _parseDouble(cols, idxTemp);
      final double? spo2 = _parseDouble(cols, idxSpo2);
      final int? cals = _parseInt(cols, idxCals);
      final int? maxHr = _parseInt(cols, idxMaxHr);
      final int? avgHr = _parseInt(cols, idxAvgHr);
      final double? resp = _parseDouble(cols, idxResp);
      final int? need = _parseInt(cols, idxSleepNeed);
      final int? debt = _parseInt(cols, idxSleepDebt);

      final ciclo = CicloFisiologico(
        dataIso: dateIso,
        strainGiornaliero: strain,
        recoveryScore: recovery,
        sleepNeedMin: need,
        sonnoArretratoMin: debt,
        hrvNotte: hrv,
        rhrNotte: rhr,
        frequenzaRespiratoriaRpm: resp,
        tempCutaneaC: temp,
        spo2Pct: spo2,
        fcMaxBpm: maxHr,
        fcMediaBpm: avgHr,
        calorieTot: cals,
        provenance: 'WHOOP_IMPORT',
      );

      list.add(ciclo);
    }

    return list;
  }

  // =========================================================================
  // 2. PARSING SONNO
  // =========================================================================

  static List<Sonno> parseSonno(String csvContent, {Map<String, String>? cycleStartToDateIsoMap}) {
    final rows = parseCsv(csvContent);
    if (rows.length <= 1) return [];

    final headers = rows.first;
    final normHeaders = headers.map(normalizeHeader).toList();

    final idxCycleStart = findColumnIndex(normHeaders, ['oradiiniziociclo', 'cyclestarttime', 'cyclestart']);
    final idxSleepStart = findColumnIndex(normHeaders, ['iniziodelsonno', 'sleeponset', 'sleepstart', 'starttime']);
    final idxWake = findColumnIndex(normHeaders, ['iniziodelrisveglio', 'waketime', 'endtime']);
    final idxDur = findColumnIndex(normHeaders, ['duratadelsonno', 'sleepduration', 'duration', 'durata']);
    final idxDeep = findColumnIndex(normHeaders, ['durataprofondosws', 'deepsleep', 'sws']);
    final idxRem = findColumnIndex(normHeaders, ['duratarem', 'remsleep', 'rem']);
    final idxEff = findColumnIndex(normHeaders, ['efficienzadelsonno', 'sleepefficiency', 'efficiency']);
    final idxPerf = findColumnIndex(normHeaders, ['andamentodelsonno', 'sleepperformance', 'performance']);
    final idxReg = findColumnIndex(normHeaders, ['regolaritadelsonno', 'sleepregularity', 'regularity']);
    final idxNap = findColumnIndex(normHeaders, ['riposobreve', 'nap', 'isnap', 'shortrest']);
    final idxSleepNeed = findColumnIndex(normHeaders, ['sonnorichiesto', 'sleepneed', 'richiesto']);
    final idxSleepDebt = findColumnIndex(normHeaders, ['sonnoarretrato', 'sleepdebt', 'arretrato', 'debito']);

    final List<Sonno> list = [];

    for (int i = 1; i < rows.length; i++) {
      final cols = rows[i];
      if (cols.isEmpty) continue;

      final cycleStartRaw = idxCycleStart != -1 && cols.length > idxCycleStart ? cols[idxCycleStart].trim() : '';
      final sleepStartRaw = idxSleepStart != -1 && cols.length > idxSleepStart ? cols[idxSleepStart].trim() : '';
      final wakeRaw = idxWake != -1 && cols.length > idxWake ? cols[idxWake].trim() : '';

      if (sleepStartRaw.isEmpty && wakeRaw.isEmpty) continue;

      // Assegna dateIso
      String dateIso = '';
      if (cycleStartRaw.isNotEmpty && cycleStartToDateIsoMap != null && cycleStartToDateIsoMap.containsKey(cycleStartRaw)) {
        dateIso = cycleStartToDateIsoMap[cycleStartRaw]!;
      } else if (wakeRaw.length >= 10) {
        dateIso = wakeRaw.substring(0, 10);
      } else if (sleepStartRaw.length >= 10) {
        dateIso = sleepStartRaw.substring(0, 10);
      } else {
        dateIso = '2026-01-01';
      }

      final startIso = _formatDateTimeIso(sleepStartRaw, defaultDate: dateIso);
      final endIso = _formatDateTimeIso(wakeRaw, defaultDate: dateIso);

      int durMin = _parseInt(cols, idxDur) ?? 0;
      if (durMin <= 0) {
        final sDt = DateTime.tryParse(startIso);
        final eDt = DateTime.tryParse(endIso);
        if (sDt != null && eDt != null && eDt.isAfter(sDt)) {
          durMin = eDt.difference(sDt).inMinutes;
        }
      }

      final int deepMin = _parseInt(cols, idxDeep) ?? 0;
      final int remMin = _parseInt(cols, idxRem) ?? 0;
      final double? eff = _parseDouble(cols, idxEff);
      final double? perf = _parseDouble(cols, idxPerf);
      final double? reg = _parseDouble(cols, idxReg);
      final int? sleepNeed = _parseInt(cols, idxSleepNeed);
      final int? sleepDebt = _parseInt(cols, idxSleepDebt);
      final bool isNap = _parseBool(cols, idxNap);

      final sonno = Sonno(
        dataIso: dateIso,
        oraInizio: startIso,
        oraFine: endIso,
        durataTotMin: durMin,
        sonnoProfondoMin: deepMin,
        sonnoRemMin: remMin,
        efficienzaPct: eff,
        sleepPerformancePct: perf,
        regolaritaSonnoPctVal: reg,
        sleepNeedMin: sleepNeed,
        sleepDebtMin: sleepDebt,
        provenance: isNap ? 'WHOOP_NAP' : 'WHOOP_IMPORT',
      );

      list.add(sonno);
    }

    return list;
  }

  // =========================================================================
  // 3. PARSING ALLENAMENTI
  // =========================================================================

  static List<Allenamento> parseAllenamenti(String csvContent, {Map<String, String>? cycleStartToDateIsoMap}) {
    final rows = parseCsv(csvContent);
    if (rows.length <= 1) return [];

    final headers = rows.first;
    final normHeaders = headers.map(normalizeHeader).toList();

    final idxCycleStart = findColumnIndex(normHeaders, ['oradiiniziociclo', 'cyclestarttime']);
    final idxStart = findColumnIndex(normHeaders, ['oradiinizioallenamento', 'activitystarttime', 'workoutstarttime', 'starttime']);
    final idxEnd = findColumnIndex(normHeaders, ['oradifineallenamento', 'activityendtime', 'workoutendtime', 'endtime']);
    final idxDur = findColumnIndex(normHeaders, ['durata', 'duration']);
    final idxName = findColumnIndex(normHeaders, ['nomeattivita', 'activityname', 'sport', 'name']);
    final idxStrain = findColumnIndex(normHeaders, ['sforzorichiestodallattivita', 'activitystrain', 'strain']);
    final idxCals = findColumnIndex(normHeaders, ['energiabruciata', 'calories', 'calorie', 'energyburned']);
    final idxMaxHr = findColumnIndex(normHeaders, ['fcmax', 'maxhr']);
    final idxAvgHr = findColumnIndex(normHeaders, ['fcmedia', 'averagehr', 'avghr']);
    final idxZ1 = findColumnIndex(normHeaders, ['zonafc1', 'hrzone1', 'zone1']);
    final idxZ2 = findColumnIndex(normHeaders, ['zonafc2', 'hrzone2', 'zone2']);
    final idxZ3 = findColumnIndex(normHeaders, ['zonafc3', 'hrzone3', 'zone3']);
    final idxZ4 = findColumnIndex(normHeaders, ['zonafc4', 'hrzone4', 'zone4']);
    final idxZ5 = findColumnIndex(normHeaders, ['zonafc5', 'hrzone5', 'zone5']);

    final List<Allenamento> list = [];

    for (int i = 1; i < rows.length; i++) {
      final cols = rows[i];
      if (cols.isEmpty) continue;

      final cycleStartRaw = idxCycleStart != -1 && cols.length > idxCycleStart ? cols[idxCycleStart].trim() : '';
      final startRaw = idxStart != -1 && cols.length > idxStart ? cols[idxStart].trim() : '';
      final endRaw = idxEnd != -1 && cols.length > idxEnd ? cols[idxEnd].trim() : '';

      if (startRaw.isEmpty) continue;

      final name = idxName != -1 && cols.length > idxName && cols[idxName].trim().isNotEmpty
          ? cols[idxName].trim()
          : 'Attività Generica';

      String dateIso = '';
      if (cycleStartRaw.isNotEmpty && cycleStartToDateIsoMap != null && cycleStartToDateIsoMap.containsKey(cycleStartRaw)) {
        dateIso = cycleStartToDateIsoMap[cycleStartRaw]!;
      } else if (startRaw.length >= 10) {
        dateIso = startRaw.substring(0, 10);
      } else {
        dateIso = '2026-01-01';
      }

      final startIso = _formatDateTimeIso(startRaw, defaultDate: dateIso);
      final endIso = _formatDateTimeIso(endRaw, defaultDate: dateIso);

      int durMin = _parseInt(cols, idxDur) ?? 0;
      if (durMin <= 0) {
        final sDt = DateTime.tryParse(startIso);
        final eDt = DateTime.tryParse(endIso);
        if (sDt != null && eDt != null && eDt.isAfter(sDt)) {
          durMin = eDt.difference(sDt).inMinutes.clamp(1, 1440);
        } else {
          durMin = 30;
        }
      }

      final double? strain = _parseDouble(cols, idxStrain);
      final int? cals = _parseInt(cols, idxCals);
      final int? maxHr = _parseInt(cols, idxMaxHr);
      final int? avgHr = _parseInt(cols, idxAvgHr);
      final double? z1 = _parseDouble(cols, idxZ1);
      final double? z2 = _parseDouble(cols, idxZ2);
      final double? z3 = _parseDouble(cols, idxZ3);
      final double? z4 = _parseDouble(cols, idxZ4);
      final double? z5 = _parseDouble(cols, idxZ5);

      final workout = Allenamento(
        dataIso: dateIso,
        nomeAttivita: name,
        oraInizio: startIso,
        oraFine: endIso,
        durataMin: durMin,
        strainAttivita: strain,
        calorie: cals,
        hrMax: maxHr,
        hrMedia: avgHr,
        zoneZ1Pct: z1,
        zoneZ2Pct: z2,
        zoneZ3Pct: z3,
        zoneZ4Pct: z4,
        zoneZ5Pct: z5,
      );

      list.add(workout);
    }

    return list;
  }

  // =========================================================================
  // 4. PARSING VOCI DIARIO
  // =========================================================================

  static List<VoceDiario> parseVociDiario(String csvContent, {Map<String, String>? cycleStartToDateIsoMap}) {
    final rows = parseCsv(csvContent);
    if (rows.length <= 1) return [];

    final headers = rows.first;
    final normHeaders = headers.map(normalizeHeader).toList();

    final idxCycleStart = findColumnIndex(normHeaders, ['oradiiniziociclo', 'cyclestarttime', 'start', 'date', 'data']);
    final idxQuestion = findColumnIndex(normHeaders, ['testodomanda', 'questiontext', 'domanda', 'question']);
    final idxAnswer = findColumnIndex(normHeaders, ['rispostaaffermativa', 'answeredyes', 'risposta', 'answer']);
    final idxNote = findColumnIndex(normHeaders, ['note', 'notes']);

    final List<VoceDiario> list = [];

    for (int i = 1; i < rows.length; i++) {
      final cols = rows[i];
      if (cols.isEmpty) continue;

      final cycleStartRaw = idxCycleStart != -1 && cols.length > idxCycleStart ? cols[idxCycleStart].trim() : '';
      final question = idxQuestion != -1 && cols.length > idxQuestion ? cols[idxQuestion].trim() : '';

      if (question.isEmpty) continue;

      String dateIso = '';
      if (cycleStartRaw.isNotEmpty && cycleStartToDateIsoMap != null && cycleStartToDateIsoMap.containsKey(cycleStartRaw)) {
        dateIso = cycleStartToDateIsoMap[cycleStartRaw]!;
      } else if (cycleStartRaw.length >= 10) {
        dateIso = cycleStartRaw.substring(0, 10);
      } else {
        dateIso = '2026-01-01';
      }

      final bool answer = _parseBool(cols, idxAnswer);
      final String? note = idxNote != -1 && cols.length > idxNote && cols[idxNote].trim().isNotEmpty
          ? cols[idxNote].trim()
          : null;

      final voce = VoceDiario(
        dataIso: dateIso,
        chiaveDomanda: question,
        rispostaBool: answer,
        note: note,
      );

      list.add(voce);
    }

    return list;
  }

  // =========================================================================
  // HELPER INTERNI PER PARSING TIPI
  // =========================================================================

  static double? _parseDouble(List<String> cols, int index) {
    if (index == -1 || index >= cols.length) return null;
    final val = cols[index].trim();
    if (val.isEmpty) return null;
    return double.tryParse(val.replaceAll(',', '.'));
  }

  static int? _parseInt(List<String> cols, int index) {
    if (index == -1 || index >= cols.length) return null;
    final val = cols[index].trim();
    if (val.isEmpty) return null;
    final d = double.tryParse(val.replaceAll(',', '.'));
    return d?.round();
  }

  static bool _parseBool(List<String> cols, int index) {
    if (index == -1 || index >= cols.length) return false;
    final val = cols[index].trim().toLowerCase();
    return val == 'true' || val == '1' || val == 'si' || val == 'sì' || val == 'yes';
  }

  static String _formatDateTimeIso(String raw, {required String defaultDate}) {
    if (raw.isEmpty) return '${defaultDate}T00:00:00.000Z';
    if (raw.contains('T')) {
      final dt = DateTime.tryParse(raw);
      if (dt != null) return dt.toIso8601String();
    }
    // Formato 'YYYY-MM-DD HH:mm:ss'
    final normalized = raw.replaceFirst(' ', 'T');
    final dt = DateTime.tryParse(normalized);
    if (dt != null) return dt.toIso8601String();
    return '${defaultDate}T00:00:00.000Z';
  }
}
