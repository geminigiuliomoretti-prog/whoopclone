import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'coach_models.dart';

/// Interfaccia del Provider per WHOOP Coach AI
abstract class CoachProvider {
  Future<CoachResponse> sendMessage({
    required String userMessage,
    required CoachBiometricContext context,
    required CoachConfig config,
  });
}

/// System prompt di base condiviso per i modelli LLM esterni
const String _kCoachSystemInstructions = '''
Sei il WHOOP Coach AI, un assistente esperto in fisiologia dell'esercizio, recupero autonomico, sonno e ottimizzazione delle prestazioni umane (standard scientifico WHOOP 5.0).
Ti viene fornito il contesto fisiologico reale dell'utente per la giornata selezionata.

REGOLE ASSOLUTE:
1. Basati RIGOROSAMENTE sui parametri misurati forniti nel contesto.
2. Se un parametro è indicato come "Non disponibile", NON INVENTARLO o simularlo: spiega all'utente che il dato non è presente (ad es. sensore non indossato o telemetria notturna non scaricata).
3. Fornisci consigli pratici, basati su evidenze scientifiche, su carichi di allenamento raccomandati, igiene del sonno e gestione dello stress.
4. Rispondi in italiano in modo chiaro, empatico e professionale.
''';

/// Provider Locale Offline (Basato su Regole Fisiologiche Determinate)
class LocalRuleCoachProvider implements CoachProvider {
  @override
  Future<CoachResponse> sendMessage({
    required String userMessage,
    required CoachBiometricContext context,
    required CoachConfig config,
  }) async {
    final query = userMessage.toLowerCase();
    final rec = context.recoveryScore?.round();
    final hrv = context.hrvRmssdMs?.round();
    final rhr = context.rhrBpm?.round();
    final strain = context.dayStrain;
    final sleepDurMin = context.sleepDurationMin?.round();
    final sleepNeedMin = context.sleepNeedMin?.round();

    // 1. Domanda su orari/costanza del sonno o fabbisogno sonno
    if (query.contains('sonno') || query.contains('dormire') || query.contains('fabbisogno') || query.contains('orari')) {
      if (sleepDurMin == null) {
        return const CoachResponse(
          text: 'Non risultano sessioni di sonno registrate per questa notte. Se hai indossato il dispositivo, verifica la sincronizzazione BLE. Il tuo fabbisogno sonno basale stimato è di circa 8 ore.',
          providerName: 'Locale Offline',
        );
      }
      final oreSonno = (sleepDurMin / 60.0).toStringAsFixed(1);
      final oreNeed = sleepNeedMin != null ? (sleepNeedMin / 60.0).toStringAsFixed(1) : '8.0';
      return CoachResponse(
        text: 'La scorsa notte hai registrato $oreSonno ore di sonno effettivo a fronte di un fabbisogno calcolato di $oreNeed ore. Per massimizzare il recupero parasimpatico, mantieni orari stabili di addormentamento entro una finestra di +-30 minuti.',
        providerName: 'Locale Offline',
      );
    }

    // 2. Domanda su allenamento o sforzo di oggi
    if (query.contains('allen') || query.contains('allenar') || query.contains('sforzo') || query.contains('strain')) {
      if (rec == null) {
        return const CoachResponse(
          text: 'Il Recovery Score non è ancora disponibile per questa data. Ti consiglio un carico moderato fino al calcolo del recupero notturno.',
          providerName: 'Locale Offline',
        );
      }
      if (rec >= 67) {
        return CoachResponse(
          text: 'Ottimo recupero del $rec% (Zona Verde). Il tuo sistema nervoso autonomo è pronto per un carico elevato: puoi puntare a uno Strain compreso tra 14.0 e 18.0.',
          providerName: 'Locale Offline',
        );
      } else if (rec >= 34) {
        return CoachResponse(
          text: 'Il tuo recupero è al $rec% (Zona Gialla). Il corpo è in grado di sostenere un carico normale o aerobico moderato (Strain target: 10.0 - 13.5), evitando picchi ad altissima intensità.',
          providerName: 'Locale Offline',
        );
      } else {
        return CoachResponse(
          text: 'Recupero compromesso al $rec% (Zona Rossa). La variabilità cardiaca (VFC) o il battito a riposo indicano affaticamento. Privilegia recupero attivo, idratazione o riposo (Strain target < 8.0).',
          providerName: 'Locale Offline',
        );
      }
    }

    // 3. Domanda su VFC / HRV o parametri vitali
    if (query.contains('hrv') || query.contains('vfc') || query.contains('cuore') || query.contains('battito') || query.contains('fcr')) {
      if (hrv == null || rhr == null) {
        return const CoachResponse(
          text: 'I parametri notturni di VFC (HRV) ed FCR (RHR) non sono ancora stati registrati per questo ciclo.',
          providerName: 'Locale Offline',
        );
      }
      return CoachResponse(
        text: 'La tua VFC (rMSSD) notturna è stata di $hrv ms e la frequenza cardiaca a riposo di $rhr bpm. Questi valori riflettono l\'equilibrio simpatovagale durante la fase di sonno profondo (SWS).',
        providerName: 'Locale Offline',
      );
    }

    // 4. Domanda sul diario o abitudini
    if (query.contains('diario') || query.contains('magnesio') || query.contains('alcol') || query.contains('abitudin')) {
      if (context.habitsAnswered.isEmpty) {
        return const CoachResponse(
          text: 'Non hai ancora compilato le voci del diario comportamentale per questo ciclo. Compilare con costanza il diario ti aiuterà a scoprire quali abitudini migliorano il tuo recupero.',
          providerName: 'Locale Offline',
        );
      }
      return CoachResponse(
        text: 'Hai risposto a ${context.habitsAnswered.length} abitudini nel diario. Man mano che accumulerai registrazioni (almeno 5 Sì e 5 No per abitudine), potrai visualizzare l\'impatto statistico percentuale nella scheda "Approfondimenti sul Comportamento".',
        providerName: 'Locale Offline',
      );
    }

    // Risposta contestuale generale
    final recText = rec != null ? 'Recupero $rec%' : 'Recupero --';
    final strainText = strain != null ? 'Strain ${strain.toStringAsFixed(1)}' : 'Strain 0.0';
    return CoachResponse(
      text: 'Oggi i tuoi parametri registrano $recText e $strainText. Come posso aiutarti ulteriormente nell\'analisi dei tuoi dati?',
      providerName: 'Locale Offline',
    );
  }
}

/// Provider OpenAI (GPT-4o / GPT-4o-mini / etc.)
class OpenAICoachProvider implements CoachProvider {
  @override
  Future<CoachResponse> sendMessage({
    required String userMessage,
    required CoachBiometricContext context,
    required CoachConfig config,
  }) async {
    final apiKey = config.apiKey?.trim();
    if (apiKey == null || apiKey.isEmpty) {
      return CoachResponse.error(
        'Chiave API OpenAI non configurata. Inseriscila nelle impostazioni del Coach.',
        providerName: 'OpenAI',
      );
    }

    final endpointUrl = (config.endpoint != null && config.endpoint!.trim().isNotEmpty)
        ? config.endpoint!.trim()
        : 'https://api.openai.com/v1/chat/completions';

    final uri = Uri.tryParse(endpointUrl);
    if (uri == null) {
      return CoachResponse.error('Endpoint URL non valido: $endpointUrl', providerName: 'OpenAI');
    }

    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 15);

    try {
      final request = await client.postUrl(uri);
      request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $apiKey');

      final payload = {
        'model': config.model,
        'temperature': config.temperature,
        'messages': [
          {'role': 'system', 'content': '$_kCoachSystemInstructions\n\n${context.toSystemPromptSummary()}'},
          {'role': 'user', 'content': userMessage},
        ],
      };

      request.write(jsonEncode(payload));
      final response = await request.close().timeout(const Duration(seconds: 20));

      final responseBody = await response.transform(utf8.decoder).join();
      if (response.statusCode != 200) {
        return CoachResponse.error('Errore API HTTP ${response.statusCode}: $responseBody', providerName: 'OpenAI');
      }

      final jsonMap = jsonDecode(responseBody) as Map<String, dynamic>;
      final choices = jsonMap['choices'] as List?;
      if (choices == null || choices.isEmpty) {
        return CoachResponse.error('Risposta vuota da OpenAI', providerName: 'OpenAI');
      }

      final messageContent = choices.first['message']?['content'] as String? ?? '';
      return CoachResponse(text: messageContent.trim(), providerName: 'OpenAI (${config.model})');
    } catch (e) {
      return CoachResponse.error('Errore di connessione a OpenAI: $e', providerName: 'OpenAI');
    } finally {
      client.close();
    }
  }
}

/// Provider Anthropic Claude
class AnthropicCoachProvider implements CoachProvider {
  @override
  Future<CoachResponse> sendMessage({
    required String userMessage,
    required CoachBiometricContext context,
    required CoachConfig config,
  }) async {
    final apiKey = config.apiKey?.trim();
    if (apiKey == null || apiKey.isEmpty) {
      return CoachResponse.error(
        'Chiave API Anthropic non configurata.',
        providerName: 'Anthropic',
      );
    }

    final endpointUrl = (config.endpoint != null && config.endpoint!.trim().isNotEmpty)
        ? config.endpoint!.trim()
        : 'https://api.anthropic.com/v1/messages';

    final uri = Uri.tryParse(endpointUrl);
    if (uri == null) {
      return CoachResponse.error('Endpoint URL Anthropic non valido', providerName: 'Anthropic');
    }

    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 15);

    try {
      final request = await client.postUrl(uri);
      request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      request.headers.set('x-api-key', apiKey);
      request.headers.set('anthropic-version', '2023-06-01');

      final payload = {
        'model': config.model.contains('claude') ? config.model : 'claude-3-5-sonnet-20241022',
        'max_tokens': 1024,
        'system': '$_kCoachSystemInstructions\n\n${context.toSystemPromptSummary()}',
        'messages': [
          {'role': 'user', 'content': userMessage},
        ],
      };

      request.write(jsonEncode(payload));
      final response = await request.close().timeout(const Duration(seconds: 20));
      final responseBody = await response.transform(utf8.decoder).join();

      if (response.statusCode != 200) {
        return CoachResponse.error('Errore Anthropic HTTP ${response.statusCode}: $responseBody', providerName: 'Anthropic');
      }

      final jsonMap = jsonDecode(responseBody) as Map<String, dynamic>;
      final contentList = jsonMap['content'] as List?;
      if (contentList == null || contentList.isEmpty) {
        return CoachResponse.error('Risposta vuota da Anthropic', providerName: 'Anthropic');
      }

      final text = contentList.first['text'] as String? ?? '';
      return CoachResponse(text: text.trim(), providerName: 'Anthropic');
    } catch (e) {
      return CoachResponse.error('Errore connessione ad Anthropic: $e', providerName: 'Anthropic');
    } finally {
      client.close();
    }
  }
}

/// Provider Google Gemini
class GeminiCoachProvider implements CoachProvider {
  @override
  Future<CoachResponse> sendMessage({
    required String userMessage,
    required CoachBiometricContext context,
    required CoachConfig config,
  }) async {
    final apiKey = config.apiKey?.trim();
    if (apiKey == null || apiKey.isEmpty) {
      return CoachResponse.error(
        'Chiave API Google Gemini non configurata.',
        providerName: 'Gemini',
      );
    }

    final modelName = config.model.contains('gemini') ? config.model : 'gemini-1.5-flash';
    final endpointUrl = (config.endpoint != null && config.endpoint!.trim().isNotEmpty)
        ? config.endpoint!.trim()
        : 'https://generativelanguage.googleapis.com/v1beta/models/$modelName:generateContent?key=$apiKey';

    final uri = Uri.tryParse(endpointUrl);
    if (uri == null) {
      return CoachResponse.error('Endpoint URL Gemini non valido', providerName: 'Gemini');
    }

    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 15);

    try {
      final request = await client.postUrl(uri);
      request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');

      final payload = {
        'systemInstruction': {
          'parts': [
            {'text': '$_kCoachSystemInstructions\n\n${context.toSystemPromptSummary()}'}
          ]
        },
        'contents': [
          {
            'parts': [
              {'text': userMessage}
            ]
          }
        ],
      };

      request.write(jsonEncode(payload));
      final response = await request.close().timeout(const Duration(seconds: 20));
      final responseBody = await response.transform(utf8.decoder).join();

      if (response.statusCode != 200) {
        return CoachResponse.error('Errore Gemini HTTP ${response.statusCode}: $responseBody', providerName: 'Gemini');
      }

      final jsonMap = jsonDecode(responseBody) as Map<String, dynamic>;
      final candidates = jsonMap['candidates'] as List?;
      if (candidates == null || candidates.isEmpty) {
        return CoachResponse.error('Nessun candidato restituito da Gemini', providerName: 'Gemini');
      }

      final parts = candidates.first['content']?['parts'] as List?;
      final text = (parts != null && parts.isNotEmpty) ? parts.first['text'] as String? ?? '' : '';
      return CoachResponse(text: text.trim(), providerName: 'Google Gemini');
    } catch (e) {
      return CoachResponse.error('Errore connessione a Gemini: $e', providerName: 'Gemini');
    } finally {
      client.close();
    }
  }
}
