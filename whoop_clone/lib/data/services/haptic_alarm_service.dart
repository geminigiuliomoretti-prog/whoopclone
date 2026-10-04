import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../ble/ble_connection_manager.dart';
import '../ble/noop_protocol_decoder.dart';
import '../database/database_helper.dart';

/// Modalità di Risveglio Intelligente (Architettura NOOP)
enum WakeupMode {
  fixedTime, // Orario Fisso: risveglio deterministico all'ora impostata
  sleepTarget, // Target Sonno: risveglio al raggiungimento del target (Peak 100%, Perform 85%, Get By 70%)
  optimalWakeWindow, // Finestra Ottimale: risveglio in sonno leggero/veglia nei 30 min precedenti l'orario limite
}

/// Intensità del Motore Aptico BLE
enum HapticIntensity {
  gentle(1, 'Delicata'),
  standard(2, 'Standard'),
  intense(3, 'Intensa');

  final int patternCode;
  final String label;
  const HapticIntensity(this.patternCode, this.label);

  static HapticIntensity fromIndex(int idx) {
    if (idx < 0 || idx >= HapticIntensity.values.length) return HapticIntensity.standard;
    return HapticIntensity.values[idx];
  }
}

/// Servizio di Gestione della Sveglia Aptica Intelligente e Controllo BLE (NOOP Haptic Engine)
class HapticAlarmService extends ChangeNotifier {
  final BleConnectionManager _bleManager;
  final DatabaseHelper _dbHelper;

  bool _isEnabled = false;
  TimeOfDay _targetTime = const TimeOfDay(hour: 7, minute: 0);
  WakeupMode _wakeupMode = WakeupMode.optimalWakeWindow;
  double _sleepTargetPct = 85.0; // Perform 85% default
  HapticIntensity _intensity = HapticIntensity.standard;

  bool _isRinging = false;
  DateTime? _lastRingTime;
  DateTime? _snoozeUntil;
  Timer? _monitoringTimer;

  HapticAlarmService({
    BleConnectionManager? bleManager,
    DatabaseHelper? dbHelper,
  })  : _bleManager = bleManager ?? BleConnectionManager(),
        _dbHelper = dbHelper ?? DatabaseHelper() {
    _startMonitoringLoop();
  }

  // Getters
  bool get isEnabled => _isEnabled;
  TimeOfDay get targetTime => _targetTime;
  WakeupMode get wakeupMode => _wakeupMode;
  double get sleepTargetPct => _sleepTargetPct;
  HapticIntensity get intensity => _intensity;
  bool get isRinging => _isRinging;
  DateTime? get snoozeUntil => _snoozeUntil;
  DateTime? get lastRingTime => _lastRingTime;

  /// Inizializza o carica le impostazioni da SQLite
  Future<void> loadSettingsFromDb() async {
    final dbData = await _dbHelper.getImpostazioniSveglia();
    _isEnabled = (dbData['is_enabled'] as int? ?? 0) == 1;
    _targetTime = TimeOfDay(
      hour: dbData['alarm_hour'] as int? ?? 7,
      minute: dbData['alarm_minute'] as int? ?? 0,
    );
    final modeIdx = dbData['selected_mode'] as int? ?? 1;
    _wakeupMode = modeIdx == 0
        ? WakeupMode.fixedTime
        : modeIdx == 1
            ? WakeupMode.sleepTarget
            : WakeupMode.optimalWakeWindow;

    final goalIdx = dbData['target_goal_idx'] as int? ?? 1;
    _sleepTargetPct = goalIdx == 0
        ? 100.0
        : goalIdx == 1
            ? 85.0
            : 70.0;

    _intensity = HapticIntensity.fromIndex(dbData['haptic_intensity'] as int? ?? 1);
    notifyListeners();
  }

  /// Salva e sincronizza le impostazioni della sveglia con la fascia BLE e SQLite
  Future<void> updateSettings({
    required bool isEnabled,
    required TimeOfDay targetTime,
    required WakeupMode wakeupMode,
    double sleepTargetPct = 85.0,
    HapticIntensity intensity = HapticIntensity.standard,
  }) async {
    _isEnabled = isEnabled;
    _targetTime = targetTime;
    _wakeupMode = wakeupMode;
    _sleepTargetPct = sleepTargetPct;
    _intensity = intensity;

    // Persistenza SQLite
    final int modeIdx = wakeupMode == WakeupMode.fixedTime
        ? 0
        : wakeupMode == WakeupMode.sleepTarget
            ? 1
            : 2;

    final int goalIdx = sleepTargetPct >= 95.0
        ? 0
        : sleepTargetPct >= 80.0
            ? 1
            : 2;

    await _dbHelper.saveImpostazioniSveglia(
      isEnabled: isEnabled,
      hour: targetTime.hour,
      minute: targetTime.minute,
      mode: modeIdx,
      goalIdx: goalIdx,
      intensity: intensity.patternCode,
    );

    // Sincronizzazione BLE con lo strap
    if (isEnabled) {
      final now = DateTime.now();
      var alarmDateTime = DateTime(now.year, now.month, now.day, targetTime.hour, targetTime.minute);
      if (alarmDateTime.isBefore(now)) {
        alarmDateTime = alarmDateTime.add(const Duration(days: 1));
      }
      await _syncBleAlarmToStrap(alarmDateTime);
    } else {
      await _cancelBleAlarmOnStrap();
    }

    notifyListeners();
  }

  /// Invia il payload di configurazione sveglia allo strap WHOOP via BLE
  Future<bool> _syncBleAlarmToStrap(DateTime alarmTime) async {
    final payload = HapticClockEncoder.encodeAlarmTime(
      alarmTime: alarmTime,
      vibrationPattern: _intensity.patternCode,
    );
    return await _bleManager.writeAlarmCommand(payload);
  }

  /// Disattiva la sveglia sullo strap
  Future<bool> _cancelBleAlarmOnStrap() async {
    final payload = HapticClockEncoder.encodeCancelAlarm();
    return await _bleManager.writeAlarmCommand(payload);
  }

  /// Esegue un impulso di test immediato di vibrazione aptica
  Future<bool> testVibrationPulse({HapticIntensity? overrideIntensity}) async {
    final pattern = (overrideIntensity ?? _intensity).patternCode;
    return await _bleManager.sendHapticVibrationCommand(pattern: pattern);
  }

  /// Valuta le condizioni di risveglio in tempo reale
  void evaluateWakeupConditions({
    required double currentSleepDurationMin,
    required double sleepNeedMin,
    String? currentSleepStage, // 'wake', 'light', 'sws', 'rem'
    double? currentMotionEnmo,
    DateTime? currentTime,
  }) {
    if (!_isEnabled || _isRinging) return;

    final now = currentTime ?? DateTime.now();

    // Se la sveglia è in snooze, controlla se il timer è scaduto
    if (_snoozeUntil != null) {
      if (now.isAfter(_snoozeUntil!)) {
        _snoozeUntil = null;
        triggerAlarm(reason: 'Snooze Terminato');
      }
      return;
    }

    final targetDateTime = DateTime(now.year, now.month, now.day, _targetTime.hour, _targetTime.minute);

    // 1. Modalità Orario Fisso
    if (_wakeupMode == WakeupMode.fixedTime) {
      if (now.hour == _targetTime.hour && now.minute == _targetTime.minute) {
        triggerAlarm(reason: 'Orario Fisso Raggiunto');
      }
      return;
    }

    // 2. Modalità Target di Sonno
    if (_wakeupMode == WakeupMode.sleepTarget) {
      final targetMinutesNeeded = (sleepNeedMin * (_sleepTargetPct / 100.0));
      if (currentSleepDurationMin >= targetMinutesNeeded && targetMinutesNeeded > 0) {
        triggerAlarm(reason: 'Target Sonno ($_sleepTargetPct%) Raggiunto');
        return;
      }

      // Fallback orario limite
      if (now.hour == _targetTime.hour && now.minute == _targetTime.minute) {
        triggerAlarm(reason: 'Orario Limite Target Sonno Raggiunto');
      }
      return;
    }

    // 3. Modalità Finestra di Risveglio Ottimale (30 min prima dell'orario limite)
    if (_wakeupMode == WakeupMode.optimalWakeWindow) {
      final windowStart = targetDateTime.subtract(const Duration(minutes: 30));

      if (now.isAfter(windowStart) && now.isBefore(targetDateTime)) {
        // Se il sensore rileva fase leggera, veglia o movimento dinamico (ENMO > 0.04g), attiva la sveglia
        final isLightOrWake = currentSleepStage == 'light' || currentSleepStage == 'wake';
        final isMoving = currentMotionEnmo != null && currentMotionEnmo > 0.04;

        if (isLightOrWake || isMoving) {
          triggerAlarm(reason: 'Risveglio Ottimale in Fase Leggera');
          return;
        }
      }

      // Raggiunto l'orario limite: suona obbligatoriamente
      if (now.hour == _targetTime.hour && now.minute == _targetTime.minute) {
        triggerAlarm(reason: 'Orario Limite Finestra Ottimale');
      }
    }
  }

  /// Innesca l'allarme aptico attivo
  Future<void> triggerAlarm({String reason = 'Sveglia Attivata'}) async {
    _isRinging = true;
    _lastRingTime = DateTime.now();
    debugPrint('[HapticAlarmService] 🔔 ALLARME APTICO ATTIVATO: $reason');

    // Invia pacchetto di vibrazione immediata allo strap
    await testVibrationPulse();
    notifyListeners();
  }

  /// Snooze della sveglia per 9 minuti
  void snoozeAlarm({int snoozeMinutes = 9}) {
    _isRinging = false;
    _snoozeUntil = DateTime.now().add(Duration(minutes: snoozeMinutes));
    debugPrint('[HapticAlarmService] ⏸ Sveglia in Snooze fino a: $_snoozeUntil');
    notifyListeners();
  }

  /// Spegne definitivamente la sveglia per il ciclo corrente
  Future<void> dismissAlarm() async {
    _isRinging = false;
    _snoozeUntil = null;
    await _cancelBleAlarmOnStrap();
    debugPrint('[HapticAlarmService] ⏹ Sveglia Disattivata / Dismissed');
    notifyListeners();
  }

  void _startMonitoringLoop() {
    if (DatabaseHelper.isTestMode) return;
    _monitoringTimer?.cancel();
    _monitoringTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      if (_isEnabled) {
        evaluateWakeupConditions(
          currentSleepDurationMin: 0.0,
          sleepNeedMin: 480.0,
        );
      }
    });
  }

  @override
  void dispose() {
    _monitoringTimer?.cancel();
    super.dispose();
  }
}
