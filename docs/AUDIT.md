# WHOOP CLONE — FORENSIC ARCHITECTURAL AUDIT (PHASE 0)

> **Document Version:** 1.0.0  
> **Date:** October 2026  
> **Status:** AUDIT COMPLETED — BASELINE ESTABLISHED  
> **Scope:** Full repository forensic inspection (`whoop_clone/lib`, `whoop_clone/test`, `android`, `docs`)

---

## 1. Executive Summary & Audit Mandate

This forensic audit evaluates the integrity, reliability, and correctness of the WHOOP Clone codebase. The fundamental directive governing this project is:

$$\text{REAL DEVICE DATA} \longrightarrow \text{RELIABLE INGESTION} \longrightarrow \text{ACCURATE PERSISTENCE} \longrightarrow \text{PHYSIOLOGICAL PROCESSING} \longrightarrow \text{TRUTHFUL UI}$$

Prior to this audit, superficial unit tests were passing, creating a false impression of feature completeness. However, deep forensic analysis revealed critical architectural vulnerabilities, including synthetic physiological fallbacks, silent errors, missing ingestion stages, and unverified mock states.

**Zero-Tolerance Policy:** No physiological value ($\text{HR}$, $\text{HRV}$, $\text{RHR}$, $\text{ENMO}$, $\text{SpO}_2$, $\text{Respiration}$, $\text{Sleep Stages}$, $\text{Recovery}$) may ever be invented, guessed, or approximated from arbitrary defaults. 

$$\text{NO DATA} \equiv \text{NULL / MISSING}$$

---

## 2. End-to-End Component Audit Matrix

Below is the forensic breakdown of every architectural component in the data pipeline.

```
[BLE Antenna] 
      │
      ▼
[BleConnectionManager] (GATT, CCCD 0x2A37, 96-Byte 0x61080005)
      │
      ▼
[TelemetryIngestionService] (Timestamp, Sequence Check, CRC8/16/32, Deduplication, Quality Gate)
      │
      ▼
[DatabaseHelper / telemetria_grezza] (Single Source of Truth, Audit Columns, Raw Payloads)
      │
      ▼
[OvernightSleepEngine & Biometric Engines] (Epochs, SWS/REM/Light/Wake/Missing, Baseline, Recovery, Strain)
      │
      ▼
[Repositories & WhoopViewModel] (Reactive Streams, Throttling, State Machine)
      │
      ▼
[Presentation / UI Widgets] (Truthful Cards, Provenance Indicators, Empty/Error States)
```

---

### Component 1: BLE Hardware Communication & Characteristics
* **File:** `lib/data/ble/ble_connection_manager.dart`
* **What it receives:** Raw BLE advertising packets, GATT service discovery events, characteristic notifications from `0x180D`/`0x2A37` (Standard BLE Heart Rate) and proprietary UUID `61080005-8d6d-82b8-614a-1c8cb0f8dcc6` (WHOOP 4.0/5.0 96-byte packet).
* **What it produces:** Broadcast streams: `hrStream` (`HrDataPacket`), `packet96ByteStream` (`Whoop96BytePacket`), `stateStream` (`BleState`), `batteryStream` (`int`), `ackNotificationStream` (`List<int>`).
* **Source of data:** Real physical Bluetooth Low Energy hardware via `flutter_blue_plus`.
* **Where saved:** Emits into in-memory `StreamController.broadcast()` instances.
* **Fallbacks present:**
  - `_fallbackModeActive`: switches to standard BLE HR if proprietary characteristic discovery times out after 12 seconds.
  - `sendHapticVibrationCommand()` returns `true` (lines 865–912) even when the strap is completely disconnected or write fails, relying solely on phone local haptics.
* **Hardcoded values:**
  - Timeout durations (12s, 30s).
  - Fixed retry backoff delays (2s, 4s, 8s, 16s).
  - Packet counter increment increments `+1`, `+3`, `+4` (lines 858, 905).
* **Hidden errors:**
  - In `writeAlarmCommand`: generic `catch (e)` logs to `debugPrint` and returns `false` without propagating connection breakages.
  - Multi-listener race conditions: `WhoopViewModel` and `BackgroundSyncDaemon` both consume the raw stream directly without an arbitrating coordinator.
* **Missing data behavior:** Emits nothing; UI streams stay idle unless ViewModel uses stale cache.
* **Test coverage:** `zero_scan_test.dart`, `sprint6_zero_mock_ble_test.dart`, `haptic_vibration_test.dart`. Tests currently verify mock state transitions but do not simulate corrupted packet streams or characteristic dropouts.

---

### Component 2: Packet Decoding & CRC Verification
* **Files:** `lib/data/ble/whoop_96byte_packet.dart`, `lib/data/ble/noop_protocol_decoder.dart`, `lib/data/services/noop_ble_decoder.dart`
* **What it receives:** Byte arrays (`List<int>` / `Uint8List`) of length 20 to 96+ bytes.
* **What it produces:** Typed packet objects: `Whoop96BytePacket`, `HrDataPacket`, `NoopTelemetryFrame`.
* **Source of data:** Raw BLE characteristic notifications.
* **Where saved:** In-memory instances passed to subscribers.
* **Fallbacks present:**
  - In `whoop_96byte_packet.dart`:
    - `motionVariance` (lines 48–55): returns `0.002` if `enmo <= 0` or if bytes length < 12!
    - `skinTempRaw` (lines 80–86): returns `0` on short packets.
  - In `noop_ble_decoder.dart`:
    - Disconnected legacy file. Not used in production data path.
* **Hardcoded values:**
  - AS6221 temperature conversion multiplier: `0.0078125` (line 117 `noop_system_services.dart`).
  - SpO2 linear calibration equation: `110.0 - (25.0 * rRatio)` clamped `85..100%`.
* **Hidden errors:**
  - `noop_ble_decoder.dart` has an invalid sequence offset (`getUint16(0)` on 0xAA frames instead of byte 2).
  - Endianness assumptions on custom frames without length verification.
* **Missing data behavior:** Default values (`0.002`, `0.0`) injected if fields are truncated.
* **Test coverage:** `crc_validation_test.dart`, `noop_engine_test.dart`. Lacks automated golden packet fixture testing with raw hex dumps.

---

### Component 3: Telemetry Ingestion Layer (Current State: MISSING)
* **Current Implementation:** Directly consumed in ad-hoc fashion across `BackgroundSyncDaemon` (`noop_system_services.dart`), `WhoopViewModel` (`whoop_viewmodel.dart`), and auto-detectors.
* **Vulnerability:**
  - No sequence tracking or packet gap detection.
  - No packet loss rate counter (`packetsReceived`, `packetsSaved`, `packetsDuplicate`, `packetsMissing`).
  - No deduplication layer before database writes.
  - Ingestion latency is unmeasured.

---

### Component 4: Raw Telemetry Persistence (`telemetria_grezza`)
* **File:** `lib/data/database/database_helper.dart`
* **What it receives:** Discrete sensor values (`bpm`, `rrMs`, `accelEnmo`, `motionVar`, `skinTempCelsius`, `spo2Pct`, `respRate`, `respPower`).
* **What it produces:** SQLite database records in `telemetria_grezza`.
* **Source of data:** Listeners in `BackgroundSyncDaemon` and `WhoopViewModel`.
* **Where saved:** SQLite table `telemetria_grezza`.
* **Fallbacks present:**
  - Table schema definition contains: `accel_enmo REAL DEFAULT 0.002`, `motion_var REAL DEFAULT 0.002`!
  - `rr_ms` is conflated: stores `rmssd` instead of raw RR interval duration.
* **Missing metadata columns:**
  - Lacks: `device_id`, `session_id`, `sequence_number`, `packet_type`, `raw_payload`, `decoder_version`, `crc_valid`, `is_valid`, `received_at`, `device_timestamp`, `ingest_latency_ms`, `duplicate`, `source`, `quality`.
* **Hardcoded values:** Default pruning policy of 7 days (`pruneOldTelemetry({int daysToKeep = 7})`) which risks dropping un-synced offline records.
* **Hidden errors:** Concurrency race in database initialization (mitigated recently via `Completer<Database>`, but transactions are needed on bulk ingest).

---

### Component 5: Overnight Sleep Engine & Staging
* **File:** `lib/data/services/overnight_sleep_engine.dart`
* **What it receives:** Raw telemetry rows from `telemetria_grezza` bounded by `windowStart` and `windowEnd`.
* **What it produces:** Sleep session records: `Sonno`, `CicloFisiologico`, hypnogram epochs (`Epoch30s`), stage breakdowns (Deep, REM, Light, Awake), sleep efficiency, and performance.
* **Source of data:** SQLite query `getTelemetriaInTimeRange(windowStart, windowEnd)`.
* **Critical Fallbacks Present (P0 Blockers):**
  - **Lines 948–952:**
    ```dart
    final motion = (r['motion_var'] ?? r['motion'] ?? r['enmo'] ?? 0.002).toDouble();
    final hr = (r['hr'] ?? r['bpm'] ?? 55.0).toDouble();
    final rmssd = (r['rmssd'] as num?)?.toDouble() ?? 68.0;
    final respPower = (r['resp_power'] ?? 0.7).toDouble();
    ```
    If telemetry is missing or null, synthetic physiology (HR=55, RMSSD=68, ENMO=0.002, RespPower=0.7) is injected!
  - **Lines 1005–1006 & 1070–1080:**
    ```dart
    double lastHr = 55.0;
    double lastRmssd = 65.0;
    ...
    // Missing epoch fabrication:
    list.add(Epoch30s(
      timestamp: epochTime,
      motionVar: 0.015,
      hr: lastHr,
      rmssd: lastRmssd,
      respPower: 0.40,
      stage: SleepStage.light, // <-- TURNS MISSING DATA INTO FAKE LIGHT SLEEP!
    ));
    ```
  - **Lines 313–318 (`ingestSample`):**
    ```dart
    final double enmoVal = enmo ?? (hr < restHr + 10.0 ? 0.003 : 0.060);
    final double rmssdVal = rmssd ?? hrvBaseline;
    final double rPower = respPower ?? (hr < restHr + 8.0 ? 0.70 : 0.40);
    ```
  - **Line 700 (`processNightlyTelemetry` on manual sleep):**
    ```dart
    'light_min': totalManualSleepMin // Fabricates light sleep for manual entry!
    ```
* **Missing data behavior:** Produces fabricated sleep stages and synthetic recovery instead of flagging `MISSING` or `USER_ENTERED (No Vitals)`.

---

### Component 6: Baseline & Recovery Engines
* **Files:** `lib/data/biometrics/recovery_engine.dart`, `lib/domain/analytics/whoop_analytics_engine.dart`
* **What it receives:** Nightly vitals: SWS-period $rMSSD$, nocturnal $RHR$, sleep performance percentage, nocturnal stress index, skin temperature deviation, respiratory rate deviation.
* **What it produces:** `RecoveryBaselineResult`, `recoveryScore` ($1\% - 99\%$), `RecoveryZone` (Green, Yellow, Red).
* **Fallbacks present:**
  - In `recovery_engine.dart` lines 110–116: default optional arguments in `calculateRecoveryScore` silently assume `currentRespRateRpm = 14.5`, `baselineRespRateRpm = 14.0`, `sleepEfficiencyPct = 90.0`, `sleepPerformancePct = 85.0`, `nightlyStress = 0.5`.
  - Cold start baseline (days < 4) falls back to hardcoded `log(65.0)` and `52.0 bpm`.
  - In `whoop_viewmodel.dart` lines 431, 446: falls back to `_userProfile.hrvBaselineMean` (65.0 ms) if live HRV is zero.
* **Hidden errors:**
  - `calculateLnRmssd(0.0)` returns `0.0`, which causes extreme uncalibrated z-score distortion rather than halting calculation for missing HRV.

---

### Component 7: Streak Calculation Engine
* **Files:** `lib/data/repositories/sqlite_whoop_repository.dart`, `lib/viewmodels/whoop_viewmodel.dart`
* **What it receives:** List of `CicloFisiologico` records from database.
* **What it produces:** Continuous streak counter `_streakDays` (`int`).
* **Vulnerability:**
  - Lines 135–142 in `sqlite_whoop_repository.dart`: A day is considered active if `strainGiornaliero > 0` OR any vitals exist. A stray 0.1 strain or partial fragmented day is treated as a completed streak day.
  - Criterial rigor required: Valid completed day must have confirmed physiological recording or verified sleep cycle.

---

### Component 8: Haptics & Alarm Execution
* **Files:** `lib/data/ble/ble_connection_manager.dart`, `lib/data/services/haptic_alarm_service.dart`
* **What it receives:** Alarm trigger requests, haptic pulse patterns.
* **What it produces:** Command byte frames to BLE characteristic, local device vibration via `HapticFeedback`.
* **Vulnerability:**
  - Return value `true` in `sendHapticVibrationCommand` falsely indicates strap vibration when strap is disconnected.
  - Must return structured `HapticResultStatus`:
    `PHONE_HAPTIC_ONLY`, `STRAP_COMMAND_SENT`, `STRAP_ACKNOWLEDGED`, `STRAP_FAILED`, `NOT_CONNECTED`.

---

### Component 9: ViewModel & UI Presentation Layer
* **Files:** `lib/viewmodels/whoop_viewmodel.dart`, `lib/views/**`
* **What it receives:** Streams from repositories, BLE manager, and analytics engines.
* **What it produces:** Observable state properties for Flutter widget tree.
* **Vulnerability:**
  - Manual sleep trigger (`processAndAddManualSleep`, line 715) defaults to `allowFallback = true`.
  - Widgets display placeholder values when properties are null or empty instead of dedicated "No Data / Disconnected" state badges.
  - Missing provenance badges (REAL_MEASUREMENT, DEVICE_DERIVED, USER_ENTERED, ESTIMATED).

---

## 3. Data Integrity & Ingestion Forensic Checklist

| Checkpoint | Target | Current Status | Remediation Required |
|---|---|---|---|
| **Zero Synthetic Physiology** | No HR/HRV/Resp defaults | **FAILED** | Eliminate lines 948-952, 1005, 1070 in `overnight_sleep_engine.dart` |
| **Missing Epoch Staging** | Empty epochs $\to$ `MISSING` | **FAILED** | Add `SleepStage.missing`, eliminate auto-`light` |
| **Manual Sleep Isolation** | No fake stages on user entry | **FAILED** | Remove `allowFallback=true`, stages=0, vitals=null |
| **Sequence & Gap Tracking** | Track packet loss & duplicates | **MISSING** | Implement `TelemetryIngestionService` |
| **SQLite Source of Truth** | Audit columns & raw payload | **PARTIAL** | Schema migration v15 with seq, crc, quality, payload |
| **BLE State Machine** | 10 discrete verified states | **PARTIAL** | Replace 8-state enum with full state machine |
| **Haptic Truthfulness** | Verified ACK / Disconnected state | **FAILED** | Return explicit enum status, not false `true` |
| **Golden Packet Fixtures** | Raw hex fixture test suite | **MISSING** | Create `test/fixtures/ble/` suite |
| **End-to-End Pipeline Test** | BLE Antenna $\to$ UI trace test | **MISSING** | Create `test/e2e/e2e_pipeline_verification_test.dart` |

---

## 4. Immediate Remediation Action Plan

1. **Step 1 (Phase 1):** Remove all fallback constants (`55.0`, `65.0`, `68.0`, `0.002`, `0.7`, `0.015`) across all analytics engines. Add `SleepStage.missing` and `SleepStage.unknown`.
2. **Step 2 (Phase 2 & 5):** Create `TelemetryIngestionService` with packet validation, deduplication, sequence gap tracking, and telemetry diagnostics.
3. **Step 3 (Phase 3 & 4):** Upgrade SQLite schema to v15 adding raw payload, sequence number, crc validity, and quality flags.
4. **Step 4 (Phase 6 & 7):** Refactor `BleConnectionManager` with explicit states and truthful haptics.
5. **Step 5 (Phase 8):** Build golden packet fixtures suite for all supported Whoop packet variants.
6. **Step 6 (Phases 9–18):** Harden sleep, recovery, baseline, streak, profile, and UI layers with behavioral GIVEN-WHEN-THEN tests.
