import 'dart:async';
import 'package:flutter/material.dart';
import '../data/models/ciclo_fisiologico.dart';
import '../data/models/allenamento.dart';
import '../data/models/voce_diario.dart';
import '../data/models/sonno.dart';
import '../data/models/utente_profilo.dart';
import '../data/repositories/whoop_repository.dart';
import '../data/repositories/sqlite_whoop_repository.dart';
import '../data/repositories/user_repository.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../data/ble/ble_connection_manager.dart';
import '../data/ble/hr_data_packet.dart';
import '../data/ble/whoop_96byte_packet.dart';
import '../data/ble/rr_circular_buffer.dart';
import '../data/biometrics/whoop_biometric_engine.dart';
import '../data/biometrics/journal_impact_engine.dart';
import '../data/biometrics/health_vitals_engine.dart';
import '../data/engine/whoop_analytics_engine.dart';
import '../data/database/database_helper.dart';

import '../data/repositories/dashboard_preferences_repository.dart';
import '../data/io/noop_import_export_service.dart';
import '../data/services/noop_workout_detector.dart';
import '../data/services/noop_system_services.dart';
import '../data/services/haptic_alarm_service.dart';
import '../data/services/overnight_sleep_engine.dart';
import '../data/services/raw_capture_service.dart';

/// ViewModel Reattivo WHOOP 5.0 (Single Source of Truth)
/// Gestisce lo stato dell'applicazione leggendo esclusivamente dal DB SQLite.
class WhoopViewModel extends ChangeNotifier with WidgetsBindingObserver {
  final WhoopRepository _repository;
  final UserRepository _userRepository;
  final BleConnectionManager _bleManager;
  final WhoopBiometricEngine _biometricEngine;
  final DashboardPreferencesRepository _dashboardPreferencesRepository;

  // Servizi e Motori di Logica Infrastrutturale (da ryanbr/noop)
  late final NoopImportExportService _importExportService;
  late final AutoWorkoutDetector _autoWorkoutDetector;
  late final AutoSleepDetector _autoSleepDetector;
  final BatteryEstimator _batteryEstimator = BatteryEstimator();
  late final HapticAlarmScheduler _hapticAlarmScheduler;
  late final HapticAlarmService _hapticAlarmService;
  late final BackgroundSyncDaemon _backgroundDaemon;
  late final OvernightSleepEngine _overnightSleepEngine;

  final RRCircularBuffer _rrBuffer = RRCircularBuffer(capacity: 500);

  bool _isLoading = true;
  String? _errorMessage;

  DateTime _selectedDate = DateTime.now();

  CicloFisiologico? _ultimoCiclo;
  List<CicloFisiologico> _cicliList = [];
  List<Allenamento> _allenamentiList = [];
  List<VoceDiario> _vociDiarioList = [];
  List<Sonno> _sonnoList = [];

  // Profile Baseline User Settings (Popolate da DB utente_profilo)
  UtenteProfilo _userProfile = const UtenteProfilo(
    nome: 'Utente WHOOP',
    eta: 30,
    hrMax: 190,
    hrRestBaseline: 55,
    hrvBaselineMean: 65.0,
    hrvBaselineStd: 15.0,
    rhrBaselineMean: 55.0,
    rhrBaselineStd: 3.5,
    sleepBaselineMin: 480,
  );

  // Active Dashboard Tiles Keys
  List<String> _enabledTileKeys = ['vfc', 'fcr', 'steps', 'zone_fc_low', 'vo2max', 'calories'];

  // Live BLE State & Biometrics
  int _liveBpm = 0;
  double _liveHrvRmssd = 0.0;
  double _liveStressIndex = 0.0;
  int _lastStressSampleSaveMs = 0;
  BleState _bleState = BleState.disconnected;
  String? _bleStatusMessage;
  bool _isFallbackMode = false;
  Whoop96BytePacket? _last96BytePacket;

  // Dati grafici reali aggregati da SQLite (CHT-01..04, STG-07)
  List<Map<String, dynamic>> _currentHypnogramSegments = [];
  List<Map<String, dynamic>?> _currentIntradayHrBuckets = [];
  Map<String, dynamic> _currentHrZones = {};
  bool _isChartsLoading = false;

  // Throttling/Debouncing Live BLE updates per prevenire rebuild continui della UI
  int _lastNotifiedBpm = 0;
  double _lastNotifiedHrv = 0.0;
  double _lastNotifiedStress = 0.0;
  int _lastBleNotifyMs = 0;
  Timer? _bleThrottleTimer;
  static const int _bleThrottleIntervalMs = 600;

  StreamSubscription<HrDataPacket>? _hrSubscription;
  StreamSubscription<Whoop96BytePacket>? _packet96Subscription;
  StreamSubscription<BleState>? _bleStateSubscription;
  StreamSubscription<UtenteProfilo?>? _profileSubscription;
  StreamSubscription<Allenamento>? _autoWorkoutSubscription;
  StreamSubscription<Map<String, dynamic>>? _autoSleepSubscription;

  WhoopViewModel({
    WhoopRepository? repository,
    UserRepository? userRepository,
    BleConnectionManager? bleManager,
    WhoopBiometricEngine? biometricEngine,
    DashboardPreferencesRepository? dashboardPreferencesRepository,
  })  : _repository = repository ?? SqliteWhoopRepository(),
        _userRepository = userRepository ?? UserRepository(),
        _bleManager = bleManager ?? BleConnectionManager(),
        _biometricEngine = biometricEngine ?? WhoopBiometricEngine(),
        _dashboardPreferencesRepository = dashboardPreferencesRepository ?? DashboardPreferencesRepository() {
    
    // Inizializzazione moduli infrastrutturali NOOP
    if (_repository is SqliteWhoopRepository) {
      _importExportService = NoopImportExportService(repository: _repository as SqliteWhoopRepository);
    } else {
      _importExportService = NoopImportExportService(repository: SqliteWhoopRepository());
    }
    _autoWorkoutDetector = AutoWorkoutDetector(restHr: _userProfile.hrRestBaseline.toDouble());
    _hapticAlarmScheduler = HapticAlarmScheduler(bleManager: _bleManager);
    _hapticAlarmService = HapticAlarmService(bleManager: _bleManager);
    _backgroundDaemon = BackgroundSyncDaemon(bleManager: _bleManager, repository: _repository);
    _overnightSleepEngine = OvernightSleepEngine();
    _autoSleepDetector = AutoSleepDetector(
      restHr: _userProfile.hrRestBaseline.toDouble(),
      hrvBaseline: _userProfile.hrvBaselineMean,
      sleepEngine: _overnightSleepEngine,
      userBaselineProvider: () => {
        'rhr_mean': _userProfile.rhrBaselineMean,
        'rmssd_mean': _userProfile.hrvBaselineMean,
        'rmssd_std': _userProfile.hrvBaselineStd,
        'baseline_temp_celsius': _userProfile.baselineSampleCount >= 4 ? 36.5 : null,
        'sleep_baseline_min': _userProfile.sleepBaselineMin,
        'sleep_need_min': currentSleepNeedMinutes,
      },
    );

    _backgroundDaemon.startDaemon();
    _initAutoWorkoutListener();
    _initAutoSleepListener();
    _initBleListeners();
    _initProfileListener();
    try {
      WidgetsBinding.instance.addObserver(this);
    } catch (e) {
      debugPrint('[WhoopViewModel] WidgetsBinding.addObserver notice: $e');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      debugPrint('WhoopViewModel: App tornata in primo piano (resumed). Ripristino / verifica connessione BLE...');
      _bleManager.ensureConnected();
      triggerOvernightSyncIfNeeded();
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      debugPrint('WhoopViewModel: App andata in background. Sessione BLE mantenuta attiva.');
    }
  }

  void _initAutoWorkoutListener() {
    _autoWorkoutSubscription = _autoWorkoutDetector.autoWorkoutDetectedStream.listen((allenamento) async {
      await _repository.insertAllenamento(allenamento);
      await loadData();
      notifyListeners();
    });
  }

  void _initAutoSleepListener() {
    _autoSleepSubscription = _autoSleepDetector.autoSleepDetectedStream.listen((sleepResult) async {
      debugPrint('WhoopViewModel [AutoSleep]: Notte conclusa ed elaborata automaticamente!');
      await loadData(triggerAutoSync: false);
      notifyListeners();
    });
  }

  // Getters NOOP Infrastructure
  NoopImportExportService get importExportService => _importExportService;
  AutoWorkoutDetector get autoWorkoutDetector => _autoWorkoutDetector;
  AutoSleepDetector get autoSleepDetector => _autoSleepDetector;
  OvernightSleepEngine get overnightSleepEngine => _overnightSleepEngine;
  BatteryEstimator get batteryEstimator => _batteryEstimator;
  HapticAlarmScheduler get hapticAlarmScheduler => _hapticAlarmScheduler;
  HapticAlarmService get hapticAlarmService => _hapticAlarmService;
  BleConnectionManager get bleManager => _bleManager;

  List<double?> get history14dRecovery => _cicliList.take(14).map((c) => c.punteggioRecuperoPct).toList().reversed.toList();
  List<double?> get history14dHrv => _cicliList.take(14).map((c) => c.vfcMs).toList().reversed.toList();
  List<double?> get history14dRhr => _cicliList.take(14).map((c) => c.rhrNotte).toList().reversed.toList();
  List<double?> get history14dStrain => _cicliList.take(14).map((c) => c.sforzoGiornaliero).toList().reversed.toList();
  List<double?> get history14dSleep => _sonnoList.take(14).map((s) => s.durataTotMin > 0 ? (s.durataTotMin / 60.0) : null).toList().reversed.toList();

  Future<bool> scheduleHapticAlarm(DateTime alarmTime, {int vibrationPattern = 1}) async {
    return await _hapticAlarmScheduler.scheduleHapticAlarm(
      alarmTime: alarmTime,
      vibrationPattern: vibrationPattern,
    );
  }

  // Getters reattivi
  bool get isLoading => _isLoading;
  bool get isLoadingDailyData => _isLoading;
  String? get errorMessage => _errorMessage;
  DateTime get selectedDate => _selectedDate;
  CicloFisiologico? get ultimoCiclo => _ultimoCiclo;
  List<CicloFisiologico> get cicliList => _cicliList;
  List<CicloFisiologico> get storicoCicli => _cicliList;
  List<Allenamento> get allenamentiList => _allenamentiList;
  List<VoceDiario> get vociDiarioList => _vociDiarioList;
  List<Sonno> get sonnoList => _sonnoList;
  Sonno? get ultimoSonno => _sonnoList.isNotEmpty ? _sonnoList.first : null;
  WhoopBiometricEngine get biometricEngine => _biometricEngine;
  UtenteProfilo get userProfile => _userProfile;

  int? get recoveryScore => _ultimoCiclo?.punteggioRecuperoPct?.round();
  int? get sleepPerformance {
    final sonno = _sonnoList.isNotEmpty ? _sonnoList.first : null;
    final double sleepMin = (sonno?.durataTotMin ?? 0).toDouble();
    if (sleepMin <= 0 || sonno?.sleepPerformancePct == null) return null;
    return sonno!.sleepPerformancePct!.round();
  }
  double? get hrv => _ultimoCiclo?.vfcMs;
  double? get restingHr => _ultimoCiclo?.rhrNotte;
  double? get respiratoryRate => _ultimoCiclo?.frequenzaRespiratoriaRpm;
  double? get skinTempDelta => _ultimoCiclo?.tempCutaneaC;
  double? get bloodOxygenSpo2 => _ultimoCiclo?.spo2Pct?.toDouble();

  String get userName => _userProfile.nome;
  int get userMaxHr => _userProfile.hrMax;
  int get userBaselineRhr => _userProfile.hrRestBaseline;
  double get userBaselineHrv => _userProfile.hrvBaselineMean;
  List<String> get enabledTileKeys => _enabledTileKeys;
  List<String> get debugLogs => _bleManager.debugLogs;
  Stream<List<String>> get debugLogsStream => _bleManager.debugLogsStream;

  Future<void> saveDashboardTiles(List<String> activeKeys) async {
    _enabledTileKeys = List.from(activeKeys);
    await _dashboardPreferencesRepository.saveEnabledTiles(activeKeys);
    notifyListeners();
  }

  void updateDashboardTiles(List<String> activeKeys) {
    saveDashboardTiles(activeKeys);
  }

  // Live BLE & Biometric Getters
  int get liveBpm => _liveBpm;
  double get liveHrvRmssd => _liveHrvRmssd;
  double get liveStressIndex => _liveStressIndex;
  BleState get bleState => _bleState;
  String? get bleStatusMessage => _bleStatusMessage;
  bool get isFallbackMode => _isFallbackMode;
  Whoop96BytePacket? get last96BytePacket => _last96BytePacket;
  int? get batteryPct => _bleManager.batteryLevelPct;
  String? get connectedDeviceName => _bleManager.connectedDevice?.platformName.isNotEmpty == true
      ? _bleManager.connectedDevice!.platformName
      : _bleManager.connectedDevice?.remoteId.str;
  int get streakDays => _streakDays;
  RRCircularBuffer get rrBuffer => _rrBuffer;
  int _streakDays = 0;

  // Chart Getters (CHT-01..04, STG-07)
  List<Map<String, dynamic>> get currentHypnogramSegments => _currentHypnogramSegments;
  List<Map<String, dynamic>?> get currentIntradayHrBuckets => _currentIntradayHrBuckets;
  Map<String, dynamic> get currentHrZones => _currentHrZones;
  bool get isChartsLoading => _isChartsLoading;

  double _savedStressScore = 0.0;

  bool _isAlarmEnabled = false;
  TimeOfDay _alarmTime = const TimeOfDay(hour: 7, minute: 0);
  int _alarmModeIdx = 1;
  int _alarmGoalIdx = 1;
  int _alarmHapticIntensity = 1;

  bool get isAlarmEnabled => _isAlarmEnabled;
  TimeOfDay get alarmTime => _alarmTime;
  int get alarmModeIdx => _alarmModeIdx;
  int get alarmGoalIdx => _alarmGoalIdx;
  int get alarmHapticIntensity => _alarmHapticIntensity;

  double get currentStressScore {
    if (_liveStressIndex > 0) return _liveStressIndex;
    if (_savedStressScore > 0) return _savedStressScore;
    if (_ultimoCiclo?.valoreStressNotte != null && _ultimoCiclo!.valoreStressNotte! > 0) {
      return _ultimoCiclo!.valoreStressNotte!;
    }
    return 0.0;
  }

  double? get sleepStress => _ultimoCiclo?.valoreStressNotte;

  Future<void> saveAlarmSettings({
    required bool isEnabled,
    required TimeOfDay alarmTime,
    required int selectedMode,
    required int targetGoalIdx,
    required int hapticIntensity,
  }) async {
    _isAlarmEnabled = isEnabled;
    _alarmTime = alarmTime;
    _alarmModeIdx = selectedMode;
    _alarmGoalIdx = targetGoalIdx;
    _alarmHapticIntensity = hapticIntensity;

    await DatabaseHelper().saveImpostazioniSveglia(
      isEnabled: isEnabled,
      hour: alarmTime.hour,
      minute: alarmTime.minute,
      mode: selectedMode,
      goalIdx: targetGoalIdx,
      intensity: hapticIntensity,
    );

    if (isEnabled) {
      final now = DateTime.now();
      var alarmDateTime = DateTime(now.year, now.month, now.day, alarmTime.hour, alarmTime.minute);
      if (alarmDateTime.isBefore(now)) {
        alarmDateTime = alarmDateTime.add(const Duration(days: 1));
      }
      await scheduleHapticAlarm(alarmDateTime, vibrationPattern: hapticIntensity);
    } else {
      _hapticAlarmScheduler.cancelAlarm();
    }

    notifyListeners();
  }

  Future<bool> sendTestVibrationPulseNow() async {
    return await _bleManager.sendTestVibrationPulseNow();
  }

  List<VitalEvaluation> get vitalEvaluations {
    final current = _ultimoCiclo;
    final historical30dHrv = _cicliList.where((c) => c.vfcMs != null).map((c) => c.vfcMs!).toList();
    final historical30dRhr = _cicliList.where((c) => c.fcrBpm != null).map((c) => c.fcrBpm!.toDouble()).toList();
    final historical30dResp = _cicliList
        .where((c) => c.frequenzaRespiratoriaRpm != null && c.frequenzaRespiratoriaRpm! >= 7.0 && c.frequenzaRespiratoriaRpm! <= 24.0)
        .map((c) => c.frequenzaRespiratoriaRpm!)
        .toList();
    final historical30dSpo2 = _cicliList
        .where((c) => c.spo2Pct != null && c.spo2Pct! >= 85.0 && c.spo2Pct! <= 100.0)
        .map((c) => c.spo2Pct!.toDouble())
        .toList();
    final historical30dTemp = _cicliList
        .where((c) => c.tempCutaneaC != null && c.tempCutaneaC!.abs() <= 3.0)
        .map((c) => c.tempCutaneaC!)
        .toList();

    final respVal = (current?.frequenzaRespiratoriaRpm != null && current!.frequenzaRespiratoriaRpm! >= 7.0 && current.frequenzaRespiratoriaRpm! <= 24.0)
        ? current.frequenzaRespiratoriaRpm
        : null;

    final tempVal = (current?.tempCutaneaC != null && current!.tempCutaneaC!.abs() <= 3.0)
        ? current.tempCutaneaC
        : null;

    final spo2Val = (current?.spo2Pct != null && current!.spo2Pct! >= 85.0 && current.spo2Pct! <= 100.0)
        ? current.spo2Pct!.toDouble()
        : null;

    return [
      HealthVitalsEngine.evaluateVital(
        key: 'resp_rate',
        title: 'FREQUENZA RESPIRATORIA',
        currentValue: respVal,
        historical30dValues: historical30dResp,
        unit: 'rpm',
      ),
      HealthVitalsEngine.evaluateVital(
        key: 'spo2',
        title: 'OSSIGENO NEL SANGUE (SPO₂)',
        currentValue: spo2Val,
        historical30dValues: historical30dSpo2,
        unit: '%',
      ),
      HealthVitalsEngine.evaluateVital(
        key: 'fcr',
        title: 'FC A RIPOSO (FCR)',
        currentValue: current?.fcrBpm?.toDouble(),
        historical30dValues: historical30dRhr,
        unit: 'bpm',
      ),
      HealthVitalsEngine.evaluateVital(
        key: 'vfc',
        title: 'VARIABILITÀ FC (VFC)',
        currentValue: current?.vfcMs,
        historical30dValues: historical30dHrv,
        unit: 'ms',
      ),
      HealthVitalsEngine.evaluateVital(
        key: 'temp',
        title: 'TEMP. CUTANEA',
        currentValue: tempVal,
        historical30dValues: historical30dTemp,
        unit: '°C',
      ),
    ];
  }

  void _initProfileListener() {
    _profileSubscription = _userRepository.watchProfile().listen((profile) {
      if (profile != null) {
        _userProfile = profile;
        notifyListeners();
      }
    });
  }

  void _initBleListeners() {
    _hrSubscription = _bleManager.hrStream.listen((hrPacket) {
      _liveBpm = hrPacket.bpm;
      final now = DateTime.now();
      _autoWorkoutDetector.processBpmSample(_liveBpm, now);
      
      // Passa i dati di movimento (ENMO) all'AutoSleepDetector se disponibili dal pacchetto 96 byte
      final double? enmoVal = (_last96BytePacket != null && _last96BytePacket!.isValid)
          ? _last96BytePacket!.motionVariance
          : null;
      
      _autoSleepDetector.processBpmSample(
        _liveBpm, 
        now, 
        enmo: enmoVal,
        rmssd: _liveHrvRmssd > 0 ? _liveHrvRmssd : null,
      );

      if (hrPacket.rrIntervalsMs.isNotEmpty) {
        _rrBuffer.addAll(hrPacket.rrIntervalsMs);
        _liveHrvRmssd = _rrBuffer.rmssdMs;
      }

      if (_liveBpm > 0 && (_liveHrvRmssd > 0 || _ultimoCiclo?.vfcMs != null)) {
        final double? effectiveHrv = _liveHrvRmssd > 0 ? _liveHrvRmssd : _ultimoCiclo?.vfcMs;
        if (effectiveHrv != null && effectiveHrv > 0) {
          _liveStressIndex = WhoopAnalyticsEngine.calculateStressScore(
            hrLive: _liveBpm.toDouble(),
            hrRest: (_ultimoCiclo?.fcrBpm ?? _userProfile.hrRestBaseline).toDouble(),
            hrvLiveMs: effectiveHrv,
            baselineHrvMean: _userProfile.hrvBaselineMean,
            baselineHrvStd: _userProfile.hrvBaselineStd,
            accMagnitude: 1.0 + (enmoVal ?? 0.0),
          );

          // Salvataggio periodico diurno ogni 60 secondi su misurazioni_stress
          if (_liveStressIndex > 0) {
            final nowMs = now.millisecondsSinceEpoch;
            if (_lastStressSampleSaveMs == 0 || nowMs - _lastStressSampleSaveMs >= 60000) {
              _lastStressSampleSaveMs = nowMs;
              final dateIso = now.toIso8601String().substring(0, 10);
              DatabaseHelper().insertMisurazioneStress(
                dateIso,
                _liveStressIndex,
                effectiveHrv,
                _liveBpm,
              );
            }
          }
        }
      }
      _throttledBleNotifyListeners();
    });

    _packet96Subscription = _bleManager.packet96ByteStream.listen((p96) {
      _last96BytePacket = p96;
      
      // Estrai dati biometrici avanzati dal pacchetto 96 byte
      if (p96.isValid && p96.rawBytes.length >= 40) {
        final enmo = p96.motionVariance;
        final respPower = p96.respiratoryPower;
        final respRate = p96.respiratoryRate;
        final skinTemp = p96.skinTempRaw;
        final spo2Ratio = p96.spo2Ratio;
        final hrvRmssd = p96.hrvRmssdMs;

        if (p96.heartRateBpm > 0) {
          _liveBpm = p96.heartRateBpm;
          final now = p96.timestamp;
          _autoWorkoutDetector.processBpmSample(_liveBpm, now);
          _autoSleepDetector.processBpmSample(
            _liveBpm,
            now,
            enmo: enmo,
            rmssd: hrvRmssd > 0 ? hrvRmssd : null,
          );
        }
        
        debugPrint('[BLE 96-Byte] ENMO: ${enmo.toStringAsFixed(4)}g, RespPower: ${respPower.toStringAsFixed(2)}, RespRate: ${respRate.toStringAsFixed(1)} rpm, HRV: ${hrvRmssd.toStringAsFixed(1)} ms, TempRaw: $skinTemp, SpO2Ratio: ${spo2Ratio.toStringAsFixed(2)}');
        
        // Aggiorna HRV live se disponibile dal pacchetto 96 byte
        if (hrvRmssd > 0 && hrvRmssd < 200) {
          _liveHrvRmssd = hrvRmssd;
          if (_liveBpm > 0) {
            _liveStressIndex = WhoopAnalyticsEngine.calculateStressScore(
              hrLive: _liveBpm.toDouble(),
              hrRest: (_ultimoCiclo?.fcrBpm ?? _userProfile.hrRestBaseline).toDouble(),
              hrvLiveMs: _liveHrvRmssd,
              baselineHrvMean: _userProfile.hrvBaselineMean,
              baselineHrvStd: _userProfile.hrvBaselineStd,
              accMagnitude: 1.0 + enmo,
            );
          }
        }
      }
      
      _throttledBleNotifyListeners();
    });

    _bleStateSubscription = _bleManager.stateStream.listen((state) {
      _bleState = state;
      _bleStatusMessage = _bleManager.statusMessage;
      _isFallbackMode = _bleManager.fallbackModeActive;
      if (state == BleState.connected) {
        triggerOvernightSyncIfNeeded();
      }
      notifyListeners();
    });
  }

  void _throttledBleNotifyListeners({bool force = false}) {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final bpmChanged = _liveBpm != _lastNotifiedBpm;
    final hrvChanged = (_liveHrvRmssd - _lastNotifiedHrv).abs() >= 0.5;
    final stressChanged = (_liveStressIndex - _lastNotifiedStress).abs() >= 0.05;

    if (!force && !bpmChanged && !hrvChanged && !stressChanged) {
      return;
    }

    final elapsed = nowMs - _lastBleNotifyMs;
    if (elapsed >= _bleThrottleIntervalMs || force) {
      _bleThrottleTimer?.cancel();
      _bleThrottleTimer = null;
      _lastBleNotifyMs = nowMs;
      _lastNotifiedBpm = _liveBpm;
      _lastNotifiedHrv = _liveHrvRmssd;
      _lastNotifiedStress = _liveStressIndex;
      notifyListeners();
    } else {
      if (_bleThrottleTimer == null || !_bleThrottleTimer!.isActive) {
        final remainingMs = _bleThrottleIntervalMs - elapsed;
        _bleThrottleTimer = Timer(Duration(milliseconds: remainingMs), () {
          _lastBleNotifyMs = DateTime.now().millisecondsSinceEpoch;
          _lastNotifiedBpm = _liveBpm;
          _lastNotifiedHrv = _liveHrvRmssd;
          _lastNotifiedStress = _liveStressIndex;
          notifyListeners();
        });
      }
    }
  }

  Stream<List<ScanResult>> get scanResultsStream => _bleManager.scanResultsStream;
  BluetoothDevice? get connectedDevice => _bleManager.connectedDevice;
  String? get statusMessage => _bleManager.statusMessage;

  Future<void> startBleScan() async {
    await _bleManager.startScanAndConnect();
  }

  Future<void> startScanOnly() async {
    await _bleManager.startScanOnly();
  }

  Future<void> connectToDevice(BluetoothDevice device) async {
    await _bleManager.connectToSpecificDevice(device);
  }

  Future<void> disconnectBle() async {
    await _bleManager.disconnect();
    _liveBpm = 0;
    _liveHrvRmssd = 0.0;
    _liveStressIndex = 0.0;
    _lastStressSampleSaveMs = 0;
    notifyListeners();
  }

  /// Imposta la data selezionata nel navigatore < OGGI > e aggiorna reattivamente le query
  void setSelectedDate(DateTime date, {bool triggerAutoSync = true}) {
    _selectedDate = date;
    loadData(triggerAutoSync: triggerAutoSync);
  }

  /// Carica i dati per la data selezionata direttamente da SQLite
  Future<void> loadData({bool triggerAutoSync = true}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _repository.initializeAndSeedDatabase();
      unawaited(RawCaptureService.instance.init());

      if (_bleManager.state == BleState.disconnected || _bleManager.state == BleState.reconnecting) {
        await _bleManager.ensureConnected();
      }

      // Carica preferenze Dashboard da DB
      final savedTiles = await _dashboardPreferencesRepository.getEnabledTiles();
      if (savedTiles.isNotEmpty) {
        _enabledTileKeys = savedTiles;
      }

      // Carica profilo utente da DB
      final profile = await _userRepository.getProfile();
      if (profile != null) {
        _userProfile = profile;
      }

      final dateKey = _selectedDate.toIso8601String().substring(0, 10);

      // Esegui query per la data selezionata
      final cicli = await _repository.getCicliFisiologici();
      _cicliList = cicli;
      _streakDays = SqliteWhoopRepository.calculateStreakDays(cicli);

      final dateCicli = cicli.where((c) => c.dataIso == dateKey).toList();
      _ultimoCiclo = dateCicli.isNotEmpty ? dateCicli.first : null;

      final allAllenamenti = await _repository.getAllenamenti();
      _allenamentiList = allAllenamenti.where((a) => a.dataIso == dateKey).toList();

      final allSonno = await _repository.getSonnoLogs();
      _sonnoList = allSonno.where((s) => s.dataIso == dateKey).toList();

      final allDiario = await _repository.getVociDiario();
      _vociDiarioList = allDiario.where((v) => v.dataIso == dateKey).toList();

      final stressRows = await DatabaseHelper().getMisurazioniStressByDate(dateKey);
      if (stressRows.isNotEmpty) {
        _savedStressScore = (stressRows.last['valore_stress'] as num).toDouble();
      } else {
        _savedStressScore = 0.0;
      }

      final alarmData = await DatabaseHelper().getImpostazioniSveglia();
      _isAlarmEnabled = (alarmData['is_enabled'] as int) == 1;
      _alarmTime = TimeOfDay(
        hour: alarmData['alarm_hour'] as int,
        minute: alarmData['alarm_minute'] as int,
      );
      _alarmModeIdx = alarmData['selected_mode'] as int;
      _alarmGoalIdx = alarmData['target_goal_idx'] as int;
      _alarmHapticIntensity = alarmData['haptic_intensity'] as int;

      // Carica dati grafici aggregati da SQLite per la data selezionata (CHT-01..04, STG-07)
      final dayStart = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, 0, 0, 0);
      final dayEnd = dayStart.add(const Duration(days: 1));
      _isChartsLoading = true;
      try {
        _currentHypnogramSegments = await DatabaseHelper().getHypnogramSegments(dateKey);
        _currentIntradayHrBuckets = await DatabaseHelper().getIntradayHrBuckets(dayStart, dayEnd, bucketMinutes: 1);
        _currentHrZones = await DatabaseHelper().getHrZoneDistribution(dayStart, dayEnd, _userProfile.hrMax.toDouble());
      } catch (err) {
        debugPrint('WhoopViewModel: Errore caricamento aggregazioni grafici: $err');
      } finally {
        _isChartsLoading = false;
      }

      if (triggerAutoSync && !DatabaseHelper.isTestMode) {
        await triggerOvernightSyncIfNeeded();
      }
    } catch (e) {
      _errorMessage = 'Errore durante il caricamento dei dati: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Recupera i segmenti dell'ipnogramma per una data specifica (STG-07, CHT-02)
  Future<List<Map<String, dynamic>>> loadHypnogramSegments(String dateIso) async {
    return await DatabaseHelper().getHypnogramSegments(dateIso);
  }

  /// Recupera i bucket aggregati di frequenza cardiaca intraday (CHT-02)
  Future<List<Map<String, dynamic>?>> loadIntradayHrBuckets(
    DateTime start,
    DateTime end, {
    int bucketMinutes = 1,
  }) async {
    return await DatabaseHelper().getIntradayHrBuckets(start, end, bucketMinutes: bucketMinutes);
  }

  /// Calcola la distribuzione del tempo nelle 5 zone cardiache (CHT-02)
  Future<Map<String, dynamic>> loadHrZoneDistribution(
    DateTime start,
    DateTime end, {
    double? maxHr,
  }) async {
    return await DatabaseHelper().getHrZoneDistribution(start, end, maxHr ?? _userProfile.hrMax.toDouble());
  }

  /// Caricamento iniziale all'avvio dell'applicazione
  Future<void> loadInitialData() => loadData();

  /// Verifica ed esegue il sync notturno automatico se per oggi manca ancora il sonno e il recovery
  Future<void> triggerOvernightSyncIfNeeded() async {
    if (DatabaseHelper.isTestMode) return;
    final todayIso = DateTime.now().toIso8601String().substring(0, 10);

    final existingCicli = _cicliList.where((c) => c.dataIso == todayIso).toList();
    final hasRecovery = existingCicli.isNotEmpty && existingCicli.first.punteggioRecuperoPct != null;

    if (!hasRecovery) {
      // 1. Prova prima a recuperare i dati reali registrati su SQLite nelle ultime 14 ore
      final now = DateTime.now();
      final lastNightStart = now.subtract(const Duration(hours: 14));
      var records = await DatabaseHelper().getTelemetriaInTimeRange(lastNightStart, now);

      // 2. Se su SQLite non ci sono dati, controlla il buffer in RAM del daemon di background
      if (records.isEmpty) {
        records = _backgroundDaemon.getNocturnalTelemetryRecords();
      }

      if (records.isEmpty) {
        // Nessun record di telemetria notturna reale registrato: lascia lo stato vuoto
        return;
      }
      debugPrint('WhoopViewModel: Esecuzione sincro notturno automatico per la data $todayIso (${records.length} campioni)...');
      final result = await _overnightSleepEngine.processNightlyTelemetry(
        rawTelemetryRecords: records,
        userBaseline30d: {
          'rhr_mean': _userProfile.rhrBaselineMean,
          'rmssd_mean': _userProfile.hrvBaselineMean,
          'rmssd_std': _userProfile.hrvBaselineStd,
          'baseline_temp_celsius': _userProfile.baselineSampleCount >= 4 ? 36.5 : null,
        },
      );
      if (result['has_data'] == true) {
        // Ricarica la lista cicli e sonno da SQLite
        final cicli = await _repository.getCicliFisiologici();
        _cicliList = cicli;
        final dateCicli = cicli.where((c) => c.dataIso == todayIso).toList();
        if (dateCicli.isNotEmpty) {
          _ultimoCiclo = dateCicli.first;
        }
        final allSonno = await _repository.getSonnoLogs();
        _sonnoList = allSonno.where((s) => s.dataIso == todayIso).toList();
        notifyListeners();
      }
    }
  }

  /// Registra un Allenamento con ricalcolo a cascata
  Future<void> addWorkout(Allenamento allenamento) async {
    await _repository.insertAllenamento(allenamento);
    await loadData();
  }

  /// Registra una sessione di Sonno con ricalcolo a cascata
  Future<void> addSleep(Sonno sonno) async {
    await _repository.insertSonno(sonno);
    await loadData();
  }

  /// Processa e registra un Sonno Manuale leggendo i dati di telemetria da SQLite
  Future<Map<String, dynamic>> processAndAddManualSleep({
    required DateTime startTime,
    required DateTime endTime,
    required String dateIso,
    bool allowFallback = true,
  }) async {
    // 1. Query Dati Biometrici nel Range
    final dbPoints = await DatabaseHelper().getTelemetriaInTimeRange(startTime, endTime);
    final bool hasRealBleData = dbPoints.isNotEmpty;

    debugPrint('processAndAddManualSleep: Trovati ${dbPoints.length} campioni BLE per la finestra $startTime - $endTime (hasRealBleData: $hasRealBleData)');
    
    // 2. Invocazione dell'OvernightSleepEngine (processamento staging reale se presenti campioni; altrimenti registrazione pura USER_ENTERED con zero stadi e vitali null)
    final engineResult = await _overnightSleepEngine.processNightlyTelemetry(
      rawTelemetryRecords: dbPoints,
      userBaseline30d: {
        'rhr_mean': _userProfile.rhrBaselineMean,
        'rmssd_mean': _userProfile.hrvBaselineMean,
        'rmssd_std': _userProfile.hrvBaselineStd,
        'baseline_temp_celsius': 36.5,
      },
      windowStart: startTime,
      windowEnd: endTime,
      targetDateIso: dateIso,
    );

    // 3. Aggiornamento data attiva e refresh reattivo senza sovrascrittura auto-sync
    try {
      _selectedDate = DateTime.parse(dateIso);
    } catch (e) {
      debugPrint('[WhoopViewModel] Error parsing dateIso "$dateIso": $e');
    }
    await loadData(triggerAutoSync: false);
    notifyListeners();

    return {
      'success': true,
      'noTelemetryFound': !hasRealBleData,
      'hasRealBleData': hasRealBleData,
      'engineResult': engineResult,
      'recoveryScore': engineResult['recovery_score'],
      'totalSleepMin': engineResult['total_sleep_min'],
      'swsMin': engineResult['sws_min'],
      'remMin': engineResult['rem_min'],
      'lightMin': engineResult['light_min'],
      'respiratoryRate': engineResult['respiratory_rate'],
      'skinTempDelta': engineResult['skin_temperature_delta_c'] ?? engineResult['delta_skin_temp'],
      'spo2Pct': engineResult['spo2_percentage'] ?? engineResult['spo2'],
      'rhr': engineResult['resting_hr_bpm'] ?? engineResult['rhr'],
      'hrv': engineResult['hrv_rmssd_ms'] ?? engineResult['rmssd'],
    };
  }

  /// Registra una Voce Diario
  Future<void> addJournalEntry(VoceDiario voce) async {
    await _repository.insertVoceDiario(voce);
    await loadData();
  }

  /// Aggiorna i dati anagrafici e basali del profilo utente su SQLite
  Future<void> updateUserProfile({
    required String name,
    required int maxHr,
    required int baselineRhr,
    required double baselineHrv,
    int? age,
    double? hrvStd,
    double? rhrStd,
    int? sleepBaselineMin,
  }) async {
    final updated = _userProfile.copyWith(
      nome: name,
      hrMax: maxHr,
      hrRestBaseline: baselineRhr,
      hrvBaselineMean: baselineHrv,
      eta: age ?? _userProfile.eta,
      hrvBaselineStd: hrvStd ?? _userProfile.hrvBaselineStd,
      rhrBaselineMean: baselineRhr.toDouble(),
      rhrBaselineStd: rhrStd ?? _userProfile.rhrBaselineStd,
      sleepBaselineMin: sleepBaselineMin ?? _userProfile.sleepBaselineMin,
    );

    await _userRepository.updateProfile(updated);
    _userProfile = updated;
    notifyListeners();
  }

  double get currentSleepNeedMinutes {
    final strain = _ultimoCiclo?.sforzoGiornaliero ?? 0.0;
    return WhoopAnalyticsEngine.calculateSleepNeedMinutes(
      baselineNeedMin: _userProfile.sleepBaselineMin.toDouble(),
      dayStrain: strain,
    ).toDouble();
  }

  HabitImpactResult getHabitImpact(String habitQuestion) {
    final records = _vociDiarioList
        .where((v) => v.chiaveDomanda == habitQuestion)
        .map((v) => JournalHabitRecord(
              habitQuestion: v.chiaveDomanda,
              answeredYes: v.rispostaBool,
              date: v.oraInizioCiclo,
              nextDayRecoveryPct: _ultimoCiclo?.punteggioRecuperoPct ?? 75.0,
              nextDaySleepPct: _ultimoCiclo?.andamentoSonnoPct ?? 85.0,
            ))
        .toList();

    return _biometricEngine.calculateJournalHabitImpact(
      habitQuestion: habitQuestion,
      records: records,
    );
  }

  @override
  void dispose() {
    try {
      WidgetsBinding.instance.removeObserver(this);
    } catch (e) {
      debugPrint('[WhoopViewModel] WidgetsBinding.removeObserver notice: $e');
    }
    _bleThrottleTimer?.cancel();
    _hrSubscription?.cancel();
    _packet96Subscription?.cancel();
    _bleStateSubscription?.cancel();
    _profileSubscription?.cancel();
    _autoWorkoutSubscription?.cancel();
    _autoSleepSubscription?.cancel();
    _autoWorkoutDetector.dispose();
    _autoSleepDetector.dispose();
    _hapticAlarmScheduler.dispose();
    _backgroundDaemon.stopDaemon();
    _bleManager.dispose();
    super.dispose();
  }
}
