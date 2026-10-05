import 'package:flutter/foundation.dart';
import '../../core/utils/clock.dart';

/// Modello per la tabella `cicli_fisiologici` (Single Source of Truth per la UI)
/// Schema: data_iso (PK YYYY-MM-DD), strain_giornaliero, recovery_score, sleep_need_min,
/// hrv_notte, rhr_notte, frequenza_respiratoria_rpm, temp_cutanea_c, spo2_pct, fc_max_bpm, fc_media_bpm, calorie_tot.
@immutable
class CicloFisiologico {
  final String dataIso; // PK (YYYY-MM-DD)
  final double? strainGiornaliero;
  final double? recoveryScore;
  final int? sleepNeedMin;
  final double? hrvNotte;
  final double? rhrNotte;
  final double? frequenzaRespiratoriaRpmVal;
  final double? tempCutaneaCVal;
  final double? spo2PctVal;
  final int? fcMaxBpmVal;
  final int? fcMediaBpmVal;
  final int? calorieTot;
  final double? valoreStressNotteVal;
  final String provenance; // REAL, DERIVED, BOOTSTRAP, CACHED, MANUAL

  const CicloFisiologico({
    required this.dataIso,
    this.strainGiornaliero,
    this.recoveryScore,
    this.sleepNeedMin,
    this.hrvNotte,
    this.rhrNotte,
    double? frequenzaRespiratoriaRpm,
    double? tempCutaneaC,
    double? spo2Pct,
    int? fcMaxBpm,
    int? fcMediaBpm,
    this.calorieTot,
    double? valoreStressNotte,
    this.provenance = 'REAL',
  })  : frequenzaRespiratoriaRpmVal = frequenzaRespiratoriaRpm,
        tempCutaneaCVal = tempCutaneaC,
        spo2PctVal = spo2Pct,
        fcMaxBpmVal = fcMaxBpm,
        fcMediaBpmVal = fcMediaBpm,
        valoreStressNotteVal = valoreStressNotte;

  // Getters di compatibilità per la UI
  DateTime get oraInizioCiclo {
    try {
      return DateTime.parse('${dataIso}T00:00:00.000Z');
    } catch (e) {
      debugPrint('[CicloFisiologico] Error parsing oraInizioCiclo from dataIso "$dataIso": $e');
      return Clock.current.now();
    }
  }

  DateTime? get oraFineCiclo {
    try {
      return DateTime.parse('${dataIso}T23:59:59.000Z');
    } catch (e) {
      debugPrint('[CicloFisiologico] Error parsing oraFineCiclo from dataIso "$dataIso": $e');
      return null;
    }
  }

  String get fusoOrario => Clock.current.formattedTimeZoneOffset;
  double? get sforzoGiornaliero => strainGiornaliero;
  double? get punteggioRecuperoPct => recoveryScore;
  double? get sonnoRichiestoMin => sleepNeedMin?.toDouble();
  double? get vfcMs => hrvNotte;
  int? get fcrBpm => rhrNotte?.toInt();
  int? get energiaBruciataCal => calorieTot;

  // Metriche Biometriche reali lette da SQLite o null se non misurate
  DateTime get giorno => oraInizioCiclo;
  double? get frequenzaRespiratoriaRpm => frequenzaRespiratoriaRpmVal;
  double? get tempCutaneaC => tempCutaneaCVal;
  double? get temperaturaPelleCelsius => tempCutaneaCVal;
  double? get frequenzaCardiacaRiposoBpm => rhrNotte;
  double? get spo2Pct => spo2PctVal;
  int? get fcMaxBpm => fcMaxBpmVal;
  int? get fcMediaBpm => fcMediaBpmVal;
  double? get valoreStressNotte => valoreStressNotteVal;

  // Campi sonno delegati (restituiscono null se non associati a sessione)
  double? get andamentoSonnoPct => null;
  double? get durataSonnoMin => null;
  double? get sonnoProfondoMin => null;
  double? get sonnoRemMin => null;
  double? get sonnoLeggeroMin => null;
  double? get durataRisveglioMin => null;
  double? get efficienzaSonnoPct => null;
  double? get regolaritaSonnoPct => null;
  double? get sonnoArretratoMin => null;

  Map<String, dynamic> toMap() {
    return {
      'data_iso': dataIso,
      'strain_giornaliero': strainGiornaliero,
      'recovery_score': recoveryScore,
      'sleep_need_min': sleepNeedMin,
      'hrv_notte': hrvNotte,
      'rhr_notte': rhrNotte,
      'frequenza_respiratoria_rpm': frequenzaRespiratoriaRpmVal,
      'temp_cutanea_c': tempCutaneaCVal,
      'spo2_pct': spo2PctVal,
      'fc_max_bpm': fcMaxBpmVal,
      'fc_media_bpm': fcMediaBpmVal,
      'calorie_tot': calorieTot,
      'valore_stress_notte': valoreStressNotteVal,
      'provenance': provenance,
    };
  }

  factory CicloFisiologico.fromMap(Map<String, dynamic> map) {
    return CicloFisiologico(
      dataIso: map['data_iso'] as String? ??
          (map['ora_inizio_ciclo'] != null
              ? (map['ora_inizio_ciclo'] as String).substring(0, 10)
              : DateTime.now().toIso8601String().substring(0, 10)),
      strainGiornaliero: (map['strain_giornaliero'] ?? map['sforzo_giornaliero'] as num?)?.toDouble(),
      recoveryScore: (map['recovery_score'] ?? map['punteggio_recupero_pct'] as num?)?.toDouble(),
      sleepNeedMin: (map['sleep_need_min'] ?? map['sonno_richiesto_min'] as num?)?.toInt(),
      hrvNotte: (map['hrv_notte'] ?? map['vfc_ms'] as num?)?.toDouble(),
      rhrNotte: (map['rhr_notte'] ?? map['fcr_bpm'] as num?)?.toDouble(),
      frequenzaRespiratoriaRpm: (map['frequenza_respiratoria_rpm'] as num?)?.toDouble(),
      tempCutaneaC: (map['temp_cutanea_c'] as num?)?.toDouble(),
      spo2Pct: (map['spo2_pct'] as num?)?.toDouble(),
      fcMaxBpm: (map['fc_max_bpm'] as num?)?.toInt(),
      fcMediaBpm: (map['fc_media_bpm'] as num?)?.toInt(),
      calorieTot: (map['calorie_tot'] ?? map['energia_bruciata_cal'] as num?)?.toInt(),
      valoreStressNotte: (map['valore_stress_notte'] as num?)?.toDouble(),
      provenance: map['provenance'] as String? ?? 'REAL',
    );
  }

  CicloFisiologico copyWith({
    String? dataIso,
    double? strainGiornaliero,
    double? recoveryScore,
    int? sleepNeedMin,
    double? hrvNotte,
    double? rhrNotte,
    double? frequenzaRespiratoriaRpm,
    double? tempCutaneaC,
    double? spo2Pct,
    int? fcMaxBpm,
    int? fcMediaBpm,
    int? calorieTot,
    double? valoreStressNotte,
    String? provenance,
  }) {
    return CicloFisiologico(
      dataIso: dataIso ?? this.dataIso,
      strainGiornaliero: strainGiornaliero ?? this.strainGiornaliero,
      recoveryScore: recoveryScore ?? this.recoveryScore,
      sleepNeedMin: sleepNeedMin ?? this.sleepNeedMin,
      hrvNotte: hrvNotte ?? this.hrvNotte,
      rhrNotte: rhrNotte ?? this.rhrNotte,
      frequenzaRespiratoriaRpm: frequenzaRespiratoriaRpm ?? this.frequenzaRespiratoriaRpmVal,
      tempCutaneaC: tempCutaneaC ?? this.tempCutaneaCVal,
      spo2Pct: spo2Pct ?? this.spo2PctVal,
      fcMaxBpm: fcMaxBpm ?? this.fcMaxBpmVal,
      fcMediaBpm: fcMediaBpm ?? this.fcMediaBpmVal,
      calorieTot: calorieTot ?? this.calorieTot,
      valoreStressNotte: valoreStressNotte ?? this.valoreStressNotteVal,
      provenance: provenance ?? this.provenance,
    );
  }
}
