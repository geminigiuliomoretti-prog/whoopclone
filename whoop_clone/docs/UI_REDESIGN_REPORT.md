# Report di Riprogettazione UI/UX: Design System "Bright Nature"

**Data**: 7 Ottobre 2026  
**Applicazione**: WHOOP 5.0 Flutter Client (`whoop_clone`)  
**Stato Analisi**: `flutter analyze` — 0 errori / 0 avvisi  
**Stato Render Test**: `test/visual_render_audit_test.dart` — 100% Passed (0 RenderFlex Overflows)  

---

## 1. Visione e Filosofia di Design ("Bright Nature")

La riprogettazione visiva dell'applicazione è stata guidata dai principi editoriali, sereni e luminosi ispirati alla schermata di riferimento (Oura style), trasposti in un'identità originale denominata **"Bright Nature"**:
- **Filosofia Core**: *"Un compagno personale per la salute, immerso nella calma della natura, costruito con tecnologia premium."*
- **Luminosità Editoriale**: Abbandonato il tema dark aggressivo e cupo in favore di una palette Light-First calda e ariosa, fondata su toni panna, avorio e bianco latte (`#FAF8F5`).
- **Superfici Organiche**: Schede in puro bianco con bordi hairline minerali ultra-sottili (`0.85px`, `#ECE6DC`), raggi di curvatura ampi (`24px` e `16px`) e ombre ambientali morbidissime e non invasive (`rgba(0,0,0, 0.03)`).
- **Gerarchia Tipografica Editoriale**: Titoli sereni con tracking curato, pesi tipografici calibrati per evitare la pesantezza visiva, e numeri biometrici leggibili e protagonisti.

---

## 2. Token di Design System

### 2.1 Palette Cromatica (`NatureColors`)

| Token | Valore Esadecimale | Ruolo Visivo / Semantico |
|---|---|---|
| `canvas` / `offWhite` | `#FAF8F5` | Sfondo primario luminoso, caldo, privo di affaticamento visivo |
| `card` | `#FFFFFF` | Superficie elevata per schede biometriche |
| `creamLight` | `#F5F1E8` | Superfici secondarie, banner informativi, tab inattivi |
| `border` / `sandBorder` | `#ECE6DC` | Hairline border standard (`0.85px`) |
| `borderSubtle` | `#F3EFE8` | Divisori e bordi ultra-delicati |
| `sage` / `sageDark` | `#3EA572` / `#2E8056` | Recupero ottimale, salute e vitalità |
| `sageBackground` | `#EFF8F3` | Badge e pillole pastello per stati di recupero |
| `teal` / `tealDark` | `#2A8E9E` / `#1E6F7C` | Sonno, fisiologia notturna, tab attivi |
| `tealBackground` | `#EFF8F9` | Badge pastello per metriche del sonno |
| `amberWarm` | `#DFA048` | Sforzo controllato, attenzione moderata, sole mattutino |
| `amberBackground` | `#FDF8EE` | Badge e superfici calde per insight ed energia |
| `terracotta` | `#D76F52` | Sforzo intenso, notifiche di attenzione |
| `terracottaBackground`| `#FDF3F0` | Badge pastello per sforzo / fuori scala |
| `textPrimary` | `#182228` | Tipografia principale ad alto contrasto (antracite profondo) |
| `textSecondary` | `#5A6872` | Sottotitoli, etichette e unità di misura |
| `textMuted` | `#93A0AA` | Timestamp, metadati secondari |

---

## 3. Riprogettazione Componente per Componente

### 3.1 Header & Selettore Data Sereno (`DateSelector`)
- **Prima**: Stile scuro, frecce poco contrastate, sensazione compressa.
- **Dopo**: Header flessibile con pillola centrale "Oggi", frecce chevron delicate, tipografia ariosa con badge data centrato e sfondo sfumato verso il canvas.

### 3.2 I Tre Anelli Biometrici (`ThreeRingWidget`)
- Ridotto il diametro del 12% per liberare respiro verticale nella prima schermata (above the fold).
- Gradiente radiale organico con bagliore soffuso (misty glow) centrato nel cerchio interno.
- Punteggi del Recupero, Sforzo e Sonno presentati con badge pastello coordinati in orizzontale anziché blocchi scuri pesanti.

### 3.3 Card Editoriale "Sun Insight" (`SunInsightCard`)
- Ispirata alla sezione temporale e circadiana dell'esperienza utente.
- Gradiente etereo che evoca la luce naturale (crema dorata `#FDFBF7` verso ambra delicata `#FDF8EE`).
- Iconografia a sole solare e tipografia editoriale ispirata al ritmo biologico.

### 3.4 Schede Metriche & Monitor Sonno Notturno (`TonightSleepCard`)
- Risolto il disallineamento e il glitch di overflow orizzontale nei selettori orari (letto vs sveglia) tramite `FittedBox(fit: BoxFit.scaleDown)`.
- Finitura con bordi hairline, icone tonde pastello e switch a basso attrito visivo.

### 3.5 Grafico dell'Onda di Stress (`StressWaveChart`)
- Eliminato l'overflow nel titolo/sottotitolo tramite wrapping con `Expanded`.
- Curva bezier organica con riempimento gradiente sfumato a zero alla base, senza gabbie o linee di griglia invasive.

### 3.6 Sezione Attività & Diario (`HomeScreen`)
- Banner prospetti giornalieri: eliminato l'overflow di 153px grazie al contenimento proporzionato e alla rimozione di gradienti scuri opachi.
- Pulsanti di azione "Aggiungi Attività" e "Inizia Attività": scalati perfettamente con `FittedBox` per scongiurare qualsiasi overflow su schermi compatti.
- Card "La mia dashboard": header flessibile senza collisioni con il pulsante "Personalizza".

### 3.7 Diario delle Abitudini (`JournalScreen`)
- **Fix Contrasto**: Rimossi tutti i testi bianchi rigidi che risultavano invisibili su superfici chiare.
- Chip di selezione (NO / SÌ): sostituiti con pillole pastello in terracotta (`#FDF3F0`) e salvia (`#EFF8F3`) con bordi hairline e testi a contrasto elevato.
- Barre di impatto abitudini con etichette visibili e barre progressive morbide.

### 3.8 Monitor Parametri Vitali (`HealthScreen` & `HealthVitalsDetailScreen`)
- Iconografia con badge a capsula pastello dedicati (`sageBackground`, `terracottaBackground`, `tealBackground`).
- Risolto il difetto numerico nei dettagli vitali (punteggi passati da `Colors.white` a `WhoopTheme.textPrimary`).
- Pulsante di condivisione e cartelle cliniche allineati al tema luminoso.

### 3.9 Menu Altro (`MoreMenuScreen`) & Coach AI (`CoachScreen`)
- Avatar "GM" rifinito con palette `sageBackground` e testo `sageDark`.
- Badge delle metriche profilo disposti tramite `Wrap` per evitare overflow laterale.
- Messaggi del coach presentati in bolle chiare su tela avorio con avatar verde pino naturale.

### 3.10 Navigatore Inferiore (`MainNavigationScreen`)
- Barra inferiore galleggiante in bianco puro con bordo hairline superiore sand (`#ECE6DC`).
- Icona attiva evidenziata dal colore salvia/teal della natura (`#2A8E9E`) con indicatore sottile.

---

## 4. Risoluzione Overflow & Audit di Rendering

La suite di test automatizzati `visual_render_audit_test.dart` ha verificato l'assenza totale di eccezioni grafiche su viewport standard mobile:

| Schermata / Componente | Stato Iniziale | Risoluzione Applicata | Risultato Finale |
|---|---|---|---|
| Banner Prospetti Giornalieri | 153px RenderFlex Overflow | `Expanded` su testo + card naturale | **0 px (Risolto)** |
| Pulsanti Azione Attività | 47px & 25px Overflows | `FittedBox(scaleDown)` + padding bilanciato | **0 px (Risolto)** |
| Header "La mia dashboard" | 100px RenderFlex Overflow | `Expanded` sul titolo + spacing reattivo | **0 px (Risolto)** |
| Selettori Sonno Notturno | 15px RenderFlex Overflow | `FittedBox` sui blocchi orario/sveglia | **0 px (Risolto)** |
| Stress Wave Chart Header | 18px RenderFlex Overflow | `Expanded` sui testi del grafico | **0 px (Risolto)** |
| Totale Eccezioni RenderFlex | **8 Eccezioni** | Refactoring reattivo universale | **0 Eccezioni** |

---

## 5. Verifica di Integrità e Conformità

1. **Zero Modifiche alla Logica di Dominio**:
   - I repository SQLite, i motori biometrici (`WhoopBiometricEngine`, `WhoopAnalyticsEngine`, `OvernightSleepEngine`), le comunicazioni BLE e la tabella `utente_profilo` sono rimasti al 100% inalterati.
2. **Zero Dati Sintetici (Zero Mock)**:
   - Nessun valore fittizio è stato inserito nel database o nei provider. Tutti i placeholder mostrano coerentemente `--` in assenza di dati reali da cinturino o SQLite.
3. **Analisi Statica Perfetta**:
   - `flutter analyze` produce **0 errori e 0 avvisi** su tutti i file del progetto.
