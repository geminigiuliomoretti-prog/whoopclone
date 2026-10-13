# Forensic System & Data Pipeline Fix Report
**WHOOP Clone — Engineering Forensic Analysis & Repair**
*Author: DeepMind Antigravity Pair Programmer*  
*Date: 2026-10-07*  
*Validation: 204 automated unit/integration tests passing (100%), 0 analyze lints*

---

## Executive Summary
This document provides a comprehensive forensic analysis of the core biological data pipelines, sensor decoders, mathematical staging algorithms, and edge-case behaviors of the WHOOP 5.0 clone. In compliance with the strict **NO FAKE DATA** directive, all synthetic fallbacks masquerading as physiological biometrics (`?? 55`, `?? 65`, `?? 480`, `?? 0.002`, `HRV + 8`, `RHR + 2`, `RR + 1.9`, and steps fabricated from strain) were eliminated.

Every calculation is now fully data-driven, deriving directly from genuine BLE telemetry packets, store-and-forward archives, or user inputs with strict distinction between `MEASURED`, `ESTIMATED`, `DEFAULT`, `MISSING`, and `INVALID` states.

---

## Forensic Problem Analyses & Root Cause Fixes

### P0.1: Semantic Conflation between RR Intervals and HRV (rMSSD)
- **Problem**: In several components, inter-beat RR intervals (600–1200 ms) were conflated with root-mean-square of successive differences (rMSSD, 20–150 ms) or synthetic instantaneous RR intervals were fabricated from heart rate (`60000.0 / bpm`).
- **Root Cause**: `noop_ble_decoder.dart` previously synthesized `instantaneousRr = 60000.0 / rawHr` and mapped it to `rr_ms`. In `overnight_sleep_engine.dart`, line 680 had mapped SQLite's `rmssd_ms` as `'rmssd': rr` and contained heuristics assuming anything `< 250` was rMSSD, creating circular data pollution.
- **Files Affected**:
  - `lib/data/services/noop_ble_decoder.dart`
  - `lib/data/services/overnight_sleep_engine.dart`
  - `lib/data/services/noop_analytics_engine.dart`
  - `lib/data/database/database_helper.dart`
- **Changes**:
  1. In `NoopBleDecoder.decodeTelemetryPacket`: removed synthetic `instantaneousRr` derivation. Added dedicated `rmssdMs` property to `NoopTelemetryFrame` and database dictionary `'rmssd_ms'`. Left `rrList` empty for 96-byte packets which only provide aggregate epoch rMSSD.
  2. For standard BLE 0x180D heart rate measurement packets containing genuine discrete RR intervals, applied Task Force 1996 rMSSD calculation over adjacent inter-beat intervals.
  3. In `DatabaseHelper.insertTelemetriaPoint`: disambiguated inputs at the ingestion boundary. Valid RR intervals are strictly bounded to `[300..2000 ms]`; if a caller passes `rrMs <= 250.0`, it is categorized as `rmssd_ms`.
  4. In `OvernightSleepEngine`: separated `rawRr` and `rawRmssd`. `ppIntervals` only accepts valid beat-to-beat intervals `>= 300 ms`.
- **Test**: `test/forensic_negative_edge_cases_test.dart` (Test 4, 6), `test/auto_sleep_pipeline_test.dart`.
- **Result**: PASSED. RR intervals and rMSSD are completely independent physiological concepts.
- **Remaining Limitations**: The proprietary 96-byte WHOOP telemetry packet provides pre-calculated epoch rMSSD rather than raw millisecond beat timestamps. Discrete RR intervals are available when standard BLE heart rate service streams.

---

### P0.2: BLE Decoding Pipeline Duplication (Single Source of Truth)
- **Problem**: Multiple uncoordinated services were decoding the same raw BLE telemetry streams using disparate byte offsets and independent parsing logic.
- **Root Cause**: `BackgroundSyncDaemon` in `noop_system_services.dart` maintained redundant manual byte extraction routines (`_extractFloat32LE`, `_extractUint16LE`), ignoring `Whoop96BytePacket` validated decoders. Furthermore, it generated fabricated timestamps using `now.subtract(Duration(seconds: totalCount - i))`.
- **Files Affected**:
  - `lib/data/services/noop_system_services.dart`
  - `lib/data/ble/noop_protocol_decoder.dart`
- **Changes**:
  1. Refactored `BackgroundSyncDaemon` to ingest and decode via `Whoop96BytePacket.fromBytes()`.
  2. Direct extraction of verified properties: `motionVariance`, `respiratoryPower`, `respiratoryRate`, `skinTempRaw`, `spo2Ratio`, `hrvRmssdMs`, `heartRateBpm`.
  3. Added `_NocturnalSample` to capture authentic packet timestamps from the device clock rather than generating synthetic backward offsets from current wall clock.
- **Test**: `test/telemetry_ingestion_service_test.dart`, `test/golden_packet_suite_test.dart`.
- **Result**: PASSED. Single source of truth established across live streaming and background daemon.
- **Remaining Limitations**: Dependent on the strap transmitting valid CRC-32 frames (corrupt frames are safely dropped).

---

### P0.3: Elimination of Physiological Fallbacks Masquerading as Real Data
- **Problem**: Missing sensor data was masked using hardcoded constants (`?? 55`, `?? 65`, `?? 480`, `?? 0.002`). This caused stationary users to appear as having accelerometer noise and users without baseline to receive calibrated scores.
- **Root Cause**: Null-coalescing operators in `BackgroundSyncDaemon`, `noop_ble_decoder.dart`, and `utente_profilo.dart` injected nominal population averages.
- **Files Affected**:
  - `lib/data/services/noop_ble_decoder.dart`
  - `lib/data/models/utente_profilo.dart`
  - `lib/data/io/noop_import_export_service.dart`
  - `lib/data/services/noop_system_services.dart`
- **Changes**:
  1. Replaced `motion_var ?? 0.002` with `0.0` (true stationary zero).
  2. Implemented strict baseline state gating in `UtenteProfilo`: `hasEstablishedBaseline` (>=14d), `isCalibrating` (4-13d), `hasNoBaselineData` (0-3d).
  3. In `NoopImportExportService.recalculateBaselineFromHistory`: flagged baseline source as `ROLLING_DEVICE_HISTORY` only when `>= 3` authentic sessions exist; otherwise leaves baseline uncalibrated.
- **Test**: `test/zero_fake_data_behavioral_test.dart`, `test/forensic_negative_edge_cases_test.dart` (Test 2, 4).
- **Result**: PASSED. Missing biometrics are displayed as `--` / `null` without artificial defaults.
- **Remaining Limitations**: None. Unconnected or freshly initialized straps truthfully indicate calibration status.

---

### P0.4: Respiratory Rate Pipeline Audit
- **Problem**: Potential usage of rMSSD or heart-rate fluctuation as input to respiratory rate estimation, leading to inaccurate frequencies.
- **Root Cause**: Heuristics in spectral analysis lacked strict input hierarchy and fell back to simple arithmetic averages of RR intervals when DFT spectral peaks were unclear.
- **Files Affected**:
  - `lib/data/services/overnight_sleep_engine.dart`
- **Changes**:
  1. Established strict extraction hierarchy:
     - Direct strap respiratory rate (`p['resp_rate']`) if valid `[7..24 RPM]`.
     - Respiratory Sinus Arrhythmia (RSA) peak extraction via Discrete Fourier Transform (DFT) over valid inter-beat `ppIntervals` (0.12–0.40 Hz band).
     - Centered 1-Hz BPM time-series DFT only when continuous pulse intervals are absent.
     - Returns `null` if telemetry quality is insufficient. Never uses rMSSD as respiratory input.
  2. Added Mayer wave rejection (0.10 Hz sympathetic blood pressure oscillation).
- **Test**: `test/forensic_negative_edge_cases_test.dart` (Test 10), `test/past_sleep_vitals_extraction_test.dart`.
- **Result**: PASSED. Locks onto genuine ~0.23 Hz RSA (13.8 RPM) without confusing 0.10 Hz Mayer waves.
- **Remaining Limitations**: Requires at least 60 seconds of continuous telemetry to compute spectral DFT.

---

### P0.5: Sleep Detection: Distinguishing Couch Resting from Sleep
- **Problem**: Sedentary inactivity while watching TV or reading on a couch (low motion, heart rate ~64 bpm) was erroneously classified as sleep onset.
- **Root Cause**: Prior sleep detectors relied purely on motion thresholds (quiescent ENMO) without circadian time gating or autonomic heart-rate drop requirements.
- **Files Affected**:
  - `lib/data/services/posterior_sleep_detector.dart`
  - `lib/data/services/overnight_sleep_engine.dart`
- **Changes**:
  1. Added circadian day/night gating: Daytime sedentary wakefulness between 09:00 and 21:00 requires stricter criteria than nocturnal sleep.
  2. Daytime sleep (naps) requires:
     - Motion `ENMO <= 0.008g`
     - Heart rate drop to `HR <= profileRhr + 2.0 bpm`
     - Minimum uninterrupted duration `>= 30 minutes`
  3. Sedentary wakefulness with HR 60–75 bpm during daytime is definitively rejected.
- **Test**: `test/forensic_negative_edge_cases_test.dart` (Test 8).
- **Result**: PASSED. 60 minutes on the couch at 16:00 (HR 64, ENMO 0.012) does not trigger sleep state.
- **Remaining Limitations**: Users with exceptionally low daytime resting heart rates must remain stationary for >30 minutes to be identified as a nap.

---

### P0.6: Sleep Staging: Deep Sleep Overestimation & Missing Epochs
- **Problem**: A 7h22m sleep session was classifying almost the entire duration as Slow Wave Sleep (Deep Sleep), and telemetry gaps were coerced into Light Sleep.
- **Root Cause**: In `classifyEpoch`, the rule `enmo < 0.006 && hrRatio <= 0.98` was applied up to 70% of the night. Because sleeping heart rate is naturally below daytime baseline, almost every epoch of normal N2 light sleep satisfied `hrRatio <= 0.98`. Furthermore, gap epochs without packets defaulted to Light Sleep.
- **Files Affected**:
  - `lib/data/services/overnight_sleep_engine.dart`
- **Changes**:
  1. Calibrated `classifyEpoch`: SWS without explicit optical RSA requires true heart-rate nadir: `enmo < 0.005 && hrRatio <= 0.95` and progress `< 45%` of the night.
  2. Gaps in telemetry stream are explicitly assigned `EpochQuality.missing` and `stage: 'MISSING'`.
  3. Temporal smoothing filters skip `MISSING` epochs, preserving genuine data holes without falsifying them as Light sleep.
- **Test**: `test/forensic_negative_edge_cases_test.dart` (Test 9), `test/zero_fake_data_behavioral_test.dart` (Test 2), `test/hmm_sleep_classifier_test.dart`.
- **Result**: PASSED. Deep sleep proportion normalized to realistic physiological levels (15–25%), and missing epochs remain MISSING.
- **Remaining Limitations**: Optical PPG noise during movement epochs can prevent stage differentiation.

---

### P0.7: Timestamps and Timezone Rigor
- **Problem**: Ambiguity between UTC database timestamps and local UI representations, especially for nocturnal sleep spanning across midnight.
- **Root Cause**: Date keys were occasionally formatted from session start timestamp rather than the wake date, causing nocturnal sleep to be attributed to the previous calendar day.
- **Files Affected**:
  - `lib/data/database/database_helper.dart`
  - `lib/data/services/overnight_sleep_engine.dart`
  - `lib/views/home_screen.dart`
- **Changes**:
  1. Database tables store `timestamp` as UTC ISO-8601 strings and `timestamp_utc_ms` epoch integers.
  2. Nocturnal sleep sessions are indexed under the waking date (e.g. sleep starting 23:00 on Oct 6 and ending 07:00 on Oct 7 belongs to physiological cycle of Oct 7).
  3. UI date selectors operate on local midnight representations.
- **Test**: `test/clock_timezone_test.dart`.
- **Result**: PASSED. Seamless handling across midnight boundaries.
- **Remaining Limitations**: Timezone changes during an active sleep session preserve UTC millisecond ordering.

---

### P1.1 - P1.8: Architecture, Models, and UI Hooks

#### P1.1: Data-Driven Baseline Gating
- `RecoveryEngine.calculateBaseline`: Gating distinguishes Cold Start (1–3d), Calibrating (4–13d), and Fully Established (>=14d). Strict gating yields `null` recovery score during cold start.

#### P1.2: WHOOP Historical CSV Import
- `NoopImportExportService`: Implemented complete CSV parsers for `sleeps.csv`, `workouts.csv`, and `physiological_cycles.csv`. Automatically recalculates rolling device baseline without generating fake data.

#### P1.3: Sleep Need Mathematical Model
- `WhoopAnalyticsEngine.calculateAccumulatedSleepDebt`: Models sleep debt accumulation over rolling 14-day history. Sleep surplus (`deficit < 0`) pays down 50% of debt, bounded within `[0..180 minutes]`.

#### P1.4: Streak Calculation (DAY COMPLETED)
- `SqliteWhoopRepository.calculateStreakDays`: Streak increments only for completed days with authentic nocturnal recovery (`recoveryScore != null || (hrv != null && rhr != null)`) or active daytime strain (`strain >= 4.0 || calories > 500`). An incomplete current day does not break an ongoing streak.

#### P1.5: Charts & Trend Visualization
- Real data rendering across Sparkline, Intraday HR, and Hypnogram. Telemetry dropouts render as empty segments rather than artificial horizontal flatlines.

#### P1.6: Habit Journal Persistence
- `JournalScreen`: Wired to load and save answers per `targetDateIso` in SQLite `voci_diario`. In `HomeScreen`, user clicks on past week dates pass the selected date to `JournalScreen`.

#### P1.7: Haptic Alarm & Physical Phone Vibration
- `HapticAlarmService`: Synchronizes BLE alarm packet to strap, evaluates optimal wake window (light sleep / movement), and triggers physical smartphone vibration via `MethodChannel('com.example.whoop_clone/foreground_service', 'triggerVibration')` and Android `Vibrator` / `VibratorManager`.

#### P1.8: Coach AI Fail-Safe
- `CoachContextBuilder`: Explicitly annotates absent metrics as `"Non disponibile"` in LLM context. Handles missing network connectivity gracefully without generating hallucinated metrics.

---

## Forensic Verification Summary Table

| Problem | Root Cause | Fixed | Evidence |
| :--- | :--- | :---: | :--- |
| **P0.1: RR vs RMSSD Conflation** | Synthetic `60000/bpm` mapped to RR, heuristic `<250` mapped to rMSSD | **YES** | `test/forensic_negative_edge_cases_test.dart` (Tests 4, 6) |
| **P0.2: BLE Parser Duplication** | Independent byte slicing in `BackgroundSyncDaemon` | **YES** | Single source of truth via `Whoop96BytePacket`; daemon refactored |
| **P0.3: Physiological Fallbacks** | `?? 55`, `?? 65`, `?? 0.002` masked sensor gaps | **YES** | Stationary motion = `0.0`, missing biometrics return `null`/`--` |
| **P0.4: Respiratory Pipeline** | Lack of spectral DFT gating and risk of rMSSD contamination | **YES** | Clean DFT hierarchy; rejects 0.10 Hz Mayer waves; Test 10 passes |
| **P0.5: Couch Resting vs Sleep** | Pure quiescent ENMO without circadian or autonomic gating | **YES** | Daytime couch rest rejected; Test 8 passes |
| **P0.6: Deep Sleep Overestimation** | `hrRatio <= 0.98` matched normal N2 sleep for 70% of night | **YES** | Nadir tightened to `<= 0.95`, SWS normalized to 15-25%; Test 9 passes |
| **P0.7: Timezone & Wake Date** | Nocturnal sleep attributed to start date rather than wake date | **YES** | UTC in DB, local time in UI, wake date indexing; `clock_timezone_test.dart` passes |
| **P1.1: Baseline Gating** | Uncalibrated users receiving nominal population scores | **YES** | Cold start returns `null`, calibrating requires `>=4d`; Test 4 passes |
| **P1.2: WHOOP Import** | Lack of CSV ingestion for historical sleeps & workouts | **YES** | `NoopImportExportService` imports CSVs and recalculates baseline; Test 11 passes |
| **P1.3: Sleep Need Model** | Unclamped debt and lack of debt repayment on sleep surplus | **YES** | 50% surplus debt repayment implemented and tested |
| **P1.4: Streak Calculation** | Partial days counted as full streak | **YES** | DAY COMPLETED requirement enforced; `sprint6_zero_mock_ble_test.dart` passes |
| **P1.5: Truthful Charts** | Missing buckets interpolated with artificial flatlines | **YES** | Intraday buckets return `null` for gaps; `chart_aggregation_queries_test.dart` passes |
| **P1.6: Habit Journal Persistence** | Journal responses not synced with selected calendar date | **YES** | `JournalScreen` loads/saves for `targetDateIso`; Test 12 passes |
| **P1.7: Haptic Alarm & Vibration** | Strap command only, no physical phone vibration bridge | **YES** | MethodChannel `triggerVibration` added to `MainActivity.kt` and `HapticAlarmService` |
| **P1.8: Coach AI Fail-Safe** | Missing metrics could lead to hallucinated advice | **YES** | `CoachContextBuilder` flags absent metrics as `"Non disponibile"`; Test 13 passes |

---

## Test Suite Execution Evidence
```text
$ flutter analyze
Analyzing whoop_clone...
No issues found! (ran in 6.1s)

$ flutter test
...
00:26 +204: All tests passed!
```
- **Total Test Files**: 49
- **Total Tests Run**: 204
- **Passed**: 204 (100%)
- **Failed**: 0
- **Lints/Warnings**: 0
