import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Servizio per la gestione dell'ottimizzazione batteria Android e notifica dinamica (Fase 4: BGD-01, BGD-02)
class BatteryOptimizationService {
  static const MethodChannel _channel =
      MethodChannel('com.example.whoop_clone/foreground_service');

  static final BatteryOptimizationService instance = BatteryOptimizationService();

  bool get _isPlatformChannelAvailable {
    if (kIsWeb) return false;
    try {
      return defaultTargetPlatform == TargetPlatform.android;
    } catch (_) {
      return false;
    }
  }

  /// Verifica se l'app è esclusa dall'ottimizzazione della batteria (Doze mode)
  Future<bool> isIgnoringBatteryOptimizations() async {
    if (!_isPlatformChannelAvailable) {
      return true;
    }
    try {
      final bool? result =
          await _channel.invokeMethod<bool>('isIgnoringBatteryOptimizations');
      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint('[BatteryOptimizationService] Errore verifica ottimizzazione: ${e.message}');
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Richiede al sistema operativo di escludere l'app dall'ottimizzazione batteria
  Future<bool> requestIgnoreBatteryOptimizations() async {
    if (!_isPlatformChannelAvailable) {
      return true;
    }
    try {
      final bool? result =
          await _channel.invokeMethod<bool>('requestIgnoreBatteryOptimizations');
      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint('[BatteryOptimizationService] Errore richiesta ottimizzazione: ${e.message}');
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Aggiorna dinamicamente il testo della notifica permanente del Foreground Service (BGD-01)
  Future<bool> updateServiceNotification({
    required String title,
    required String text,
  }) async {
    if (!_isPlatformChannelAvailable) {
      return true;
    }
    try {
      final bool? result = await _channel.invokeMethod<bool>(
        'updateNotification',
        {'title': title, 'text': text},
      );
      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint('[BatteryOptimizationService] Errore aggiornamento notifica: ${e.message}');
      return false;
    } catch (_) {
      return false;
    }
  }
}
