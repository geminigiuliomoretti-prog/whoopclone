/// Tipo di Provider LLM configurabile per WHOOP Coach AI
enum CoachProviderType {
  localRuleBased('Locale Offline (Regole Verificate)'),
  openAi('OpenAI (ChatGPT / GPT-4o)'),
  anthropic('Anthropic (Claude 3.5)'),
  gemini('Google Gemini (1.5 Flash / Pro)'),
  customHttp('Custom HTTP (OpenAI-Compatible)');

  final String label;
  const CoachProviderType(this.label);
}

/// Configurazione persistente del Coach AI
class CoachConfig {
  final CoachProviderType providerType;
  final String? apiKey;
  final String? endpoint;
  final String model;
  final double temperature;

  const CoachConfig({
    this.providerType = CoachProviderType.localRuleBased,
    this.apiKey,
    this.endpoint,
    this.model = 'gpt-4o-mini',
    this.temperature = 0.7,
  });

  CoachConfig copyWith({
    CoachProviderType? providerType,
    String? apiKey,
    String? endpoint,
    String? model,
    double? temperature,
  }) {
    return CoachConfig(
      providerType: providerType ?? this.providerType,
      apiKey: apiKey ?? this.apiKey,
      endpoint: endpoint ?? this.endpoint,
      model: model ?? this.model,
      temperature: temperature ?? this.temperature,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'provider_type': providerType.name,
      'api_key': apiKey,
      'endpoint': endpoint,
      'model': model,
      'temperature': temperature,
    };
  }

  factory CoachConfig.fromMap(Map<String, dynamic> map) {
    CoachProviderType pType = CoachProviderType.localRuleBased;
    final typeName = map['provider_type'] as String?;
    if (typeName != null) {
      pType = CoachProviderType.values.firstWhere(
        (e) => e.name == typeName,
        orElse: () => CoachProviderType.localRuleBased,
      );
    }

    return CoachConfig(
      providerType: pType,
      apiKey: map['api_key'] as String?,
      endpoint: map['endpoint'] as String?,
      model: map['model'] as String? ?? 'gpt-4o-mini',
      temperature: (map['temperature'] as num?)?.toDouble() ?? 0.7,
    );
  }
}

/// Contesto Biometrico Veritiero (Zero Fake Data) per il Prompt del Coach
class CoachBiometricContext {
  final String dateIso;
  final double? recoveryScore;
  final double? dayStrain;
  final double? sleepDurationMin;
  final double? sleepNeedMin;
  final double? sleepPerformancePct;
  final double? hrvRmssdMs;
  final double? rhrBpm;
  final double? respiratoryRateRpm;
  final double? skinTempDeltaC;
  final double? spo2Pct;
  final Map<String, bool> habitsAnswered;
  final bool hasBleConnection;

  const CoachBiometricContext({
    required this.dateIso,
    this.recoveryScore,
    this.dayStrain,
    this.sleepDurationMin,
    this.sleepNeedMin,
    this.sleepPerformancePct,
    this.hrvRmssdMs,
    this.rhrBpm,
    this.respiratoryRateRpm,
    this.skinTempDeltaC,
    this.spo2Pct,
    this.habitsAnswered = const {},
    this.hasBleConnection = false,
  });

  /// Genera una rappresentazione testuale rigorosa e scientifica dei parametri reali
  String toSystemPromptSummary() {
    final buffer = StringBuffer();
    buffer.writeln('DATA CICLO: $dateIso');
    buffer.writeln('STATO DISPOSITIVO: ${hasBleConnection ? "Connesso BLE" : "Disconnesso / Dati Storici"}');
    buffer.writeln('');
    buffer.writeln('PARAMETRI FISIOLOGICI MISURATI:');
    buffer.writeln('- Punteggio Recupero (Recovery): ${recoveryScore != null ? "${recoveryScore!.toInt()}%" : "Non disponibile (in attesa di telemetria notturna valida)"}');
    buffer.writeln('- Sforzo Giornaliero (Day Strain): ${dayStrain != null ? dayStrain!.toStringAsFixed(1) : "0.0"}');
    buffer.writeln('- Durata Sonno: ${sleepDurationMin != null ? "${(sleepDurationMin! / 60).toStringAsFixed(1)} ore (${sleepDurationMin!.toInt()} min)" : "Nessuna sessione registrata"}');
    buffer.writeln('- Fabbisogno Sonno: ${sleepNeedMin != null ? "${(sleepNeedMin! / 60).toStringAsFixed(1)} ore" : "Non calcolato"}');
    buffer.writeln('- Prestazione Sonno: ${sleepPerformancePct != null ? "${sleepPerformancePct!.toInt()}%" : "Non disponibile"}');
    buffer.writeln('- VFC Notturna (rMSSD): ${hrvRmssdMs != null ? "${hrvRmssdMs!.toStringAsFixed(1)} ms" : "Non disponibile"}');
    buffer.writeln('- Frequenza a Riposo (RHR): ${rhrBpm != null ? "${rhrBpm!.toStringAsFixed(1)} bpm" : "Non disponibile"}');
    buffer.writeln('- Frequenza Respiratoria: ${respiratoryRateRpm != null ? "${respiratoryRateRpm!.toStringAsFixed(1)} rpm" : "Non disponibile"}');
    buffer.writeln('- Delta Temperatura Cutanea: ${skinTempDeltaC != null ? "${skinTempDeltaC! > 0 ? '+' : ''}${skinTempDeltaC!.toStringAsFixed(1)} °C" : "Non disponibile"}');
    buffer.writeln('- Saturazione SpO2: ${spo2Pct != null ? "${spo2Pct!.toStringAsFixed(1)}%" : "Non disponibile"}');
    
    if (habitsAnswered.isNotEmpty) {
      buffer.writeln('');
      buffer.writeln('VOCI DEL DIARIO COMPORTAMENTALE (IERI):');
      habitsAnswered.forEach((habit, answeredYes) {
        buffer.writeln('- $habit: ${answeredYes ? "SÌ" : "NO"}');
      });
    }

    return buffer.toString();
  }
}

/// Risultato della risposta del Coach AI
class CoachResponse {
  final String text;
  final bool isError;
  final String? errorMessage;
  final String providerName;

  const CoachResponse({
    required this.text,
    this.isError = false,
    this.errorMessage,
    required this.providerName,
  });

  factory CoachResponse.error(String message, {String providerName = 'Sistema'}) {
    return CoachResponse(
      text: 'Non è stato possibile ottenere una risposta dal Coach: $message',
      isError: true,
      errorMessage: message,
      providerName: providerName,
    );
  }
}
