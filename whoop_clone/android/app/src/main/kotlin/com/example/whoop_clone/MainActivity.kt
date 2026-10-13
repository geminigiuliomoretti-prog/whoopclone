package com.example.whoop_clone

import android.app.ForegroundServiceStartNotAllowedException
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
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
                "updateNotification" -> {
                    val title = call.argument<String>("title") ?: "WHOOP 5.0 - Connessione Strap Attiva"
                    val text = call.argument<String>("text") ?: "Monitoraggio attivo in background"
                    try {
                        BleForegroundService.updateNotification(applicationContext, title, text)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("UpdateNotificationError", e.message, null)
                    }
                }
                "isIgnoringBatteryOptimizations" -> {
                    val pm = getSystemService(Context.POWER_SERVICE) as? PowerManager
                    val isIgnoring = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && pm != null) {
                        pm.isIgnoringBatteryOptimizations(packageName)
                    } else {
                        true
                    }
                    result.success(isIgnoring)
                }
                "requestIgnoreBatteryOptimizations" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        try {
                            val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                                data = Uri.parse("package:$packageName")
                                flags = Intent.FLAG_ACTIVITY_NEW_TASK
                            }
                            startActivity(intent)
                            result.success(true)
                        } catch (e: Exception) {
                            try {
                                val fallbackIntent = Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS).apply {
                                    flags = Intent.FLAG_ACTIVITY_NEW_TASK
                                }
                                startActivity(fallbackIntent)
                                result.success(true)
                            } catch (e2: Exception) {
                                result.error("BatteryOptimizationError", e2.message, null)
                            }
                        }
                    } else {
                        result.success(true)
                    }
                }
                "triggerVibration" -> {
                    try {
                        val durationMs = (call.argument<Int>("durationMs") ?: 500).toLong()
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                            val vibratorManager = getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as? android.os.VibratorManager
                            val vibrator = vibratorManager?.defaultVibrator
                            vibrator?.vibrate(android.os.VibrationEffect.createOneShot(durationMs, android.os.VibrationEffect.DEFAULT_AMPLITUDE))
                        } else {
                            @Suppress("DEPRECATION")
                            val vibrator = getSystemService(Context.VIBRATOR_SERVICE) as? android.os.Vibrator
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                                vibrator?.vibrate(android.os.VibrationEffect.createOneShot(durationMs, android.os.VibrationEffect.DEFAULT_AMPLITUDE))
                            } else {
                                @Suppress("DEPRECATION")
                                vibrator?.vibrate(durationMs)
                            }
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("VibrationError", e.message, null)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }
}
