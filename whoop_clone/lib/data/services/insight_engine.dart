/// Motore di calcolo e generazione insight fisiologici WHOOP 5.0
class InsightEngine {
  /// Calcola la percentuale di scostamento e genera il testo di approfondimento fisiologico VFC
  static String generateHrvInsight({
    required double? hrvSws,
    required double? hrvBaseline,
  }) {
    if (hrvSws == null || hrvBaseline == null || hrvBaseline <= 0) {
      return 'Dati VFC insufficienti per determinare lo scostamento dalla baseline.';
    }

    final delta = ((hrvSws - hrvBaseline) / hrvBaseline * 100).round();
    final direction = delta >= 0 ? 'superiore' : 'inferiore';

    return 'La tua VFC è del ${delta.abs()}% $direction alla baseline. '
        '${delta >= 0 ? "Una VFC elevata indica che il tuo sistema nervoso autonomo è pronto a gestire lo sforzo e lo stress." : "Una VFC ridotta suggerisce che il tuo corpo necessita di maggiore riposo per recuperare."}';
  }
}
