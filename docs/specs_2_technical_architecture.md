Documentazione Tecnica: Architettura, Protocolli BLE e Modelli Algoritmetici Whoop 5.0 (Allineata alla Roadmap Ufficiale)

1. Architettura Software e Schema Database Locale (CSV Specs)

L'applicazione offline utilizzerà un database SQLite / Room basato sui 4 tipi di esportazione dati di Whoop:

Schema Tabelle Database Locale:

cicli_fisiologici: ora_inizio_ciclo (DATETIME PRIMARY KEY), ora_fine_ciclo (DATETIME), fuso_orario (TEXT), punteggio_recupero_pct (INT), fcr_bpm (INT), vfc_ms (FLOAT), temp_cutanea_c (FLOAT), spo2_pct (FLOAT), sforzo_giornaliero (FLOAT 0-21), energia_bruciata_cal (INT), fc_max_bpm (INT), fc_media_bpm (INT), inizio_sonno (DATETIME), inizio_risveglio (DATETIME), andamento_sonno_pct (INT), frequenza_respiratoria_rpm (FLOAT), durata_sonno_min (INT), tempo_a_letto_min (INT), sonno_leggero_min (INT), sonno_profondo_min (INT), sonno_rem_min (INT), durata_risveglio_min (INT), sonno_richiesto_min (INT), sonno_arretrato_min (INT), efficienza_sonno_pct (INT), regolarita_sonno_pct (INT).

allenamenti: ora_inizio_ciclo (DATETIME), ora_fine_ciclo (DATETIME), fuso_orario (TEXT), ora_inizio_allenamento (DATETIME), ora_fine_allenamento (DATETIME), durata_min (INT), nome_attivita (TEXT), sforzo_richiesto (FLOAT), energia_bruciata_cal (FLOAT), fc_max_bpm (INT), fc_media_bpm (INT), zona_fc_1_pct (INT), zona_fc_2_pct (INT), zona_fc_3_pct (INT), zona_fc_4_pct (INT), zona_fc_5_pct (INT), gps_abilitato (BOOLEAN).

voci_diario: ora_inizio_ciclo (DATETIME), ora_fine_ciclo (DATETIME), fuso_orario (TEXT), testo_domanda (TEXT), risposta_affermativa (BOOLEAN), note (TEXT).

sonno: ora_inizio_ciclo (DATETIME), ora_fine_ciclo (DATETIME), fuso_orario (TEXT), inizio_sonno (DATETIME), inizio_risveglio (DATETIME), andamento_sonno_pct (INT), frequenza_respiratoria_rpm (FLOAT), durata_sonno_min (INT), tempo_a_letto_min (INT), sonno_leggero_min (INT), sonno_profondo_min (INT), sonno_rem_min (INT), durata_risveglio_min (INT), sonno_richiesto_min (INT), sonno_arretrato_min (INT), efficienza_sonno_pct (INT), regolarita_sonno_pct (INT), riposo_breve (BOOLEAN).

2. Connettività BLE e Interfaccia Hardware Whoop 5.0

GATT Standard Heart Rate: Service 0x180D, Characteristic 0x2A37 (Notify).

Servizio Proprietario Raw Stream: Service 61080000-8d6d-82b8-614a-1c8cb0f8dcc6, Characteristic 61080005.

Informazioni Hardware Whoop 5.0: ID Dispositivo 5A00479315, Firmware 50.39.1.0.

3. Formule Matematiche e Algoritmi Biometrici (Mappati sui 25 Moduli della Roadmap)

A. Strain Score (0.0 – 21.0) - Modulo 6 & 7

$HR_{max} = 208 - 0.7 \times \text{età}$ (Tanaka).

$HRR = HR_{max} - HR_{rest}$. Riserva frazionaria $x_i = (HR_i - HR_{rest}) / HRR$.

TRIMP di Bannister: $\text{TRIMP} = \sum \Delta t_i \cdot x_i \cdot e^{1.92 \cdot x_i}$.

Compressione logaritmica: $\text{Strain} = 21.0 \cdot (1 - e^{-k \cdot \text{TRIMP}})$.

B. Strength Trainer Engine (Carico Muscolare) - Modulo 8

Stima del carico muscolare integrando il volume (serie $\times$ ripetizioni $\times$ carico) con i dati cinematici dell'accelerometro e giroscopio a 3 assi (velocità d'esecuzione delle ripetizioni) e scala RPE 1–20.

C. Recovery Score (0% – 100%) - Modulo 2 & 3

HRV $\text{RMSSD} = \sqrt{\frac{1}{N-1} \sum (RR_{i+1} - RR_i)^2}$, con trasformazione $\ln(\text{RMSSD})$.

Normalizzazione Z-score rispetto alla media mobile a 30 giorni:$$Z_{HRV} = \frac{\ln(\text{RMSSD}) - \mu_{30}}{\sigma_{30}}, \quad Z_{RHR} = \frac{\text{RHR} - \mu_{30}}{\sigma_{30}}$$

Punteggio percentuale ottenuto tramite trasformazione sigmoidale dell'indice composito.

D. Sleep Need & Sveglia Smart Engine - Modulo 4 & 5

L'indice di stress istantaneo combina la frequenza cardiaca in tempo reale e la variabilità della frequenza cardiaca ($HRV_{instant}$) normalizzate sul valore di riposo:$$\text{Stress}_{t} = 3.0 \times \left( \alpha \cdot \frac{HR_t - HR_{rest}}{HR_{max} - HR_{rest}} + (1 - \alpha) \cdot \left(1 - \frac{HRV_t}{HRV_{baseline}}\right) \right)$$

$\text{Sleep Need} = \text{Baseline} + \text{Sleep Debt} + \text{Strain Adjustment} - \text{Nap Credit}$.

Sveglia Smart Aptica: Trigger a vibrazione in base a Tempo Esatto, Obiettivo di Sonno o Soglia Recovery >67% (Zona Verde).

E. Monitoraggio dello Stress 24h (Scala 0.0 – 3.0) - Modulo 12

F. Journal Impact Engine (Cross-Data Analytics) - Modulo 10 & 11

Per ciascun comportamento registrato nel Diario (almeno 5 voci "Sì" e 5 "No" su 90 giorni):$$\text{Impatto \%} = \overline{\text{Recovery}}_{\text{Sì}} - \overline{\text{Recovery}}_{\text{No}}$$

Mostra bar chart orizzontali verdi per impatto positivo e arancioni/rossi per impatto negativo.