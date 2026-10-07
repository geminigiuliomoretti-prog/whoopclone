import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'coach_models.dart';
import 'coach_provider.dart';

/// Servizio centrale di orchestrazione per WHOOP Coach AI
class CoachService extends ChangeNotifier {
  static const String _kConfigPrefsKey = 'whoop_coach_config_v1';

  CoachConfig _config = const CoachConfig();
  CoachConfig get config => _config;

  final Map<CoachProviderType, CoachProvider> _providers = {
    CoachProviderType.localRuleBased: LocalRuleCoachProvider(),
    CoachProviderType.openAi: OpenAICoachProvider(),
    CoachProviderType.anthropic: AnthropicCoachProvider(),
    CoachProviderType.gemini: GeminiCoachProvider(),
    CoachProviderType.customHttp: OpenAICoachProvider(), // Custom HTTP usa formato OpenAI
  };

  CoachService() {
    loadConfig();
  }

  /// Carica le preferenze del Coach salvate
  Future<void> loadConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_kConfigPrefsKey);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final map = jsonDecode(jsonStr) as Map<String, dynamic>;
        _config = CoachConfig.fromMap(map);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[CoachService] Errore caricamento configurazione: $e');
    }
  }

  /// Salva la nuova configurazione del Coach
  Future<void> updateConfig(CoachConfig newConfig) async {
    _config = newConfig;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kConfigPrefsKey, jsonEncode(newConfig.toMap()));
    } catch (e) {
      debugPrint('[CoachService] Errore salvataggio configurazione: $e');
    }
  }

  /// Invia la richiesta al provider configurato, con fallback trasparente
  Future<CoachResponse> askCoach({
    required String query,
    required CoachBiometricContext context,
  }) async {
    final activeProvider = _providers[_config.providerType] ?? _providers[CoachProviderType.localRuleBased]!;

    try {
      final response = await activeProvider.sendMessage(
        userMessage: query,
        context: context,
        config: _config,
      );

      // Se il provider remoto ha fallito a causa di errore di connessione o chiave non impostata,
      // esegui un fallback sul motore locale scientifico e notifica l'utente
      if (response.isError && _config.providerType != CoachProviderType.localRuleBased) {
        debugPrint('[CoachService] Provider ${_config.providerType} ha fallito: ${response.errorMessage}. Eseguo fallback locale.');
        final localFallback = await _providers[CoachProviderType.localRuleBased]!.sendMessage(
          userMessage: query,
          context: context,
          config: _config,
        );

        return CoachResponse(
          text: '${localFallback.text}\n\n*(Nota: ${response.errorMessage}. Risposta generata dal motore locale offline)*',
          isError: false,
          providerName: 'Locale Offline (Fallback)',
        );
      }

      return response;
    } catch (e) {
      debugPrint('[CoachService] Eccezione generica nel Coach: $e');
      final localFallback = await _providers[CoachProviderType.localRuleBased]!.sendMessage(
        userMessage: query,
        context: context,
        config: _config,
      );
      return CoachResponse(
        text: '${localFallback.text}\n\n*(Nota: errore provider $e. Risposta generata dal motore locale offline)*',
        isError: false,
        providerName: 'Locale Offline (Fallback)',
      );
    }
  }
}
