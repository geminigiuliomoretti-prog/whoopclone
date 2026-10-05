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
  final String provenance; // REAL, BOOTSTRAP, MANUAL

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
  bool get riposoBreve => false;

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
      provenance: map['provenance'] as String? ?? 'REAL',
    );
  }
}
