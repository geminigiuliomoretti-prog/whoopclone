Background Completo, Specs UI-UX e Roadmap Ufficiale per Google Antigravity

1. Visione Generale e Palette Cromatiche Pixel-Perfect

Questo documento fornisce il contesto completo (Background Context) da somministrare al tool di Vibe Coding Google Antigravity per garantire una fedeltà del 100% all'interfaccia originale e alla totalità delle funzionalità di Whoop 5.0.

Palette Cromatiche Hex Ufficiali:

Fondo Principale (Dark Mode): #0E1116 / #121212

Superficie Card e Moduli: #1A1F26 / #1E1E1E

Recovery Green (Alto / 67-100%): #00E676

Recovery Yellow (Medio / 34-66%): #FFEA00

Recovery Red (Basso / 1-33%): #FF1744

Strain Light Blue / Sforzo Moderato: #00B0FF

Strain Orange/Red / Sforzo Elevato: #FF3D00 / #D50000

Sleep Purple / Sonno Ristoratore: #7C4DFF

Sleep Light Blue / Sonno Leggero: #40C4FF

Sleep Teal / REM: #00E5FF

Stress Monitor Green / Basso (0.0-1.0): #00E676

Stress Monitor Orange / Medio (1.0-2.0): #FF9100

Stress Monitor Red / Alto (2.0-3.0): #FF1744

Testo Primario: #FFFFFF | Testo Secondario: #B0BEC5 | Bordi/Divider: #263238

2. ROADMAP UFFICIALE WHOOP (IMPASTO FUNZIONALE PER ANTIGRAVITY)

L'applicazione da generare deve implementare tassativamente i 25 moduli funzionali della roadmap ufficiale:

Home: Centro operativo con Tri-Anello (Recovery, Sleep, Strain), stato batteria %, attività del giorno, widget "Il bilancio della tua giornata", WHOOP Coach, My Plan e Dashboard personalizzabile.

Rings (Recovery, Sleep, Strain): Sintesi visiva primaria. Recovery (verde/giallo/rosso) per la prontezza, Sleep (sfumatura viola) per il fabbisogno coperto, Strain (blu/arancione 0-21) per lo sforzo.

Pagina Recovery: Punteggio %, HRV (lnRMSSD), RHR, Frequenza Respiratoria, confronto con la baseline a 30 giorni.

Pagina Sleep: Sleep Performance %, ore dormite, Sleep Need (baseline + debito + strain adjustment - napping), Sleep Debt, Sleep Efficiency, Sleep Consistency, Hypnogram delle 4 fasi (Veglia, Leggero, Profondo SWS, REM).

Sveglia Smart / Alarm: Sveglia aptica a vibrazione silente con 3 modalità (Tempo Esatto, Obiettivo di Sonno, In Zona Verde >67%).

Pagina Strain: Day Strain gauge (0.0-21.0), andamento del carico, battito max e medio, calorie, passi e distribuzione nelle 5 zone FC.

Activities / Activity Details: Analisi singola seduta, strain attività, tempo nelle zone cardiache, mappa overlay GPS outdoor.

Strength Trainer: Modulo per carico muscolare basato su accelerometro/giroscopio 3 assi (esercizi, serie, reps, peso in kg/lbs, tonnellaggio, Muscular vs Cardio load, RPE 1-20).

WHOOP Coach AI (V5.4): Assistente virtuale basato su LLM collegato ai dati biometrici locali e con modulo "La Mia Memoria" (timeline, obiettivi, lesioni).

Journal: Questionario mattutino per 160+ comportamenti (Caffeina, Alcol, Creatina, Proteine, Sauna, Doccia fredda, Coperta pesante, Videogiochi, Melatonina, ecc.).

Cross-data (Journal + Sleep + Recovery): Motore di correlazione statistica che calcola l'impatto percentuale (+/- %) delle abitudini su Recovery e Sonno.

Stress Monitor 24h: Tracciamento dello stress continuo su scala 0.0-3.0 (Basso, Medio, Alto) con grafico ad onda 24h e protocolli di respirazione guidata (Cyclic Sighing).

Health Monitor: Pannello dei 5 parametri vitali (FR, SpO2, FCR, VFC, Temp. Cutanea) con spunta "5/5 nella norma" ed esportazione referto medico PDF a 30 giorni.

Trends / Visione Tendenze: Grafici di analisi longitudinale (7D, 30D, 6M, 1Y) per tutte le metriche.

Calendario: Navigazione temporale storica per consultare e confrontare qualsiasi data passata.

My Plan / Piano Personale: Impostazione e monitoraggio degli obiettivi personali di salute.

Dashboard Personalizzabile: Configurazione e riordinamento delle tessere biometriche della Home.

Profile: Profilo atleta con anagrafica, livello (es. LIVELLO 13), streak di giorni (es. 173 giorni), dati salienti e riepilogo attività.

More / Altro: Gestione dispositivo Whoop 5.0 (ID `5A00479315`, Firmware `50.39.1.0`, Batteria `77%`, HR Broadcasting toggle, Reset).

Integrations: Sincronizzazione con Apple Health, Health Connect, Strava, Withings.

Community & Teams: Gestione Team, classifiche dinamiche (Leaderboard) e chat integrata.

Getting Started / Primi 4 Giorni: Onboarding guidato e calibrazione dei sensori.

Gerarchia di Lettura: Livello 1 (Stato) -> Livello 2 (Spiegazione) -> Livello 3 (Causa Journal) -> Livello 4 (Tendenze).

Routine Pratica d'Uso: Flusso quotidiano Mattina -> Pre-workout -> During Strength -> Post-workout -> Sera.

8 Funzioni Prioritarie: Recovery, Sleep, Journal, Trends, Stress Monitor 24h, WHOOP Coach AI, Strength Trainer, My Plan.

3. Schema Dati e Corrispondenza con i File CSV

L'app locale utilizzerà un database SQLite / Room speculare all'export CSV ufficiale:

cicli_fisiologici (Recovery %, FCR, VFC, Temp cutanea, SpO2, Sforzo, Calorie, Sonno, FR, Efficienza, Regolarità).

allenamenti (Attività, Sforzo, Calorie, FC Max, FC Media, Zone FC 1-5 %, GPS).

voci_diario (Domande comportamentali, Risposta true/false, Note).

sonno (Fasi del sonno, Efficienza, Regolarità, Sonno richiesto e arretrato, Riposo breve).