import 'package:flutter/foundation.dart';
import '../../core/utils/clock.dart';

/// Modello per la tabella `allenamenti`
/// Schema: id (PK AUTOINCREMENT), data_iso, nome_attivita, ora_inizio, ora_fine, durata_min,
/// hr_media, hr_max, strain_attivita, calorie, zone_z1_pct, zone_z2_pct, zone_z3_pct, zone_z4_pct, zone_z5_pct.
@immutable
class Allenamento {
  final int? id;
  final String dataIso; // YYYY-MM-DD
  final String nomeAttivita;
  final String oraInizio; // ISO 8601 string
  final String oraFine; // ISO 8601 string
  final int durataMin;
  final int? hrMedia;
  final int? hrMax;
  final double? strainAttivita;
  final int? calorie;
  final double? zoneZ1Pct;
  final double? zoneZ2Pct;
  final double? zoneZ3Pct;
  final double? zoneZ4Pct;
  final double? zoneZ5Pct;

  Allenamento({
    this.id,
    String? dataIso,
    DateTime? oraInizioCiclo,
    DateTime? oraFineCiclo,
    String? fusoOrario,
    required this.nomeAttivita,
    String? oraInizio,
    DateTime? oraInizioAllenamento,
    String? oraFine,
    DateTime? oraFineAllenamento,
    dynamic durataMin,
    double? sforzoRichiesto,
    int? energiaBruciataCal,
    int? fcMaxBpm,
    int? fcMediaBpm,
    bool? gpsAbilitato,
    int? hrMedia,
    int? hrMax,
    double? strainAttivita,
    int? calorie,
    this.zoneZ1Pct,
    this.zoneZ2Pct,
    this.zoneZ3Pct,
    this.zoneZ4Pct,
    this.zoneZ5Pct,
  })  : dataIso = dataIso ??
            (oraInizioCiclo != null
                ? oraInizioCiclo.toIso8601String().substring(0, 10)
                : (oraInizioAllenamento != null
                    ? oraInizioAllenamento.toIso8601String().substring(0, 10)
                    : (oraInizio != null && oraInizio.length >= 10
                        ? oraInizio.substring(0, 10)
                        : DateTime.now().toIso8601String().substring(0, 10)))),
        oraInizio = oraInizio ??
            (oraInizioAllenamento?.toIso8601String() ??
                oraInizioCiclo?.toIso8601String() ??
                DateTime.now().toIso8601String()),
        oraFine = oraFine ??
            (oraFineAllenamento?.toIso8601String() ??
                oraFineCiclo?.toIso8601String() ??
                DateTime.now().toIso8601String()),
        durataMin = (durataMin as num?)?.toInt() ?? 0,
        hrMedia = hrMedia ?? fcMediaBpm,
        hrMax = hrMax ?? fcMaxBpm,
        strainAttivita = strainAttivita ?? sforzoRichiesto,
        calorie = calorie ?? energiaBruciataCal;

  // Getters di compatibilità per la UI
  DateTime get oraInizioAllenamento => DateTime.tryParse(oraInizio) ?? Clock.current.now();
  DateTime get oraFineAllenamento => DateTime.tryParse(oraFine) ?? Clock.current.now();
  DateTime get oraInizioCiclo => DateTime.tryParse('${dataIso}T00:00:00.000Z') ?? Clock.current.now();
  DateTime? get oraFineCiclo => DateTime.tryParse('${dataIso}T23:59:59.000Z');
  String get fusoOrario => Clock.current.formattedTimeZoneOffset;
  double? get sforzoRichiesto => strainAttivita;
  int? get energiaBruciataCal => calorie;
  int? get fcMaxBpm => hrMax;
  int? get fcMediaBpm => hrMedia;
  double? get zonaFc1Pct => zoneZ1Pct;
  double? get zonaFc2Pct => zoneZ2Pct;
  double? get zonaFc3Pct => zoneZ3Pct;
  double? get zonaFc4Pct => zoneZ4Pct;
  double? get zonaFc5Pct => zoneZ5Pct;
  bool get gpsAbilitato => true;

  Allenamento copyWith({
    int? id,
    String? dataIso,
    String? nomeAttivita,
    String? oraInizio,
    DateTime? oraInizioAllenamento,
    String? oraFine,
    DateTime? oraFineAllenamento,
    int? durataMin,
    int? hrMedia,
    int? hrMax,
    double? strainAttivita,
    int? calorie,
    double? zoneZ1Pct,
    double? zoneZ2Pct,
    double? zoneZ3Pct,
    double? zoneZ4Pct,
    double? zoneZ5Pct,
  }) {
    return Allenamento(
      id: id ?? this.id,
      dataIso: dataIso ?? this.dataIso,
      nomeAttivita: nomeAttivita ?? this.nomeAttivita,
      oraInizio: oraInizio ?? (oraInizioAllenamento?.toIso8601String() ?? this.oraInizio),
      oraFine: oraFine ?? (oraFineAllenamento?.toIso8601String() ?? this.oraFine),
      durataMin: durataMin ?? this.durataMin,
      hrMedia: hrMedia ?? this.hrMedia,
      hrMax: hrMax ?? this.hrMax,
      strainAttivita: strainAttivita ?? this.strainAttivita,
      calorie: calorie ?? this.calorie,
      zoneZ1Pct: zoneZ1Pct ?? this.zoneZ1Pct,
      zoneZ2Pct: zoneZ2Pct ?? this.zoneZ2Pct,
      zoneZ3Pct: zoneZ3Pct ?? this.zoneZ3Pct,
      zoneZ4Pct: zoneZ4Pct ?? this.zoneZ4Pct,
      zoneZ5Pct: zoneZ5Pct ?? this.zoneZ5Pct,
    );
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'data_iso': dataIso,
      'nome_attivita': nomeAttivita,
      'ora_inizio': oraInizio,
      'ora_fine': oraFine,
      'durata_min': durataMin,
      'hr_media': hrMedia,
      'hr_max': hrMax,
      'strain_attivita': strainAttivita,
      'calorie': calorie,
      'zone_z1_pct': zoneZ1Pct,
      'zone_z2_pct': zoneZ2Pct,
      'zone_z3_pct': zoneZ3Pct,
      'zone_z4_pct': zoneZ4Pct,
      'zone_z5_pct': zoneZ5Pct,
    };
    if (id != null) map['id'] = id;
    return map;
  }

  factory Allenamento.fromMap(Map<String, dynamic> map) {
    String dIso = map['data_iso'] as String? ?? '';
    if (dIso.isEmpty && map['ora_inizio_allenamento'] != null) {
      dIso = (map['ora_inizio_allenamento'] as String).substring(0, 10);
    } else if (dIso.isEmpty && map['ora_inizio'] != null) {
      dIso = (map['ora_inizio'] as String).substring(0, 10);
    } else if (dIso.isEmpty) {
      dIso = DateTime.now().toIso8601String().substring(0, 10);
    }

    return Allenamento(
      id: map['id'] as int?,
      dataIso: dIso,
      nomeAttivita: map['nome_attivita'] as String? ?? 'Attività',
      oraInizio: map['ora_inizio'] as String? ?? map['ora_inizio_allenamento'] as String? ?? DateTime.now().toIso8601String(),
      oraFine: map['ora_fine'] as String? ?? map['ora_fine_allenamento'] as String? ?? DateTime.now().toIso8601String(),
      durataMin: (map['durata_min'] as num?)?.toInt() ?? 0,
      hrMedia: (map['hr_media'] ?? map['fc_media_bpm'] as num?)?.toInt(),
      hrMax: (map['hr_max'] ?? map['fc_max_bpm'] as num?)?.toInt(),
      strainAttivita: (map['strain_attivita'] ?? map['sforzo_richiesto'] as num?)?.toDouble(),
      calorie: (map['calorie'] ?? map['energia_bruciata_cal'] as num?)?.toInt(),
      zoneZ1Pct: (map['zone_z1_pct'] ?? map['zona_fc_1_pct'] as num?)?.toDouble(),
      zoneZ2Pct: (map['zone_z2_pct'] ?? map['zona_fc_2_pct'] as num?)?.toDouble(),
      zoneZ3Pct: (map['zone_z3_pct'] ?? map['zona_fc_3_pct'] as num?)?.toDouble(),
      zoneZ4Pct: (map['zone_z4_pct'] ?? map['zona_fc_4_pct'] as num?)?.toDouble(),
      zoneZ5Pct: (map['zone_z5_pct'] ?? map['zona_fc_5_pct'] as num?)?.toDouble(),
    );
  }
}
