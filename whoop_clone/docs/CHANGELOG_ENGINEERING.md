# ENGINEERING CHANGELOG — WHOOP CLONE ARCHITECTURAL OVERHAUL

---

## [Phase 0] — Forensic Audit & Baseline Documentation
- Audited entire Flutter, Dart, SQLite, and Native Android codebases.
- Documented data pipeline, known issues, and test strategy across `docs/AUDIT.md`, `docs/DATA_PIPELINE.md`, `docs/KNOWN_ISSUES.md`, and `docs/TEST_STRATEGY.md`.
- Identified critical data corruption points: CRC-32 residue collision in deduplication, fake physiological default values in overnight sleep staging, unhandled BLE state transition timeouts, and fake haptic success responses.

---

## [Phase 1] — Elimination of Fake Data & Physiological Fallbacks
- **`lib/data/services/overnight_sleep_engine.dart`**:
  - Removed default assignments for RHR (55 bpm), nocturnal HRV (65 ms), and skin temperature (36.5°C).
  - Enforced `null` returns when telemetry records are absent or empty.
  - Eliminated the conversion of unmonitored time into 100% Light Sleep; unmonitored epochs now record strictly as `MISSING`.
- **`lib/data/ble/whoop_96byte_packet.dart`**:
  - Removed fake default `0.002` from `motionVariance`; returns `0.0` if motion variance is absent.
  - Resolved byte offset collisions between accelerometer axes and respiratory power.
- **`lib/data/biometrics/recovery_engine.dart`**:
  - Enforced strictly `null` recovery score when nocturnal HRV is missing.
  - Fixed day count indexing for historical RHR baseline calculation to prevent `RangeError`.
  - Normalized stress penalty calculations within the z-score space.
- **`lib/data/services/noop_system_services.dart`**:
  - Purged fake HRV assignment from raw RR intervals (~900 ms) in nocturnal telemetry collectors.
- **`test/zero_fake_data_behavioral_test.dart`**:
  - Added 5 behavioral verification tests ensuring zero fake data leakage across all layers.

---

## [Phase 2 & 5] — Telemetry Ingestion Layer, Sequence & Deduplication
- **`lib/data/services/telemetry_ingestion_service.dart`**:
  - Created a robust 9-stage telemetry pipeline:
    1. Packet Reception & Ingest Timestamping
    2. Header framing validation (distinguishes framed 0xAA packets from 96-byte flat frames)
    3. Custom WHOOP CRC-8 and CRC-32 validation
    4. Deduplication via FNV-1a 32-bit hash on raw payload bytes (excluding trailing CRC residue to prevent cyclic residue collision)
    5. 16-bit sequence number tracking with circular wraparound ($0 \to 65535$) and gap/packet loss detection
    6. Raw-to-physiological decoding
    7. Physiological sanity filtering (HR $\in [25, 250]$, temp $\in [20, 45]^\circ\text{C}$, SpO2 $\in [50, 100]\%$)
    8. SQLite persistence into `telemetria_grezza`
    9. Real-time broadcast emission to UI Stream
  - Integrated diagnostic telemetry counters (`packetsReceived`, `packetsSaved`, `packetsDuplicate`, `packetsInvalid`, `packetsMissing`).
- **`test/telemetry_ingestion_service_test.dart`**:
  - Implemented 7 unit tests covering valid ingestion, CRC failures, deduplication, packet loss detection, outlier rejection, and store-and-forward batch ingestion.

---

## [Phase 3 & 4] — SQLite Schema v15 & Raw Telemetry Persistence
- **`lib/data/database/database_helper.dart`**:
  - Upgraded schema to **Version 15**.
  - Added columns to `telemetria_grezza`:
    - `device_id` (TEXT)
    - `session_id` (TEXT)
    - `sequence_number` (INTEGER)
    - `packet_type` (INTEGER)
    - `raw_payload` (BLOB)
    - `decoder_version` (INTEGER)
    - `crc_valid` (INTEGER)
    - `is_valid` (INTEGER)
    - `received_at` (TEXT)
    - `device_timestamp` (TEXT)
    - `ingest_latency_ms` (INTEGER)
    - `duplicate` (INTEGER)
    - `source` (TEXT, e.g. `'REAL_STREAM'`, `'STORE_FORWARD'`)
    - `quality` (TEXT)
    - `rmssd_ms` (REAL)
  - Created optimized composite indices on `(timestamp_utc_ms ASC)` and `(sequence_number ASC)`.
  - Added thread-safe database initialization lock via `Completer<Database>`.
  - Wrapped multi-row insert/update operations in atomic transactions (`db.transaction`).

---

## [Phase 6 & 7] — BLE Connection State Machine & Store-and-Forward Protocol
- **`lib/data/ble/ble_connection_manager.dart`**:
  - Refactored `BleState` into **10 explicit states**:
    - `disconnected`, `scanning`, `connecting`, `discovering`, `subscribing`, `initializing`, `syncingHistory`, `streaming`, `reconnecting`, `failed`.
  - Added `_stateTransitionTimer` (15s timeout) to prevent hanging during GATT discovery or characteristic subscription.
  - Implemented exponential backoff for auto-reconnection without killing active reconnection timers.
  - Protected all async stream controllers from post-dispose event emissions.
- **`lib/data/services/overnight_sleep_engine.dart`**:
  - Implemented `StoreAndForwardHandler` with WHOOP framing:
    - Opcode `0x16` (`SEND_HISTORICAL_DATA`)
    - Opcode `0x17` (`HISTORICAL_DATA_RESULT` ACK)
  - Integrated historical data packet reconstruction with CRC-32 integrity validation.

---

## [Phase 8] — Golden Packet Suite
- **`test/fixtures/ble/`**:
  - Created golden packet fixtures:
    - `framed_0xaa_command.json`: Framed command with CRC-8 and CRC-32.
    - `whoop_96byte_sensor_packet.json`: 96-byte raw sensor telemetry frame with 10-millisecond optical channels, accelerometer axes, and temperatures.
    - `store_and_forward_batch.json`: Batched historical frames with sequence indicators.
    - `corrupt_crc_packet.json`: Corrupted frame verifying bit-error rejection.
- **`test/golden_packet_suite_test.dart`**:
  - Built bit-level golden verification suite testing parsing accuracy, endianness, and CRC integrity.

---

## [Phase 9, 10, 11, 12] — Biometrics, Staging & Recovery Engines
- **`lib/data/services/overnight_sleep_engine.dart`**:
  - Structured overnight sleep staging around 30-second epochs (`Epoch30s`).
  - Added `_classifyHypnogram` using multi-feature decision boundaries (ENMO, HR ratio, HRV norm, RSA respiratory spectral power).
  - Implemented US Patent US9750415B2 algorithm: extracts nocturnal HRV (rMSSD) strictly from the final Slow-Wave Sleep (SWS) cycle prior to waking.
  - Automated sleep boundary detection with sustained quiescence window filters.
- **`lib/domain/analytics/whoop_analytics_engine.dart`**:
  - Replaced piecewise non-continuous strain conversion with a continuous, strictly monotonic, concave formula.
- **`lib/data/biometrics/strain_engine.dart`**:
  - Corrected Banister gender exponent for females to 1.67 (was 1.92).

---

## [Phase 13, 14, 15] — Profile Persistence, Streak & Truthful Haptics
- **`lib/data/ble/ble_connection_manager.dart`**:
  - Introduced `HapticResultStatus` enum: `phoneHapticOnly`, `strapCommandSent`, `strapAcknowledged`, `strapFailed`, `notConnected`.
  - Refactored `sendHapticVibrationCommand` to return truthful status; never returns success when BLE is disconnected.
- **`lib/views/screens/device_screen.dart` & `lib/data/services/haptic_alarm_service.dart`**:
  - Updated UI feedback to accurately present strap vs phone vibration states.
- **`lib/viewmodels/whoop_viewmodel.dart`**:
  - Secured biometrics profile persistence in SQLite and SharedPreferences.
  - Refined streak calculation to require genuine logged sleep or recovery cycles.

---

## [Phase 16 & 17] — Background Operation, Native Android & Truthful UI
- **`android/app/src/main/kotlin/com/example/whoop_clone/BleForegroundService.kt`**:
  - Guarded `startForeground` against `SecurityException` on Android 14 when Bluetooth connect permissions are revoked.
  - Added `FLAG_IMMUTABLE` PendingIntent to notification to safely resume app on tap.
- **`android/app/src/main/kotlin/com/example/whoop_clone/MainActivity.kt`**:
  - Wrapped foreground service launch in `try-catch` handling `ForegroundServiceStartNotAllowedException` on Android 12+.
- **`lib/viewmodels/whoop_viewmodel.dart`**:
  - Implemented debouncing and dirty-checking on `notifyListeners()` to prevent redundant 4Hz UI rebuild cascades.
  - Preserved null values for unmonitored vitals across all dashboard tiles.

---

## [Phase 18] — End-to-End Integration Verification
- **`test/e2e/e2e_pipeline_verification_test.dart`**:
  - Built comprehensive 5-stage E2E test:
    1. Ingestion of 120 packets (100 valid, 15 duplicates, 5 corrupted).
    2. SQLite Schema v15 forensic verification.
    3. OvernightSleepEngine processing of genuine telemetry (50.0 min recorded, unobserved gaps marked missing).
    4. Manual sleep entry without BLE (zero fake vitals, provenance `'USER_ENTERED'`).
    5. ViewModel and truthful haptics status validation.

---

## [Phase 19 & 20] — Portability, Cleanliness & Certification
- Cleaned hardcoded Windows paths (`C:\Users\...`) in `BUILD_APK.bat` and `build_apk_quick.ps1` using relative `%~dp0` and `$PSScriptRoot`.
- Created comprehensive engineering dossier, final audit report, and hardware validation protocols.
- Verified 122/122 tests passing with zero failures.
