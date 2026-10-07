ROADMAP COMPLETA E GUIDA FUNZIONALE WHOOP APP (VERSIONE REVISIONATA E STRUTTURATA)

Guida Architetturale e Funzionale a Schermate, Moduli e Routine Pratica

Indice Generale dei Moduli

Home (Centro Operativo)

Rings: Recovery, Sleep, Strain

Pagina Recovery (Prontezza Fisiologica)

Pagina Sleep (Qualità e Architettura del Sonno)

Sveglia Smart / Alarm (Aptica Strategica)

Pagina Strain (Carico Cardiovascolare Accumulato)

Activities / Activity Details (Analisi Singola Seduta)

Strength Trainer (Carico Muscolare e Tonnellaggio)

WHOOP Coach AI (Modulo di Interpretazione e Guida)

Journal (Tracciamento Comportamenti e Contesto)

Cross-data Analysis: Journal + Sleep + Recovery

Stress Monitor 24h (Carico Interno Istantaneo)

Health Monitor (Viti Biometrici e Baseline)

Trends / Visione delle Tendenze (Analisi Longitudinale)

Calendario (Storico e Ricorrenze)

My Plan / Piano Personale (Strutturazione Obiettivi)

Dashboard Personalizzabile (Vista Metriche Prioritarie)

Profile / Profilo Atleta (Anagrafica e Memoria)

More / Altro (Impostazioni e Servizi)

Integrations (Integrazione Ecosistemi Esterni)

Community & Teams (Social e Classifiche)

Getting Started / Onboarding Primi 4 Giorni

Gerarchia di Lettura dei Dati Whoop

Routine Pratica d’Uso Giornaliera

Le 8 Funzioni Prioritarie da Padroneggiare

1. Home (Centro Operativo)

La schermata principale dell'applicazione funge da dashboard centrale per valutare all'istante lo stato fisiologico dell'atleta e pianificare la giornata.

Componenti Visivi: Concentric Tri-Ring Dial (Recovery, Sleep, Strain), stato sensore BLE e batteria (%), lista attività del giorno, widget "Il bilancio della tua giornata", scorciatoia WHOOP Coach, sezione "My Plan", Dashboard tessere personalizzate, indicatore streak e notifiche.

Scopo Applicativo: Consente in pochi secondi di determinare la prontezza del corpo, decidere il target di allenamento e stabilire se spingere, mantenere o privilegiare il recupero.

2. Rings: Recovery, Sleep, Strain

I tre anelli concentrici rappresentano la sintesi visiva primaria dell'esperienza Whoop.

Recovery Ring: Prontezza fisiologica del giorno. Basato su HRV (RMSSD), RHR, Frequenza Respiratoria e sonno. Colori: Verde (alta prontezza), Giallo (prontezza media), Rosso (recupero incompleto/affaticamento).

Sleep Ring: Percentuale del fabbisogno di sonno dinamico coperta. Valuta ore dormite, sleep need, sleep performance e coerenza degli orari. Sfumatura blu/viola.

Strain Ring: Carico cardiovascolare accumulato (scala logaritmica 0.0 – 21.0). Va sempre interpretato in combinazione con il Recovery score.

3. Pagina Recovery (Prontezza Fisiologica)

Fornisce il quadro dettagliato del sistema nervoso autonomo (SNA).

Metriche Chiave: HRV (lnRMSSD, indicatore di adattamento e tono vagale), RHR (frequenza cardiaca a riposo durante sonno SWS), Frequenza Respiratoria (rpm), e variazioni rispetto alla baseline rolling di 30 giorni.

Uso Corretto: Non interpretare il valore isolatamente, ma incrociarlo con la qualità del sonno della notte, lo strain del giorno precedente e i fattori registrati nel Journal.

4. Pagina Sleep (Qualità e Architettura del Sonno)

Analizza la struttura quantitativa e qualitativa del sonno.

Metriche Chiave: Sleep Performance (%), Sleep Need (fabbisogno dinamico = baseline + debito accumulato + aggiustamento da strain - credito sonnellini), Sleep Debt, Sleep Efficiency (%), Sleep Consistency (regolarità orari), Wake Events (risvegli) e Hypnogram (fasi Veglia, Sonno Leggero, Sonno Profondo SWS e REM).

5. Sveglia Smart / Alarm (Aptica Strategica)

Sveglia a vibrazione aptica silenziosa sul sensore con 3 modalità di attivazione:

Tempo Esatto: Sveglia ad un orario fisso preimpostato (massima stabilità circadiana).

Obiettivo di Sonno: Risveglio dinamico quando si raggiunge il target di sonno selezionato (Peak 100%, Perform 85%, Get By 70%).

In Zona Verde: Risveglio intelligente quando il Recovery previsto raggiunge almeno il 67% all'interno di una finestra temporale di 1 ora.

6. Pagina Strain (Carico Cardiovascolare Accumulato)

Misura l'impatto cardiovascolare totale della giornata (scala 0.0 – 21.0).

Elementi: Day Strain gauge, grafico dell'andamento del carico nel tempo, battito massimo e medio, calorie totali bruciate (BMR + attivo), passi e distribuzione del tempo nelle 5 zone di frequenza cardiaca.

7. Activities / Activity Details (Analisi Singola Seduta)

Dettaglio specifico per ogni singolo allenamento o attività registrata.

Elementi: Durata, Activity Strain, HR media e max, grafico dell'andamento cardiaco diviso nelle 5 zone FC, calorie e tracciato GPS overlay per attività outdoor.

8. Strength Trainer (Carico Muscolare e Tonnellaggio)

Modulo avanzato accessibile dal tasto FAB (+) per la misurazione del carico muscolare tramite accelerometro e giroscopio a 3 assi.

Funzionalità: Creazione e selezione workout (esercizi, serie, ripetizioni, peso in kg/lbs), calcolo del Muscular Load distinto dal Cardiovascular Load, conteggio tonnellaggio/volume, progressione esercizi, record personali (PR) e inserimento RPE finale (scala 1–20).

9. WHOOP Coach AI (Modulo di Interpretazione e Guida)

Assistente virtuale avanzato basato su LLM e addestrato sui dati biometrici locali dell'utente.

Funzionalità: Interpreta le metriche, collega abitudini e recupero, spiega anomalie biometriche, costruisce schede di allenamento personalizzate e mantiene la memoria storica (timeline, obiettivi, lesioni o condizioni dell'atleta).

10. Journal (Tracciamento Comportamenti e Contesto)

Questionario mattutino per la registrazione di oltre 160 comportamenti e fattori di stile di vita (Caffeina, Alcol, Schermi a letto, Pasti tardivi, Creatina, Proteine, Sauna, Doccia fredda, Coperta pesante, Videogiochi, Stress percepito, Farmaci).

11. Cross-data Analysis: Journal + Sleep + Recovery

Motore di analisi di correlazione statistica che mette in relazione le risposte del Journal con le variazioni percentuale (+/- %) del Recovery Score e dell'efficienza del sonno su finestre di 30-90 giorni.

12. Stress Monitor 24h (Carico Interno Istantaneo)

Tracciamento dello stress in tempo reale su scala da 0.0 a 3.0 (Basso 0.0-1.0, Medio 1.0-2.0, Alto 2.0-3.0), isolando lo stress fisiologico non legato all'attività fisica e fornendo esercizi di respirazione guidata (Cyclic Sighing).

13. Health Monitor (Viti Biometrici e Baseline)

Pannello di controllo dei 5 parametri vitali fondamentali: Frequenza Cardiaca a Riposo (FCR), Variabilità della Frequenza Cardiaca (VFC), Frequenza Respiratoria (FR), Saturazione di Ossigeno (SpO2) e Variazione della Temperatura Cutanea (ΔT), con indicatore "5/5 nella norma" ed esportazione del referto medico PDF a 30 giorni.

14. Trends / Visione delle Tendenze (Analisi Longitudinale)

Schermata di analisi a medio e lungo termine (7 giorni, 30 giorni, 6 mesi, 1 anno) per verificare l'andamento reale delle metriche di Sforzo, Recupero, VFC, FCR, Sonno, Stress, VO2 Max e Peso.

15. Calendario (Storico e Ricorrenze)

Interfaccia di navigazione temporale per consultare i dati di qualsiasi data passata, confrontare periodi e identificare pattern di affaticamento o recupero.

16. My Plan / Piano Personale (Strutturazione Obiettivi)

Sezione per l'impostazione di obiettivi di salute e performance (es. migliorare il sonno, aumentare i giorni in zona verde, incrementare la VFC, ridurre il sonno arretrato).

17. Dashboard Personalizzabile

Permette di riordinare e mettere in primo piano sulla Home le tessere biometriche di maggior interesse per l'atleta.

18. Profile / Profilo Atleta (Anagrafica e Memoria)

Profilo personale dell'atleta contenente dati anagrafici, livello, giorni di streak, memoria contestuale, dati salienti (1M, 3M, Tutto il tempo) e riepilogo delle attività svolte.

19. More / Altro (Impostazioni e Servizi)

Sezione per la gestione del dispositivo Whoop 5.0 (ID hardware 5A00479315, Firmware 50.39.1.0, livello batteria 77%), lingua, notifiche, privacy, controllo firmware e reset.

20. Integrations (Ecosistemi Esterni)

Modulo per la sincronizzazione dei dati con servizi terzi (Apple Health, Health Connect, Strava, TrainingPeaks, Withings).

21. Community & Teams (Social e Classifiche)

Creazione e gestione di Team con classifiche dinamiche (Leaderboards per Strain, Recovery o Sleep) e chat di gruppo.

22. Getting Started / Onboarding Primi 4 Giorni

Percorso guidato di prima configurazione e calibrazione dei sensori per i nuovi utenti.

23. Gerarchia di Lettura dei Dati Whoop

Livello 1 (Stato del Giorno): Recovery, Sleep, Strain.

Livello 2 (Spiegazione Fisiologica): HRV, RHR, Frequenza Respiratoria, Stress.

Livello 3 (Causa Probabile): Journal, routine, alimentazione, contesto.

Livello 4 (Verità Longitudinale): Trends e Calendario su 2-6 settimane.

24. Routine Pratica d’Uso Giornaliera

Mattina: Controlla Recovery e Sleep per impostare il target del giorno; compila il Journal.

Pre-Allenamento: Verifica Recovery + Strain consigliato per regolare l'intensità della seduta.

Durante Forza: Attiva lo Strength Trainer per registrare serie, reps e pesi.

Post-Allenamento: Analizza gli Activity Details e il carico muscolare/cardiovascolare.

Sera: Verifica consigli Bedtime, imposta la sveglia aptica e prepara la routine di sonno.

25. Le 8 Funzioni Prioritarie da Padroneggiare

Priorità

Funzione

Descrizione Sintetica

1

Recovery Score

Valutazione della prontezza fisica quotidiana.

2

Sleep Performance

Rapporto tra sonno ottenuto e fabbisogno dinamico.

3

Journal & Impact

Analisi delle correlazioni tra abitudini e biometria.

4

Trends

Analisi dell'andamento dei dati nel lungo periodo.

5

Stress Monitor

Monitoraggio del carico interno in tempo reale.

6

WHOOP Coach AI

Supporto decisionale basato su intelligenza artificiale.

7

Strength Trainer

Misurazione del carico muscolare e tonnellaggio.

8

My Plan

Definizione e tracciamento degli obiettivi di salute.