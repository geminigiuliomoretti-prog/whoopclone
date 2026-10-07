import '../../models/ciclo_fisiologico.dart';
import '../../models/sonno.dart';
import '../../models/voce_diario.dart';
import 'coach_models.dart';

/// Costruttore del contesto per il Coach AI a partire dai dati reali in memoria
class CoachContextBuilder {
  static CoachBiometricContext fromViewModelState({
    required String selectedDateIso,
    CicloFisiologico? ultimoCiclo,
    List<Sonno> sonnoList = const [],
    List<VoceDiario> vociDiarioList = const [],
    double? currentSleepNeedMin,
    bool isBleConnected = false,
  }) {
    final sonno = sonnoList.isNotEmpty ? sonnoList.first : null;

    final habitsMap = <String, bool>{};
    for (final v in vociDiarioList) {
      habitsMap[v.chiaveDomanda] = v.rispostaBool;
    }

    return CoachBiometricContext(
      dateIso: selectedDateIso,
      recoveryScore: ultimoCiclo?.punteggioRecuperoPct,
      dayStrain: ultimoCiclo?.sforzoGiornaliero,
      sleepDurationMin: sonno?.durataTotMin.toDouble(),
      sleepNeedMin: currentSleepNeedMin ?? ultimoCiclo?.sonnoRichiestoMin?.toDouble() ?? ultimoCiclo?.sleepNeedMin?.toDouble(),
      sleepPerformancePct: sonno?.sleepPerformancePct ?? ultimoCiclo?.andamentoSonnoPct,
      hrvRmssdMs: ultimoCiclo?.vfcMs,
      rhrBpm: ultimoCiclo?.fcrBpm?.toDouble(),
      respiratoryRateRpm: ultimoCiclo?.frequenzaRespiratoriaRpmVal,
      skinTempDeltaC: ultimoCiclo?.tempCutaneaCVal,
      spo2Pct: ultimoCiclo?.spo2PctVal,
      habitsAnswered: habitsMap,
      hasBleConnection: isBleConnected,
    );
  }
}
