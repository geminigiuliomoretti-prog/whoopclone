# DOCUMENTAZIONE DEL PROTOCOLLO BLE WHOOP 4.0 / 5.0
**Riferimento Architetturale: Fase 3 (PRO-01, PRO-04, BLE-07)**

> [!IMPORTANT]
> In conformità con la **Regola 2 della Roadmap di Sviluppo**, nessun offset o layout dei pacchetti è considerato certo fino a validazione con cattura grezza (`RawCaptureService` su dispositivo fisico reale).
> Ogni campo in questo documento è categorizzato in modo trasparente come:
> - **VERIFICATO SU CATTURA & FIRMWARE**: Convalidato da firme matematiche CRC, reverse-engineering deterministico o standard BLE.
> - **IPOTESI (IN ATTESA DI CATTURA FISICA)**: Offset derivato dall'analisi statica e da verificare con file `.ndjson` reale.

---

## 1. Struttura dei Frame Incorniciati (Framed Commands & Historical Sync)
Utilizzato per comandi, sincronizzazione orologio, sveglia aptica e scaricamento storico (Store & Forward).

```text
Byte 0       Byte 1       Byte 2       Byte 3       Byte 4..N+3               Byte N+4..N+7
┌────────────┬────────────┬────────────┬────────────┬─────────────────────────┬──────────────┐
│ Start Mark │ Len Lo     │ Len Hi     │ CRC-8      │ Inner Payload (Length N)│ Tail CRC-32  │
│ 0xAA       │ Length & FF│ Length>>8  │ Poly 0x07  │ Type, Seq, Cmd, Data... │ 4 Bytes (LE) │
└────────────┴────────────┴────────────┴────────────┴─────────────────────────┴──────────────┘
```

| Offset (Byte) | Campo | Tipo | Stato Evidenza | Descrizione / Formula |
| :--- | :--- | :--- | :--- | :--- |
| **0** | Start Marker | `uint8` (`0xAA`) | **VERIFICATO** | Byte di sincronizzazione e delimitatore di frame. |
| **1..2** | Declared Length | `uint16` (LE) | **VERIFICATO** | Lunghezza $N$ dell'Inner Payload (esclusi header 4B e tail 4B). |
| **3** | Header CRC-8 | `uint8` | **VERIFICATO** | Calcolato sui byte 1 e 2 con polinomio $0x07$ (`WhoopCrc8`). |
| **4** | Frame Type | `uint8` | **VERIFICATO** | `0x01` per comandi standard, `0x02` per eventi. |
| **5** | Sequence Number | `uint8` | **VERIFICATO** | Contatore pacchetto per ordinamento e rilevamento perdite. |
| **6** | Command Opcode | `uint8` | **VERIFICATO** | `0x16` (Send Historical Data), `0x17` (Ack Historical Data), `0x44` (Alarm). |
| **7..N+3** | Payload Data | `bytes[N-3]` | **IPOTESI** | Dati specifici del comando (in attesa di conferma su cattura). |
| **N+4..N+7** | Tail CRC-32 | `uint32` (LE) | **VERIFICATO** | Calcolato sui byte interni `[4..N+3]` (IEEE 802.3 / Poly 0xEDB88320). |

---

## 2. Struttura del Pacchetto Sensore Flat a 96-Byte (Caratteristica 0005)
Notifiche ad alta frequenza (1 Hz) trasmesse durante la registrazione continua in tempo reale.

| Offset (Byte) | Dimensione | Campo | Tipo | Stato Evidenza | Note e Regole di Ingestione |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **0** | 1 | Prefix Marker | `uint8` (`0xAA`) | **VERIFICATO** | Marcatore iniziale del pacchetto telemetrico. |
| **1** | 1 | Version/Subtype | `uint8` | **IPOTESI** | Versione firmware o flag di canale. |
| **2..3** | 2 | Sequence Number | `uint16` (LE) | **VERIFICATO** | Contatore incrementale (wrap a 65535) per gap detection. |
| **4..7** | 4 | Timestamp Device | `uint32` (LE) | **IPOTESI** | Secondi Unix dell'orologio interno del cinturino. |
| **8** | 1 | Heart Rate | `uint8` (BPM) | **IPOTESI** | Valore istantaneo FC in range $[30, 240]$. |
| **9** | 1 | Reserved / Flags | `uint8` | **IPOTESI** | Bitmask di confidenza ottica PPG. |
| **10..11** | 2 | Accel X | `int16` (LE) | **IPOTESI** | Accelerazione asse X (scalata in g: `raw / 1000.0`). |
| **12..13** | 2 | Accel Y | `int16` (LE) | **IPOTESI** | Accelerazione asse Y (scalata in g: `raw / 1000.0`). |
| **14..15** | 2 | Accel Z | `int16` (LE) | **IPOTESI** | Accelerazione asse Z (scalata in g: `raw / 1000.0`). |
| **16..17** | 2 | RR / rMSSD | `uint16` (LE) | **IPOTESI** | Intervallo PP/RR o variabilità (da validare con cattura). |
| **18..19** | 2 | Skin Temp Raw | `uint16` (LE) | **IPOTESI** | Temperatura cutanea grezza. Se non valida, campo a `null`. |
| **20..21** | 2 | SpO2 Ratio | `uint16` (LE) | **IPOTESI** | Rapporto LED Rosso/Infrarosso. |
| **22..95** | 74 | Canali Ottici PPG | `bytes[74]` | **IPOTESI** | Campioni grezzi dei fotodiodi LED verde/infrarosso. |

---

## 3. Calcolo Scientifico ENMO (Euclidean Norm Minus One)
In conformità con il punto **3.4 della Roadmap (PRO-04, DAT-06)**:
$$\text{ENMO} = \max\left(0.0, \; \sqrt{a_x^2 + a_y^2 + a_z^2} - 1.0\,\text{g}\right)$$

- **Unità:** Rigorosamente espressa in $g$ ($1.0\,\text{g} \approx 9.81\,\text{m/s}^2$).
- **Zero Floor Fittizio:** È stato **completamente rimosso** il floor artificiale `0.002`. Se il cinturino è completamente immobile su una superficie piana, il valore è fisiologicamente e matematicamente $0.0\,\text{g}$.
- **Campi Mancanti:** Se uno qualsiasi degli assi $a_x, a_y, a_z$ è assente, ENMO restituisce rigorosamente `null`.

---

## 4. Servizio Standard Heart Rate (GATT UUID 0x180D / Caratteristica 0x2A37)
- **Byte 0 (Flags):** Bit 0 = formato HR (0 = 8-bit, 1 = 16-bit); Bit 4 = presenza intervalli RR.
- **Byte 1 (+2):** Frequenza cardiaca.
- **Byte successivi:** Intervalli RR reali espressi in $1/1024$ di secondo (convertiti in ms).
- **Salvataggio SQLite:** Gli intervalli RR grezzi reali vengono salvati come array JSON in `rr_intervals_json` della tabella `telemetria_grezza`.
