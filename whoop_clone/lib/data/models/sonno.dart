import 'package:flutter/foundation.dart';
import '../../core/utils/clock.dart';

/// Modello per la tabella `sonno`
/// Schema: id (PK AUTOINCREMENT), data_iso, ora_inizio, ora_fine, durata_tot_min,
/// sonno_profondo_min, sonno_rem_min, efficienza_pct, sleep_performance_pct.
@immutable
class Sonno {
  final int? id;
  final String dataIso; // YYYY-MM-DD
  final String oraInizio; // ISO 8601 string
  final String oraFine; // ISO 8601 string
  final int durataTotMin;
  final int sonnoProfondoMin;
  final int sonnoRemMin;
  final double? efficienzaPct;
  final double? sleepPerformancePct;
  final double? regolaritaSonnoPctVal;
  final int? sleepNeedMin;
  final int? sleepDebtMin;
  final String provenance; // REAL, BOOTSTRAP, MANUAL

  /// Percentuale effettiva ore dormite rispetto al bisogno calcolato per questa sessione
  double? get actualVsNeededPct {
    if (durataTotMin <= 0 || sleepNeedMin == null || sleepNeedMin! <= 0) return null;
    final pct = (durataTotMin / sleepNeedMin!) * 100.0;
    return double.parse(pct.clamp(0.0, 100.0).toStringAsFixed(1));
  }

  const Sonno({
    this.id,
    required this.dataIso,
    required this.oraInizio,
    required this.oraFine,
    required this.durataTotMin,
    required this.sonnoProfondoMin,
    required this.sonnoRemMin,
    this.efficienzaPct,
    this.sleepPerformancePct,
    this.regolaritaSonnoPctVal,
    this.sleepNeedMin,
    this.sleepDebtMin,
    this.provenance = 'REAL',
  });

  // Getters di compatibilità per la UI
  DateTime get inizioSonno => DateTime.tryParse(oraInizio) ?? Clock.current.now();
  DateTime get inizioRisveglio => DateTime.tryParse(oraFine) ?? Clock.current.now();
  DateTime get oraInizioCiclo => DateTime.tryParse('${dataIso}T00:00:00.000Z') ?? Clock.current.now();
  DateTime? get oraFineCiclo => DateTime.tryParse('${dataIso}T23:59:59.000Z');
  String get fusoOrario => Clock.current.formattedTimeZoneOffset;
  double? get durataSonnoMin => durataTotMin.toDouble();
  double? get sonnoLeggeroMin => (provenance == 'USER_ENTERED' || provenance == 'MANUAL')
      ? 0.0
      : (durataTotMin - sonnoProfondoMin - sonnoRemMin).clamp(0, 9999).toDouble();
  double? get sonnoProfondoMinDouble => sonnoProfondoMin.toDouble();
  double? get sonnoRemMinDouble => sonnoRemMin.toDouble();
  double? get efficienzaSonnoPct => efficienzaPct;
  double? get andamentoSonnoPct => sleepPerformancePct;
  double? get regolaritaSonnoPct => regolaritaSonnoPctVal;
  double? get sonnoRichiestoMin => sleepNeedMin?.toDouble();
  double? get sonnoArretratoMin => sleepDebtMin?.toDouble();
  bool get riposoBreve {
    if (provenance == 'WHOOP_NAP') return true;
    if (durataTotMin > 0 && durataTotMin < 180) {
      final startLocal = inizioSonno.toLocal();
      if (startLocal.hour >= 9 && startLocal.hour <= 20) return true;
    }
    return false;
  }

  int get tempoALettoMin {
    final start = DateTime.tryParse(oraInizio);
    final end = DateTime.tryParse(oraFine);
    if (start != null && end != null && end.isAfter(start)) {
      return end.difference(start).inMinutes;
    }
    return durataTotMin;
  }

  double get vegliaMin {
    final diff = tempoALettoMin - durataTotMin;
    return diff > 0 ? diff.toDouble() : 0.0;
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'data_iso': dataIso,
      'ora_inizio': oraInizio,
      'ora_fine': oraFine,
      'durata_tot_min': durataTotMin,
      'sonno_profondo_min': sonnoProfondoMin,
      'sonno_rem_min': sonnoRemMin,
      'efficienza_pct': efficienzaPct,
      'sleep_performance_pct': sleepPerformancePct,
      'regolarita_sonno_pct': regolaritaSonnoPctVal,
      if (sleepNeedMin != null) 'sleep_need_min': sleepNeedMin,
      if (sleepDebtMin != null) 'sleep_debt_min': sleepDebtMin,
      'provenance': provenance,
    };
    if (id != null) map['id'] = id;
    return map;
  }

  factory Sonno.fromMap(Map<String, dynamic> map) {
    String dIso = map['data_iso'] as String? ?? '';
    if (dIso.isEmpty && map['inizio_sonno'] != null) {
      dIso = (map['inizio_sonno'] as String).substring(0, 10);
    } else if (dIso.isEmpty && map['ora_inizio'] != null) {
      dIso = (map['ora_inizio'] as String).substring(0, 10);
    } else if (dIso.isEmpty) {
      dIso = DateTime.now().toIso8601String().substring(0, 10);
    }

    return Sonno(
      id: map['id'] as int?,
      dataIso: dIso,
      oraInizio: map['ora_inizio'] as String? ?? map['inizio_sonno'] as String? ?? DateTime.now().toIso8601String(),
      oraFine: map['ora_fine'] as String? ?? map['inizio_risveglio'] as String? ?? DateTime.now().toIso8601String(),
      durataTotMin: (map['durata_tot_min'] ?? map['durata_sonno_min'] as num?)?.toInt() ?? 0,
      sonnoProfondoMin: (map['sonno_profondo_min'] as num?)?.toInt() ?? 0,
      sonnoRemMin: (map['sonno_rem_min'] as num?)?.toInt() ?? 0,
      efficienzaPct: (map['efficienza_pct'] ?? map['efficienza_sonno_pct'] as num?)?.toDouble(),
      sleepPerformancePct: (map['sleep_performance_pct'] ?? map['andamento_sonno_pct'] as num?)?.toDouble(),
      regolaritaSonnoPctVal: (map['regolarita_sonno_pct'] as num?)?.toDouble(),
      sleepNeedMin: (map['sleep_need_min'] ?? map['sonno_richiesto_min'] as num?)?.toInt(),
      sleepDebtMin: (map['sleep_debt_min'] ?? map['sonno_arretrato_min'] as num?)?.toInt(),
      provenance: map['provenance'] as String? ?? 'REAL',
    );
  }

  Sonno copyWith({
    int? id,
    String? dataIso,
    String? oraInizio,
    String? oraFine,
    int? durataTotMin,
    int? sonnoProfondoMin,
    int? sonnoRemMin,
    double? efficienzaPct,
    double? sleepPerformancePct,
    double? regolaritaSonnoPctVal,
    int? sleepNeedMin,
    int? sleepDebtMin,
    String? provenance,
  }) {
    return Sonno(
      id: id ?? this.id,
      dataIso: dataIso ?? this.dataIso,
      oraInizio: oraInizio ?? this.oraInizio,
      oraFine: oraFine ?? this.oraFine,
      durataTotMin: durataTotMin ?? this.durataTotMin,
      sonnoProfondoMin: sonnoProfondoMin ?? this.sonnoProfondoMin,
      sonnoRemMin: sonnoRemMin ?? this.sonnoRemMin,
      efficienzaPct: efficienzaPct ?? this.efficienzaPct,
      sleepPerformancePct: sleepPerformancePct ?? this.sleepPerformancePct,
      regolaritaSonnoPctVal: regolaritaSonnoPctVal ?? this.regolaritaSonnoPctVal,
      sleepNeedMin: sleepNeedMin ?? this.sleepNeedMin,
      sleepDebtMin: sleepDebtMin ?? this.sleepDebtMin,
      provenance: provenance ?? this.provenance,
    );
  }
}
