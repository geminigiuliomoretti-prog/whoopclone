import base64
import os

with open('noop-main/reference_UI/Logo/Wordmark/WHOOP Logo White@3x.png', 'rb') as f:
    b64_wordmark = base64.b64encode(f.read()).decode('utf-8')

with open('noop-main/reference_UI/Logo/Puck/WHOOP Puck White@3x.png', 'rb') as f:
    b64_puck = base64.b64encode(f.read()).decode('utf-8')

with open('noop-main/reference_UI/Logo/Circle/WHOOP Circle White@3x.png', 'rb') as f:
    b64_circle = base64.b64encode(f.read()).decode('utf-8')

html_content = f'''<!DOCTYPE html>
<html lang="it">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>WHOOP 5.0 Official UI Replica (Official Logos Embedded)</title>
  <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;600;700;800;900&display=swap" rel="stylesheet">
  <style>
    * {{ box-sizing: border-box; margin: 0; padding: 0; font-family: 'Inter', sans-serif; }}
    body {{ background-color: #0B0E12; color: #FFFFFF; display: flex; justify-content: center; align-items: center; min-height: 100vh; padding: 12px; }}
    .mobile-frame {{ width: 100%; max-width: 412px; height: 870px; background-color: #101518; border-radius: 40px; border: 3px solid #262C36; display: flex; flex-direction: column; overflow: hidden; box-shadow: 0 25px 60px rgba(0,0,0,0.95); position: relative; }}
    
    /* Header exact match with Official Logo */
    .header {{ padding: 14px 18px 8px 18px; background-color: #101518; display: flex; flex-direction: column; gap: 12px; }}
    .top-bar {{ display: flex; justify-content: space-between; align-items: center; }}
    .avatar-streak {{ display: flex; align-items: center; gap: 8px; }}
    .avatar {{ width: 32px; height: 32px; border-radius: 50%; background: #16EC06; color: #000; font-weight: 900; display: flex; align-items: center; justify-content: center; font-size: 13px; }}
    .streak {{ display: flex; align-items: center; gap: 3px; font-weight: 900; font-size: 13px; color: #FFF; }}
    .date-pill {{ background: #1E262C; padding: 4px 14px; border-radius: 20px; border: 1px solid #262C36; font-size: 11px; font-weight: 900; color: #FFF; letter-spacing: 1.2px; display: flex; align-items: center; gap: 8px; }}
    .batt-box {{ display: flex; align-items: center; gap: 6px; font-size: 13px; font-weight: 900; color: #FFF; }}
    .batt-icon-img {{ height: 18px; }}
    
    .logo-row {{ text-align: center; padding: 2px 0; }}
    .official-logo-img {{ height: 20px; object-fit: contain; }}

    /* 3 Rings Side By Side */
    .rings-hero-row {{ display: flex; justify-content: space-around; padding: 10px 8px; align-items: center; }}
    .ring-card {{ display: flex; flex-direction: column; align-items: center; gap: 8px; cursor: pointer; }}
    .ring-svg-box {{ position: relative; width: 100px; height: 100px; display: flex; justify-content: center; align-items: center; }}
    .ring-svg {{ width: 100%; height: 100%; transform: rotate(-90deg); }}
    .ring-bg {{ fill: none; stroke-width: 9; opacity: 0.18; }}
    .ring-fg {{ fill: none; stroke-width: 9; stroke-linecap: round; }}
    .ring-stat {{ position: absolute; font-size: 22px; font-weight: 900; color: #FFF; letter-spacing: -0.5px; }}
    .ring-lbl {{ font-size: 11px; font-weight: 900; color: #FFF; letter-spacing: 1px; }}

    .scroll-content {{ flex: 1; overflow-y: auto; padding: 10px 16px 14px 16px; display: flex; flex-direction: column; gap: 14px; }}
    .scroll-content::-webkit-scrollbar {{ width: 0; }}

    /* Official Cards */
    .card {{ background: linear-gradient(135deg, #1E262C, #101518); border-radius: 16px; border: 1px solid #262C36; padding: 16px; display: flex; flex-direction: column; gap: 10px; }}
    .card-head {{ display: flex; justify-content: space-between; align-items: center; }}
    .card-title {{ font-size: 12px; font-weight: 900; color: #FFF; letter-spacing: 1px; text-transform: uppercase; }}
    .card-sub {{ font-size: 13px; color: #9EAAB8; line-height: 1.4; }}

    .dismiss-hint {{ font-size: 10px; color: #5F6E80; text-align: right; font-style: italic; margin-top: 4px; }}

    .grid-2 {{ display: grid; grid-template-columns: 1fr 1fr; gap: 10px; }}
    .sq-card {{ background: #1E262C; border-radius: 16px; border: 1px solid #262C36; padding: 14px; display: flex; flex-direction: column; gap: 8px; cursor: pointer; transition: transform 0.2s; }}
    .sq-card:active {{ transform: scale(0.98); }}
    .sq-title {{ font-size: 10px; font-weight: 900; color: #FFF; letter-spacing: 0.8px; text-transform: uppercase; }}
    .badge {{ padding: 4px 8px; border-radius: 6px; font-size: 10px; font-weight: 900; width: max-content; }}

    .banner-prospects {{ background: linear-gradient(90deg, #38434B, #1E262C); border-radius: 14px; padding: 14px 16px; border: 1px solid #262C36; display: flex; justify-content: space-between; align-items: center; font-size: 13px; font-weight: 700; color: #FFF; }}

    .pill-item {{ background: rgba(123, 161, 187, 0.2); border: 1px solid rgba(123, 161, 187, 0.4); padding: 10px 12px; border-radius: 12px; display: flex; justify-content: space-between; align-items: center; cursor: pointer; }}

    .alarm-btn {{ background: #263238; border: 1px solid #262C36; color: #FFF; padding: 12px; border-radius: 12px; font-size: 11px; font-weight: 900; letter-spacing: 1.2px; text-align: center; cursor: pointer; display: flex; align-items: center; justify-content: center; gap: 8px; width: 100%; margin-top: 4px; }}
    .puck-icon-img {{ height: 16px; }}

    .dash-row {{ background: #1E262C; border-radius: 14px; border: 1px solid #262C36; padding: 14px 16px; display: flex; justify-content: space-between; align-items: center; }}
    .dash-lbl {{ font-size: 11px; font-weight: 900; color: #FFF; letter-spacing: 0.8px; }}
    .dash-val {{ font-size: 18px; font-weight: 900; color: #FFF; text-align: right; }}
    .dash-base {{ font-size: 11px; color: #5F6E80; }}

    /* Floating Navigation Bar exact match */
    .nav-bar-wrapper {{ position: absolute; bottom: 10px; left: 16px; right: 16px; }}
    .nav-bar {{ background: #1E262C; border: 1.5px solid #262C36; border-radius: 34px; height: 64px; padding: 0 10px; display: flex; justify-content: space-between; align-items: center; box-shadow: 0 8px 24px rgba(0,0,0,0.6); }}
    .nav-item {{ font-size: 10px; font-weight: 700; color: #9EAAB8; display: flex; flex-direction: column; align-items: center; gap: 3px; cursor: pointer; flex: 1; }}
    .nav-item.active {{ color: #0093E7; }}
    .coach-btn {{ width: 50px; height: 50px; border-radius: 50%; background: #141920; border: 2px solid #0093E7; color: #0093E7; font-weight: 900; font-size: 16px; display: flex; align-items: center; justify-content: center; box-shadow: 0 0 14px rgba(0,147,231,0.5); cursor: pointer; }}
    .coach-icon-img {{ height: 22px; }}
  </style>
</head>
<body>
  <div class="mobile-frame">
    <!-- Header with OFFICIAL LOGO WORDMARK EMBEDDED -->
    <div class="header">
      <div class="top-bar">
        <div class="avatar-streak">
          <div class="avatar">GM</div>
          <div class="streak">🔥 175</div>
        </div>
        <div class="date-pill"><span>&lt;</span> <span>OGGI</span> <span>&gt;</span></div>
        <div class="batt-box">
          <span>62%</span>
          <img class="batt-icon-img" src="data:image/png;base64,{b64_puck}" alt="Puck Battery">
        </div>
      </div>
      <!-- Official WHOOP Logo Image -->
      <div class="logo-row">
        <img class="official-logo-img" src="data:image/png;base64,{b64_wordmark}" alt="WHOOP Logo">
      </div>
    </div>

    <!-- 3 SEPARATE RINGS SIDE BY SIDE -->
    <div class="rings-hero-row">
      <!-- Ring 1: SONNO 81% -->
      <div class="ring-card" onclick="alert('Dettaglio Sonno: 81% (8h 24m) - Efficienza 94%')">
        <div class="ring-svg-box">
          <svg class="ring-svg" viewBox="0 0 100 100">
            <circle class="ring-bg" cx="50" cy="50" r="42" stroke="#7BA1BB"></circle>
            <circle class="ring-fg" cx="50" cy="50" r="42" stroke="#7BA1BB" stroke-dasharray="264" stroke-dashoffset="50"></circle>
          </svg>
          <div class="ring-stat">81%</div>
        </div>
        <div class="ring-lbl">SONNO &gt;</div>
      </div>

      <!-- Ring 2: RECUPERO 82% -->
      <div class="ring-card" onclick="alert('Dettaglio Recupero: 82% (Zona Verde) - VFC 76ms | FCR 51bpm')">
        <div class="ring-svg-box">
          <svg class="ring-svg" viewBox="0 0 100 100">
            <circle class="ring-bg" cx="50" cy="50" r="42" stroke="#16EC06"></circle>
            <circle class="ring-fg" cx="50" cy="50" r="42" stroke="#16EC06" stroke-dasharray="264" stroke-dashoffset="47"></circle>
          </svg>
          <div class="ring-stat">82%</div>
        </div>
        <div class="ring-lbl">RECUPERO &gt;</div>
      </div>

      <!-- Ring 3: SFORZO 0,2 -->
      <div class="ring-card" onclick="alert('Dettaglio Sforzo: 0,2 / 21.0 - Target consigliato: 15.0 - 17.5')">
        <div class="ring-svg-box">
          <svg class="ring-svg" viewBox="0 0 100 100">
            <circle class="ring-bg" cx="50" cy="50" r="42" stroke="#0093E7"></circle>
            <circle class="ring-fg" cx="50" cy="50" r="42" stroke="#0093E7" stroke-dasharray="264" stroke-dashoffset="250"></circle>
          </svg>
          <div class="ring-stat">0,2</div>
        </div>
        <div class="ring-lbl">SFORZO &gt;</div>
      </div>
    </div>

    <!-- Scrollable Content -->
    <div class="scroll-content">
      <!-- VFC Elevata Card (Swipable / Dismissible Notification) -->
      <div class="card" id="notifCard">
        <div class="card-head">
          <span style="font-size:16px; font-weight:700; color:#FFF;" id="notifTitle">VFC elevata</span>
          <span style="background:#263238; padding:3px 8px; border-radius:6px; font-size:11px; font-weight:700;" id="notifBadge">✓ 1</span>
        </div>
        <div class="card-sub" id="notifBody">La tua VFC è 6% più elevata del solito, il che indica un recupero massimo. Una VFC elevata indica che il tuo corpo è in equilibrio e il recupero completo.</div>
        <div class="dismiss-hint" onclick="dismissNotif()">Clicca o fai swipe per rimuovere ➔</div>
      </div>

      <!-- 2 Square Cards con Navigazione Diretta -->
      <div class="grid-2">
        <div class="sq-card" onclick="alert('Apertura Dashboard Salute (HealthScreen): FCR 51bpm, VFC 76ms, SpO2 98.2%, Temp +0.1°C')">
          <div class="sq-title">MONITORAGGIO DELLA SALUTE &gt;</div>
          <div class="badge" style="background:rgba(22,236,6,0.15); color:#16EC06; border:1px solid rgba(22,236,6,0.4);">✓ NELLA NORMA</div>
          <div style="font-size:10px; color:#5F6E80;">5/5 Parametri</div>
        </div>
        <div class="sq-card" onclick="alert('Apertura Dashboard Stress 24h & Protocollo Respirazione Guidata (Cyclic Sighing)')">
          <div class="sq-title">MONITORAGGIO DELLO STRESS &gt;</div>
          <div class="badge" style="background:rgba(0,147,231,0.15); color:#0093E7; border:1px solid rgba(0,147,231,0.4);">BASSO 0,8</div>
          <div style="font-size:10px; color:#5F6E80;">Ultimo agg: 12:32</div>
        </div>
      </div>

      <!-- La mia giornata -->
      <div style="display:flex; justify-content:space-between; align-items:center; margin-top:8px;">
        <span style="font-size:20px; font-weight:700; color:#FFF;">La mia giornata</span>
        <span style="font-size:24px; color:#FFF; cursor:pointer;" onclick="alert('Nuova attività registrata')">+</span>
      </div>

      <div class="banner-prospects">
        <span>🔅 Le tue prospettive giornaliere</span>
        <span>&gt;</span>
      </div>

      <!-- Attività di oggi -->
      <div class="card">
        <div class="card-head">
          <span class="card-title">ATTIVITÀ DI OGGI</span>
          <span>↗</span>
        </div>
        <div class="pill-item" onclick="alert('Visualizza il Dettaglio della Seduta di Sonno (8:24)')">
          <div><span style="font-size:16px; font-weight:900;">🌙 8:24</span> <span style="font-size:11px; font-weight:700; margin-left:8px;">SONNO</span></div>
          <div style="font-size:11px; color:#9EAAB8;">0:52 - 10:32</div>
        </div>
        <div style="display:flex; gap:8px; margin-top:4px;">
          <button style="flex:1; background:transparent; border:1px solid #262C36; color:#FFF; padding:10px; border-radius:10px; font-size:10px; font-weight:700; cursor:pointer;" onclick="alert('Modalità Aggiungi Attività aperta')">+ AGGIUNGI ATTIVITÀ</button>
          <button style="flex:1; background:transparent; border:1px solid #262C36; color:#FFF; padding:10px; border-radius:10px; font-size:10px; font-weight:700; cursor:pointer;" onclick="alert('Live Activity GPS Tracker avviato!')">⏱ INIZIA ATTIVITÀ</button>
        </div>
      </div>

      <!-- SONNO DI STANOTTE Card Completa con Sveglia Smart e Logo Puck -->
      <div class="card">
        <div class="card-head">
          <span class="card-title">SONNO DI STANOTTE</span>
          <span>&gt;</span>
        </div>
        <div style="display:flex; justify-content:space-between; align-items:center; margin: 6px 0;">
          <div>
            <div style="font-size:24px; font-weight:900; color:#FFF;">🌇 22:28</div>
            <div style="font-size:9px; font-weight:900; color:#9EAAB8; letter-spacing:0.5px;">ORA CONSIGLIATA<br>PER ANDARE A LETTO</div>
          </div>
          <div style="font-size:11px; color:#262C36; font-weight:bold;">-----</div>
          <div style="text-align:right;">
            <div style="font-size:24px; font-weight:900; color:#FFF;">🌅 08:45</div>
            <div style="font-size:9px; font-weight:900; color:#FFB74D; letter-spacing:0.5px;" id="alarmStatus">SVEGLIA<br>DISATTIVATA</div>
          </div>
        </div>
        <div class="alarm-btn" onclick="toggleAlarm()">
          <img class="puck-icon-img" src="data:image/png;base64,{b64_puck}" alt="WHOOP Puck">
          <span>IMPOSTA SVEGLIA</span>
        </div>
      </div>

      <!-- La mia dashboard -->
      <div style="display:flex; justify-content:space-between; align-items:center; margin-top:8px;">
        <span style="font-size:18px; font-weight:700; color:#FFF;">La mia dashboard</span>
        <span style="font-size:11px; font-weight:900; color:#FFF; letter-spacing:1px;">PERSONALIZZA 🖊️</span>
      </div>

      <div class="dash-row">
        <div class="dash-lbl">VARIABILITÀ DELLA FREQUENZA CARDIACA</div>
        <div><div class="dash-val">76 <span style="color:#16EC06;">▲</span></div><div class="dash-base">72</div></div>
      </div>
      <div class="dash-row">
        <div class="dash-lbl">FREQUENZA CARDIACA A RIPOSO</div>
        <div><div class="dash-val">51 <span style="color:#16EC06;">▼</span></div><div class="dash-base">53</div></div>
      </div>
      <div class="dash-row">
        <div class="dash-lbl">PASSI</div>
        <div><div class="dash-val">366 <span style="color:#9EAAB8;">▼</span></div><div class="dash-base">15.222</div></div>
      </div>
      <div class="dash-row">
        <div class="dash-lbl">RECUPERO</div>
        <div><div class="dash-val">82% <span style="color:#16EC06;">▲</span></div><div class="dash-base">63%</div></div>
      </div>
      
      <div style="height:60px;"></div>
    </div>

    <!-- Floating Nav Bar with Official Circle Icon Button -->
    <div class="nav-bar-wrapper">
      <div class="nav-bar">
        <div class="nav-item active"><span>🏠</span><span>Home</span></div>
        <div class="nav-item" onclick="alert('Apertura Monitor Salute')"><span>🖤</span><span>Salute</span></div>
        <div class="nav-item" onclick="alert('Apertura Community & Teams')"><span>👥</span><span>Community</span></div>
        <div class="nav-item" onclick="alert('Apertura Menu Altro')"><span>≡</span><span>Altro</span></div>
        <div class="coach-btn" onclick="alert('WHOOP Coach AI pronto!')">
          <img class="coach-icon-img" src="data:image/png;base64,{b64_circle}" alt="WHOOP Coach">
        </div>
      </div>
    </div>
  </div>

  <script>
    const notifs = [
      {{ 'title': 'VFC elevata', 'badge': '✓ 1', 'body': 'La tua VFC è 6% più elevata del solito, il che indica un recupero massimo. Una VFC elevata indica che il tuo corpo è in equilibrio e il recupero completo.' }},
      {{ 'title': 'Prontezza Recupero 82%', 'badge': '✓ 2', 'body': 'Il tuo sistema nervoso autonomo è in condizioni ottimali. Il target di Sforzo consigliato per oggi è tra 15.0 e 17.5.' }},
      {{ 'title': 'Fabbisogno Sonno Ottimizzato', 'badge': '✓ 3', 'body': 'In base all\'attività recente hai 30 minuti di sonno arretrato. Ti consigliamo di coricarti entro le 22:28.' }}
    ];
    let notifIdx = 0;

    function dismissNotif() {{
      notifIdx++;
      if (notifIdx < notifs.length) {{
        document.getElementById('notifTitle').innerText = notifs[notifIdx].title;
        document.getElementById('notifBadge').innerText = notifs[notifIdx].badge;
        document.getElementById('notifBody').innerText = notifs[notifIdx].body;
      }} else {{
        document.getElementById('notifCard').style.display = 'none';
      }}
    }}

    let alarmOn = false;
    function toggleAlarm() {{
      alarmOn = !alarmOn;
      const el = document.getElementById('alarmStatus');
      if (alarmOn) {{
        el.innerHTML = 'SVEGLIA<br>ATTIVATA (08:45)';
        el.style.color = '#16EC06';
        alert('Sveglia Smart Aptica Attivata per le 08:45 (In the Green >=67%)');
      }} else {{
        el.innerHTML = 'SVEGLIA<br>DISATTIVATA';
        el.style.color = '#FFB74D';
        alert('Sveglia Smart Aptica Disattivata');
      }}
    }}
  </script>
</body>
</html>
'''

with open('whoop_app_mobile.html', 'w', encoding='utf-8') as f:
    f.write(html_content)

print('Successfully embedded official high-res base64 logos into whoop_app_mobile.html!')
