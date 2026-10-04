package com.example.whoop_clone

import android.app.ForegroundServiceStartNotAllowedException
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.example.whoop_clone/foreground_service"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startForegroundService" -> {
                    try {
                        BleForegroundService.startService(applicationContext)
                        result.success(true)
                    } catch (e: IllegalStateException) {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && e is ForegroundServiceStartNotAllowedException) {
                            result.error(
                                "ForegroundServiceStartNotAllowedException",
                                "Impossibile avviare il Foreground Service in background su Android 12+: ${e.message}",
                                null
                            )
                        } else {
                            result.error(
                                "IllegalStateException",
                                "Stato non valido durante l'avvio del Foreground Service: ${e.message}",
                                null
                            )
                        }
                    } catch (e: SecurityException) {
                        result.error(
                            "SecurityException",
                            "Permessi mancanti per l'avvio del Foreground Service: ${e.message}",
                            null
                        )
                    } catch (e: Exception) {
                        result.error(
                            "ServiceStartException",
                            "Eccezione imprevista durante l'avvio del Foreground Service: ${e.message}",
                            null
                        )
                    }
                }
                "stopForegroundService" -> {
                    try {
                        BleForegroundService.stopService(applicationContext)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error(
                            "ServiceStopException",
                            "Errore durante l'arresto del Foreground Service: ${e.message}",
                            null
                        )
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }
}
