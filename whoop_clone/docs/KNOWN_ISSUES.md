# WHOOP CLONE — KNOWN ISSUES & VULNERABILITY CATALOG (PHASE 0)

> **Document Version:** 1.1.0  
> **Date:** October 2026  
> **Classification:** FORENSIC DEFECT & REMEDIATION REGISTRY  
> **Coverage:** Full Subsystem Issue Catalog (BLE-01..08, PRO-01..04, DAT-01..08, SLP-01..08, STG-01..07, MCK-01..03, TIM-01, BGD-01..04, CHT-01..04, QA-01..05, REP-01..02)

---

## 1. Catalogo Generale Problematiche per Sottosistema

### Connessione BLE — `lib/data/ble/ble_connection_manager.dart`

| ID | Sev | Problema | Fase |

|---|---|---|---|

| BLE-01 | P0 | Il retry ogni 5 s (L~704) chiama `connectSavedDevice()` che, se lo stato è `connecting`, esegue `disconnect()` (L~292). Il connect dura 6–8 s: il tentativo viene interrotto a ogni giro e non converge mai. | 2 |

| BLE-02 | P0 | `_bindToDevice` è richiamata da più percorsi (L~320, 332, 341, 387): discovery, sottoscrizioni e handshake (`GET_HELLO`, `SET_CLOCK`, toggle HR) partono due volte in parallelo → GATT busy/disconnessioni. | 2 |

| BLE-03 | P1 | Scansione ogni 3 tentativi (L~722) mentre si sta connettendo; `scanResults.listen` (L~185) può innescare più `connect` prima di `stopScan`; `createBond()` (L~383) dopo ogni connect. | 2 |

| BLE-04 | P1 | ACK opcode 23 inviato per **ogni** pacchetto ≥96 byte (≈1 Hz, L~530–542) con `await` dentro il listener; pacchetti <96 byte scartati senza log. | 2/3 |

| BLE-05 | P1 | `autoConnect: true` (L~336) in un ramo e `false` (L~374) nell'altro: politica incoerente. | 2 |

| BLE-06 | P1 | Nessun log dello status di disconnessione (8 = timeout, 19 = chiusura dal peer, 133 = errore stack): impossibile diagnosticare. | 1 |

| BLE-07 | P0 | Nessuna verifica CRC in ingresso (nessuna chiamata a `.verify`), nessun framer/riassemblaggio di notifiche frammentate. `validateAndParseBleFrame` (`overnight_sleep_engine.dart` L~33) e `reassembleFragments` esistono ma non sono mai usati. | 3 |

| BLE-08 | P1 | `sendHapticVibrationCommand` (L~865–905) invia in sequenza alla cieca 4 comandi diversi (RUN_ALARM, RUN_HAPTICS_PATTERN, MAVERICK, motor-direct con CRC16 non incorniciato). | 3 |



### Protocollo e parser — `lib/data/ble/*`, `lib/data/services/noop_ble_decoder.dart`

| ID | Sev | Problema | Fase |

|---|---|---|---|

| PRO-01 | P0 | Esistono **almeno quattro layout incompatibili** per il pacchetto dati: `Whoop96BytePacket` (seq byte 2–3, timestamp 4–7, HR byte 8), `NoopProtocolDecoder.parseRawFrame`, `NoopBleDecoder.decodeFrame` (HR byte 4, accel float32 12–23, rMSSD float32 al 40), `validateAndParseBleFrame` (prefisso `0xAA 0x01`, CRC16). In più, i **comandi** usano `AA, len_lo, len_hi, crc8, type, seq, cmd…` che contraddice il layout usato per leggere i dati. Non possono essere tutti veri. | 1→3 |

| PRO-02 | P1 | Codice morto: `NoopBleDecoder`, `NoopProtocolDecoder.parseRawFrame` (usa `ByteData.view(bytes.buffer)` ignorando l'offset), `WhoopBleService`, `validateAndParseBleFrame`, `reassembleFragments`, `mock_whoop_repository.dart`. | 3/7 |

| PRO-03 | P1 | CRC-32 del comando allarme calcolato su header+corpo (`buildAlarmCommandPayload`), mentre `buildFramedCommand` lo calcola sui soli byte interni. Il CRC-8 fisso `0x57` è corretto (verificato). Uno dei due CRC-32 è probabilmente sbagliato → l'allarme sul cinturino potrebbe essere ignorato in silenzio. | 3 |

| PRO-04 | P1 | `Whoop96BytePacket`: ENMO = `|mag−1|` con floor fittizio `0.002` (L~48–49) invece di `max(0, mag−1)`; unità dell'accelerometro non verificate; HRV `uint16/10` ipotetico. | 3 |



### Ingestione e DB — `lib/data/services/noop_system_services.dart`, `database_helper.dart`

| ID | Sev | Problema | Fase |

|---|---|---|---|

| DAT-01 | P0 | Il daemon (`BackgroundSyncDaemon`) rilegge il pacchetto con offset "flat" via `_extractFloat32LE(rawBytes, 8)` (L~112) senza validare NaN/Inf, anche per i frame con header `0xAA`: `motion_var`, `accel_enmo`, `resp_power` nel DB sono spesso privi di senso. | 3 |

| DAT-02 | P0 | `rr_ms` contiene un **rMSSD** (L~138, 206), non gli intervalli RR; gli RR grezzi non vengono mai salvati (`rr_intervals_json` è scritto solo dal codice morto). Il motore del sonno tratta `rr_ms < 250` come rMSSD e altrimenti come RR (`overnight_sleep_engine.dart` L~1034, 1047): semantica mista. | 3 |

| DAT-03 | P1 | Lo stream HR usa `DateTime.now()`, il pacchetto 96 byte usa il clock del cinturino; la deduplica confronta basi temporali diverse. | 3 |

| DAT-04 | P1 | Flush ogni 5 minuti da buffer in RAM (L~221): se il processo muore si perdono fino a 5 minuti. | 4 |

| DAT-05 | P1 | `telemetria_grezza`: nessun vincolo UNIQUE su `timestamp_utc_ms` (duplicati), `pruneOldTelemetry()` non è mai chiamata (crescita illimitata, ~86.400 righe/giorno), nessuna aggregazione prima di un eventuale prune. | 3 |

| DAT-06 | P1 | Schema e API mettono `DEFAULT 0.002` a `accel_enmo`/`motion_var` (e `insertTelemetriaPoint(motionVar = 0.002)`): un dato mancante diventa "immobile". | 3/7 |

| DAT-07 | P2 | ~65 `catch (_) {}` nel progetto; inserimenti e persistenza falliscono in silenzio (`_persistOvernightResults` L~1679 logga solo con `debugPrint`). | 7 |

| DAT-08 | P2 | Migrazioni con `catch (_) {}`; `oldVersion < 4` fa `DROP` delle tabelle utente. | 3 |



### Rilevamento sonno — `overnight_sleep_engine.dart`, `whoop_viewmodel.dart`

| ID | Sev | Problema | Fase |

|---|---|---|---|

| SLP-01 | P0 | L'analisi notturna parte solo da `loadData()` (UI) tramite `triggerOvernightSyncIfNeeded` (L~655–672), con finestra "ultime 14 h da adesso" e guard `hasRecovery` solo per oggi. Aprendo l'app alle 15:00 la notte è fuori finestra → "nessun dato al risveglio". Non parte mai su riconnessione o in background. | 5 |

| SLP-02 | P0 | **Data del sonno incoerente**: `AutoSleepDetector` salva con `targetDateIso = data di inizio` (L~507, cioè la sera prima), mentre il sync dal ViewModel salva con la data di fine. La UI filtra per `dataIso` del giorno selezionato → il sonno compare sotto il giorno sbagliato o non compare. Convenzione corretta: **data locale del risveglio**. | 5 |

| SLP-03 | P1 | `AutoSleepDetector` (L~351) conta *campioni* come se fossero secondi: con due stream (HR standard + pacchetto 96 byte) arrivano ≈2 campioni/s, quindi "30 minuti" diventano ≈15. Buffer solo in RAM; stato perso al riavvio. | 5 |

| SLP-04 | P1 | `ingestSample` (L~313) **inventa** ENMO dall'HR (`hr < rest+10 ? 0.003 : 0.060`) e default per rMSSD, RSA, `hrFluc`, `rmssdVar`. | 5/7 |

| SLP-05 | P1 | Fine sonno quasi irraggiungibile (L~380–400: serve ENMO ≥ 0.08 g su ~70 % dei campioni per 15 min **e** HR ≥ riposo+22), nessun timeout né fallback. | 5 |

| SLP-06 | P1 | `detectSleepBoundaries` (L~547): `startSustainSamples = 10` (≈10 secondi, non minuti), soglie hardcoded, `daytimeMeanHr = rhr·1.35`, fallback all'intero array se non trova nulla, solo con ≥60 record, un solo periodo (niente nap). | 5 |

| SLP-07 | P1 | Finestra >14 h → `start = end − 8 h` (arbitrario). | 5 |

| SLP-08 | P2 | `_calculateDeltaSkinTemp` e `_calculateSpo2` ricevono `rawTelemetryRecords` invece di `processedRecords`: quando i dati arrivano dal DB risultano `null`. | 5 |



### Staging delle fasi — `overnight_sleep_engine.dart`

| ID | Sev | Problema | Fase |

|---|---|---|---|

| STG-01 | P0 | **Causa probabile di "non separa le fasi"**: i default sintetici pilotano la classificazione. `resp_power ?? 0.7` → `respVar = (1−0.7)·0.5 = 0.150`, appena sotto la soglia `≤ 0.151` → la condizione respiratoria del sonno profondo risulta sempre vera. `rmssd_var ?? 0.1` e `hr_fluc ?? 2` non attivano mai la regola REM aggiuntiva; `rmssd` che ricade sulla baseline dà `hrvNorm ≈ 1.0 < 1.20` → REM quasi mai. Risultato: quasi tutto LIGHT/SWS, REM ≈ 0. | 6 |

| STG-02 | P1 | `hrRatio = hr / rhrBaseline` con baseline di default 55 finché non c'è bootstrap: con RHR reale 48 il rapporto sta sempre ≈0.87 ("profondo"), con RHR 65 supera 1.05 ("mai profondo"). Soglie assolute di accelerazione (0.040/0.008/0.010 g) con unità non verificata (g vs milli-g). | 6 |

| STG-03 | P1 | `_chunkInto30sEpochs`: le epoche senza campioni sono riempite con valori finti (motion 0.015, respPower 0.40, HR/rMSSD precedenti) invece di essere marcate `no_data`; `numEpochs` limitato a 1920 (16 h); `rmssd` forzato in 20–120. | 6 |

| STG-04 | P1 | Smoothing solo anti-flicker a 1 epoca; nessuna durata minima dei bout, nessun prior sulla struttura a cicli, nessuna normalizzazione per notte. | 6 |

| STG-05 | P1 | `_extractLastSwsCycleMetrics`: se non c'è SWS usa tutte le epoche "quiete"; rMSSD per epoca da "pp" derivati da `rr_ms` (che contiene rMSSD, vedi DAT-02) → privo di senso; clamp 20–120 distorce i valori. | 3/6 |

| STG-06 | P1 | Recovery senza gating: `sleepPerf ?? 80`, `skinTempDelta ?? 0`, baseline di default, `rmssd_std` 15.0 hardcoded, nessun minimo di dati né di giorni di baseline → numeri che sembrano reali ma sono default. | 6 |

| STG-07 | P2 | L'ipnogramma calcolato non viene persistito (la tabella `sonno` ha solo totali). | 8 |



### Dati finti, tempo e provenienza

| ID | Sev | Problema | Fase |

|---|---|---|---|

| MCK-01 | P1 | `lib/data/repositories/mock_whoop_repository.dart` è in `lib/` (nessun riferimento, ma è codice di produzione). | 7 |

| MCK-02 | P1 | Default che sembrano misure: seed profilo (età 30, hr_max 190, HRV 65/15, RHR 55/3.5), fallback `72.0` in `home_screen.dart` (L~184), ~15 occorrenze di `?? 65.0/55.0`, baseline temperatura 36.5 hardcoded nel ViewModel, `baselineHrvStd: 15.0`. | 7 |

| MCK-03 | P2 | La colonna `provenance` esiste (REAL/BOOTSTRAP/DERIVED/MANUAL) ma la UI non la mostra. | 7 |

| TIM-01 | P1 | `fusoOrario => '+02:00'` hardcoded in `ciclo_fisiologico.dart`, `sonno.dart`, `allenamento.dart` (**sbagliato dal 25/10/2026, ora solare**); 93 usi di `DateTime.now()`; timestamp stringa misti (stress inserito in locale, telemetria in UTC) con confronti di stringhe in `_persistOvernightResults`; `data_iso` ricavato con `toIso8601String().substring(0,10)` (data UTC se il `DateTime` è UTC). | 7 |



### Servizio in background e Android/iOS

| ID | Sev | Problema | Fase |

|---|---|---|---|

| BGD-01 | P0 | `BleForegroundService.kt` mostra solo la notifica "Connessione Strap Attiva": **non possiede il GATT**, nessun wake lock; `START_STICKY` può riavviare un processo senza Flutter engine con la notifica che dichiara una connessione inesistente. BLE, daemon e detector vivono nell'isolate della UI (ViewModel creato in `main.dart`): se Android distrugge l'Activity, la registrazione notturna si ferma. *(Ipotesi molto probabile, da confermare con i log.)* | 4 |

| BGD-02 | P1 | Nessun flusso `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`; build release firmata con la chiave debug, `minifyEnabled false`; `targetSdk 34` vs `compileSdk 36`; `applicationId com.example.whoop_clone`. | 4/9 |

| BGD-03 | P1 | `haptic_alarm_service.dart`: monitoraggio con `Timer.periodic(15 s)` solo nel processo UI → la sveglia intelligente non è affidabile in background; vedi anche PRO-03. | 4 |

| BGD-04 | P2 | iOS: `UIBackgroundModes: bluetooth-central` presente, ma nessuna state restoration (da verificare). | 4 |



### Grafici

| ID | Sev | Problema | Fase |

|---|---|---|---|

| CHT-01 | P0 | `HypnogramChart`, `IntradayHrChart`, `HeartRateZonesChart`, `Sparkline14d` sono definiti ma **mai usati** fuori dal proprio file (0 usi esterni). | 8 |

| CHT-02 | P1 | Nessuna query di aggregazione: `getTelemetriaInTimeRange` restituisce tutte le righe (~86k/giorno). | 8 |

| CHT-03 | P1 | Nessuno stato esplicito "vuoto / parziale / in caricamento"; i buchi di dati non spezzano le linee. | 8 |

| CHT-04 | P2 | `StressWaveChart`, `WeeklyDualAxisChart`, `StressTimelineView`: provenienza dei dati da verificare (non letti a fondo). | 8 |



### Qualità, test, repo

| ID | Sev | Problema | Fase |

|---|---|---|---|

| QA-01 | P1 | `WhoopViewModel` (850 righe) possiede BLE + daemon + detector + DB (god object). File molto lunghi: `overnight_sleep_engine.dart` 1689, `home_screen.dart` 1431, `sleep_detail_modal.dart` 978, `ble_connection_manager.dart` 967, `database_helper.dart` 866, `recovery_detail_modal.dart` 852. | 9 |

| QA-02 | P1 | `DatabaseHelper.isTestMode` usato nel codice di produzione (ViewModel L~636/652, `haptic_alarm_service.dart` L~260). | 9 |

| QA-03 | P1 | 29 file di test (24 con `isTestMode`): verificano la coerenza interna, non il comportamento con dati reali; nessuna fixture da cinturino reale. | 3/9 |

| QA-04 | P2 | `strain_engine.dart` (L~66) usa `21·(1−e^(−kL))`, il dossier descrive `21·ln(1+λL)/ln(1+λ·L_max)`; l'esempio del dossier (12.8 + 9.6 → 14.6) è incoerente con la sua stessa formula (≈16.1). Non cambiare la formula: scegliere quella canonica e allineare documento e codice. | 9 |

| QA-05 | P2 | Script Python di test e prototipi HTML alla radice della repo. | 0 |

| REP-01 | P1 | Committati: `android/local.properties` (percorsi personali), `.gradle`, `__pycache__`, video e zip pesanti, PDF. | 0 |

| REP-02 | P1 | Loghi ufficiali WHOOP in `assets/logos/` e alla radice; nome app "Whoop 5.0 Clone" (rischio marchio se la repo resta pubblica). | 0/9 |



---

---

## 2. Analisi Forense Approfondita per Priorità Architetturale

## Priority 0: Critical Data Integrity & Architectural Blockers

### ISSUE P0-1: Synthetic Physiological Data Fallbacks in `OvernightSleepEngine`
* **File:** `lib/data/services/overnight_sleep_engine.dart` (Lines 948–952, 1005–1006, 1029–1031)
* **Root Cause:** When raw telemetry records are queried from SQLite, null or missing fields are replaced with arbitrary hardcoded constants:
  ```dart
  final motion = (r['motion_var'] ?? r['motion'] ?? r['enmo'] ?? 0.002).toDouble();
  final hr = (r['hr'] ?? r['bpm'] ?? 55.0).toDouble();
  final rmssd = (r['rmssd'] as num?)?.toDouble() ?? 68.0;
  final respPower = (r['resp_power'] ?? 0.7).toDouble();
  ```
  And in lines 1005–1006:
  ```dart
  double lastHr = 55.0;
  double lastRmssd = 65.0;
  ```
* **Impact:** If the strap disconnected or dropped packets during the night, the engine fabricates normal physiological values ($\text{HR}=55$, $\text{HRV}=68$, $\text{RespPower}=0.7$), presenting fake vitals as real measurements.
* **Remediation Plan (Phase 1):** Remove all fallback constants. Store `null` when telemetry is absent. Propagate nullability to vitals extraction.
* **Verification:** Test asserting that missing records in range yield `null` vitals and zero fabricated numbers.

---

### ISSUE P0-2: Missing Epochs Automatically Classified as `SleepStage.light`
* **File:** `lib/data/services/overnight_sleep_engine.dart` (Lines 1070–1080)
* **Root Cause:** In `_buildEpochs30s`, if a 30-second window contains zero samples, the engine constructs a synthetic epoch:
  ```dart
  list.add(Epoch30s(
    timestamp: epochTime,
    motionVar: 0.015,
    hr: lastHr,
    rmssd: lastRmssd,
    respPower: 0.40,
    respRate: 0.0,
    stage: SleepStage.light, // <-- FABRICATED LIGHT SLEEP
  ));
  ```
* **Impact:** 4 hours of strap disconnection during sleep are transformed into 4 hours of "Light Sleep", inflating total sleep time and distorting sleep efficiency.
* **Remediation Plan (Phase 1):** Add `SleepStage.missing` and `SleepStage.unknown`. Missing epochs must be classified as `SleepStage.missing` with `sampleCount = 0` and `quality = EpochQuality.missing`. Total sleep time must strictly sum valid sleep stages (`sws + rem + light`), excluding `missing`.
* **Verification:** Unit test with a 60-minute gap verifying that all 120 epochs are marked `SleepStage.missing` and sleep duration does not increase.

---

### ISSUE P0-3: `allowFallback: true` and Fake Sleep Stages in Manual Sleep
* **Files:** `lib/viewmodels/whoop_viewmodel.dart` (Line 715), `lib/data/services/overnight_sleep_engine.dart` (Lines 698–708)
* **Root Cause:** In `whoop_viewmodel.dart`, `processAndAddManualSleep({bool allowFallback = true})` allows fallback. When no BLE telemetry exists, line 700 of `overnight_sleep_engine.dart` returns:
  ```dart
  'total_sleep_min': totalManualSleepMin,
  'sws_min': 0.0,
  'rem_min': 0.0,
  'light_min': totalManualSleepMin, // <-- FAKE STAGE ALLOCATION!
  ```
* **Impact:** User-entered sleep is masqueraded as measured sleep with fabricated stages (100% Light Sleep).
* **Remediation Plan (Phase 1):** Eliminate `allowFallback` parameter. Manual sleep without telemetry must record duration only with `provenance: USER_ENTERED`, `sws_min: null`, `rem_min: null`, `light_min: null`, `recovery_score: null`, `vitals: null`.
* **Verification:** Test verifying manual sleep entry of 7h45m produces exactly 465 min total duration with null stages and zero invented vitals.

---

### ISSUE P0-4: Absence of Dedicated `TelemetryIngestionService` & Sequence Tracking
* **Files:** `lib/data/services/noop_system_services.dart`, `lib/viewmodels/whoop_viewmodel.dart`
* **Root Cause:** Raw BLE packet streams are listened to independently and simultaneously by `BackgroundSyncDaemon` and `WhoopViewModel`. There is no single gateway responsible for sequence validation, packet loss tracking, deduplication, and atomic persistence.
* **Impact:** If packets arrive out of order, are duplicated, or are dropped by the Bluetooth radio, the application cannot detect the loss, risking silent telemetry gaps and duplicate database rows.
* **Remediation Plan (Phase 2 & 5):** Create `TelemetryIngestionService` acting as the sole consumer of raw BLE packets. Implement sequence counter checking (with 16-bit wraparound), duplicate hash window, gap logging, and diagnostics.
* **Verification:** GIVEN 100 packets with 2 duplicates and 1 missing sequence $\to$ THEN service records 97 saved, 2 duplicates, 1 missing.

---

### ISSUE P0-5: `telemetria_grezza` Schema Lacks Source-of-Truth Metadata & Defaults ENMO
* **File:** `lib/data/database/database_helper.dart` (Lines 281–299)
* **Root Cause:** The table definition specifies `accel_enmo REAL DEFAULT 0.002` and `motion_var REAL DEFAULT 0.002`, injecting fake acceleration on null columns. Furthermore, the table lacks audit columns: `device_id`, `session_id`, `sequence_number`, `packet_type`, `raw_payload`, `decoder_version`, `crc_valid`, `is_valid`, `received_at`, `duplicate`, `source`, `quality`.
* **Impact:** Impossible to forensically audit whether a row originated from real BLE hardware, historical sync, or manual insertion.
* **Remediation Plan (Phase 3 & 4):** Upgrade SQLite database schema to version 15. Remove default `0.002` values. Add all audit columns and index on `sequence_number` and `timestamp_utc_ms`.
* **Verification:** Automated SQLite migration test asserting column presence and null defaults.

---

### ISSUE P0-6: Hardcoded Baseline & Vitals Fallbacks in ViewModel and Recovery Engine
* **Files:** `lib/viewmodels/whoop_viewmodel.dart` (Lines 431, 446), `lib/data/biometrics/recovery_engine.dart` (Lines 110–116)
* **Root Cause:** In `whoop_viewmodel.dart`, if live HRV is zero, it falls back to `_userProfile.hrvBaselineMean` (65.0 ms) and saves it to stress measurements. In `recovery_engine.dart`, default parameter values assume `currentRespRateRpm = 14.5`, `nightlyStress = 0.5`.
* **Impact:** Live stress and recovery scores are calculated using synthetic numbers when real sensor readings are missing.
* **Remediation Plan (Phase 1 & 12):** Require explicit parameters with no defaults. If vitals are missing, abort calculation and return `null`.
* **Verification:** Test verifying recovery score returns `null` when `currentRmssdMs` or `currentFcrBpm` is missing.

---

## Priority 1: Major Architectural & Algorithmic Flaws

### ISSUE P1-1: Incomplete BLE Connection State Machine
* **File:** `lib/data/ble/ble_connection_manager.dart` (Lines 13–22)
* **Root Cause:** Current `BleState` enum only has 8 states: `disconnected`, `requestingPermissions`, `scanning`, `connecting`, `bonding`, `connected`, `reconnecting`, `error`.
* **Impact:** Missing explicit states: `DISCOVERING`, `SUBSCRIBING`, `INITIALIZING`, `SYNCING_HISTORY`, `STREAMING`, `FAILED`. The UI cannot distinguish between a device that is connected but still discovering services vs actively streaming telemetry.
* **Remediation Plan (Phase 7):** Refactor state machine to include all 10 explicit states. Ensure idempotent, logged transitions.
* **Verification:** State machine transition test verifying progression from `DISCONNECTED` $\to$ `CONNECTING` $\to$ `DISCOVERING` $\to$ `SUBSCRIBING` $\to$ `INITIALIZING` $\to$ `STREAMING`.

---

### ISSUE P1-2: Haptic Vibration Command Inaccurately Returns `true` When Strap Is Disconnected
* **File:** `lib/data/ble/ble_connection_manager.dart` (Lines 865–912)
* **Root Cause:** `sendHapticVibrationCommand` executes phone haptics first and then returns `true` even if the strap is not connected or BLE write fails.
* **Impact:** False positive: user believes the wrist strap vibrated when only the smartphone vibrated.
* **Remediation Plan (Phase 15):** Return `HapticResultStatus` enum (`PHONE_HAPTIC_ONLY`, `STRAP_COMMAND_SENT`, `STRAP_ACKNOWLEDGED`, `STRAP_FAILED`, `NOT_CONNECTED`).
* **Verification:** Test verifying that calling haptic command with disconnected strap returns `HapticResultStatus.notConnected` (or `phoneOnly`), never `strapAcknowledged`.

---

### ISSUE P1-3: Baseline Engine Lacks Distinction Between Cold Start, Bootstrap, and Normal Operation
* **File:** `lib/data/biometrics/recovery_engine.dart` (Lines 47–99)
* **Root Cause:** The baseline calculation has only a hard cutoff at `< 4` days, without persisting baseline metadata (`baseline_source`, `sample_count`, `window`, `confidence`) into the database.
* **Impact:** Baseline cannot be traced back to its underlying historical samples or audited across app restarts.
* **Remediation Plan (Phase 11):** Implement `BaselineEngine` managing cold start ($0-3$ days), bootstrap ($4-29$ days), and normal operation ($30+$ days) with persistent audit logging.
* **Verification:** Test tracking baseline calibration progression across 1, 4, 15, and 30 days of data.

---

### ISSUE P1-4: Streak Calculation Falsely Counts Partial or Unverified Days
* **File:** `lib/data/repositories/sqlite_whoop_repository.dart` (Lines 135–142)
* **Root Cause:** A day is considered active for streak if `(strainGiornaliero != null && strainGiornaliero > 0) || recoveryScore != null`. A cycle with 0.1 strain or unverified data counts as a completed day.
* **Impact:** Streak is artificially maintained even without meaningful data.
* **Remediation Plan (Phase 14):** Enforce strict validation: A valid streak day requires either a completed sleep session with valid recovery OR at least 30 minutes of continuous telemetry / completed workout.
* **Verification:** Test verifying that a cycle with 0.05 strain and no sleep does NOT increment the active streak.

---

### ISSUE P1-5: Conflation of Raw Motion with ENMO Without Mathematical Rigor
* **File:** `lib/data/ble/whoop_96byte_packet.dart` (Lines 47–50)
* **Root Cause:** Motion variance is approximated as `(sqrt(ax^2 + ay^2 + az^2) - 1.0).abs()`, which is neither pure ENMO ($\max(0, \|\mathbf{a}\| - 1)$) nor statistical variance ($\sigma^2$), and defaults to `0.002` if $\le 0$.
* **Impact:** Confuses dynamic body acceleration with noise floor variance, impairing sleep stage classification.
* **Remediation Plan (Phase 10):** Implement calibrated Euclidean Norm Minus One ($\text{ENMO} = \max(0.0, \|\mathbf{a}\| - 1.0\text{ g})$) with documented units ($g$) and sensor frequency ($25-50\text{ Hz}$).
* **Verification:** Golden packet unit tests verifying ENMO calculation against known accelerometer vectors.

---

### ISSUE P1-6: Orphaned / Out-of-Sync `NoopBleDecoder`
* **File:** `lib/data/services/noop_ble_decoder.dart` (Lines 116–125)
* **Root Cause:** Contains legacy parsing code with wrong sequence offset (`byteData.getUint16(0)` on 0xAA frames) that is not connected to production telemetry streams.
* **Impact:** Dead code causing confusion during audits and testing.
* **Remediation Plan (Phase 1 & 2):** Harmonize decoding in `noop_protocol_decoder.dart` and `whoop_96byte_packet.dart`; deprecate or align `noop_ble_decoder.dart`.
* **Verification:** Build and test verification confirming single unified decoder pipeline.

---

## Priority 2: Secondary & Resilience Defects

### ISSUE P2-1: Unchecked Silent Catch Blocks
* **Files:** `lib/data/services/noop_system_services.dart` (Lines 151, 219), `lib/data/ble/ble_connection_manager.dart`
* **Root Cause:** `try { ... } catch (_) {}` silently swallows database insertion failures and parsing errors.
* **Impact:** Database corruption or format errors fail silently with zero diagnostic footprint.
* **Remediation Plan (Phase 2):** Replace bare catch blocks with structured logging and increment diagnostic error counters.
* **Verification:** Test asserting errors trigger logging and are reflected in `IngestionDiagnostics`.

---

### ISSUE P2-2: Missing Golden Packet Regression Fixture Suite
* **Directory:** `test/fixtures/ble/` (Currently Non-Existent)
* **Root Cause:** No frozen binary/hex fixtures from actual hardware exist in the repository to guarantee parser backwards-compatibility.
* **Impact:** Any modification to byte offsets in `whoop_96byte_packet.dart` risks breaking telemetry extraction without failing tests.
* **Remediation Plan (Phase 8):** Create `test/fixtures/ble/` containing raw hex dumps for Whoop 4.0/5.0 frames and corresponding JSON expectations.
* **Verification:** Fixture-driven test suite verifying byte-for-byte exact decoding.

---

### ISSUE P2-3: 7-Day Automatic Pruning of `telemetria_grezza`
* **File:** `lib/data/database/database_helper.dart` (Line 840)
* **Root Cause:** `pruneOldTelemetry({int daysToKeep = 7})` deletes raw rows older than 7 days.
* **Impact:** If a user goes on a 10-day trip offline, historical telemetry synced after 7 days risks being purged before audit verification.
* **Remediation Plan (Phase 4):** Increase default retention to 30 days and protect un-synced / un-processed rows from pruning.
* **Verification:** Test verifying un-processed telemetry rows are never deleted by pruning routine.

---

### ISSUE P2-4: UI Widgets Rendering Unverified Defaults on Disconnection
* **Files:** `lib/views/widgets/live_heart_rate_card.dart`, `lib/views/home_screen.dart`
* **Root Cause:** UI widgets display `--` or stale cache without explicit disconnected status indicator or provenance chips.
* **Impact:** User cannot tell if a displayed heart rate is live, 10 minutes old, or from yesterday.
* **Remediation Plan (Phase 17):** Add provenance chips (`LIVE`, `SYNCED`, `DISCONNECTED`) and clear timestamps on all primary vital cards.
* **Verification:** Widget test verifying that when BLE disconnects, UI immediately switches to `DISCONNECTED` state.

---

## Priority 3: Improvements & Code Cleanliness

### ISSUE P3-1: Deprecated Flutter Theme Properties & Syntax
* **Files:** `lib/core/constants/whoop_theme.dart`, `lib/core/constants/app_theme.dart`
* **Root Cause:** Usage of deprecated `ColorScheme.background` and `.withOpacity()`.
* **Impact:** Build linter warnings and future SDK deprecation breakage.
* **Remediation Plan (Phase 20):** Migrate to `ColorScheme.surface` and `.withValues(alpha: ...)`.

### ISSUE P3-2: Android 14 Foreground Service Crash Protections
* **Files:** `android/app/src/main/kotlin/com/example/whoop_clone/BleForegroundService.kt`, `MainActivity.kt`
* **Root Cause:** Foreground service start without runtime permissions can trigger `SecurityException` or `ForegroundServiceStartNotAllowedException` on Android 12–14.
* **Impact:** App crash if background sync starts before user grants permissions.
* **Remediation Plan (Phase 16):** Safe native try-catch wrapping in Kotlin code.

### ISSUE P3-3: Missing Telemetry Diagnostic Export
* **File:** `lib/data/services/telemetry_ingestion_service.dart`
* **Root Cause:** Ingestion statistics are not exportable for user debugging.
* **Impact:** Cannot troubleshoot field issues on real user devices.
* **Remediation Plan (Phase 5):** Add JSON export of sequence gaps, loss rate, and CRC error log.
