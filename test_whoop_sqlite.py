import sqlite3
import datetime
import json

def test_whoop_sqlite_schema():
    print("=== TEST CREAZIONE SCHEMA DATABASE SQLITE WHOOP 5.0 ===")
    
    conn = sqlite3.connect(":memory:")
    cursor = conn.cursor()
    cursor.execute("PRAGMA foreign_keys = ON;")

    # 1. cicli_fisiologici
    cursor.execute("""
      CREATE TABLE cicli_fisiologici (
        ora_inizio_ciclo TEXT PRIMARY KEY,
        ora_fine_ciclo TEXT,
        fuso_orario TEXT NOT NULL,
        punteggio_recupero_pct REAL,
        fcr_bpm INTEGER,
        vfc_ms REAL,
        temp_cutanea_c REAL,
        spo2_pct REAL,
        sforzo_giornaliero REAL,
        energia_bruciata_cal INTEGER,
        fc_max_bpm INTEGER,
        fc_media_bpm INTEGER,
        inizio_sonno TEXT,
        inizio_risveglio TEXT,
        andamento_sonno_pct REAL,
        frequenza_respiratoria_rpm REAL,
        durata_sonno_min REAL,
        tempo_a_letto_min REAL,
        sonno_leggero_min REAL,
        sonno_profondo_min REAL,
        sonno_rem_min REAL,
        durata_risveglio_min REAL,
        sonno_richiesto_min REAL,
        sonno_arretrato_min REAL,
        efficienza_sonno_pct REAL,
        regolarita_sonno_pct REAL
      );
    """)

    # 2. allenamenti
    cursor.execute("""
      CREATE TABLE allenamenti (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        ora_inizio_ciclo TEXT NOT NULL,
        ora_fine_ciclo TEXT,
        fuso_orario TEXT NOT NULL,
        ora_inizio_allenamento TEXT NOT NULL,
        ora_fine_allenamento TEXT NOT NULL,
        durata_min REAL NOT NULL,
        nome_attivita TEXT NOT NULL,
        sforzo_richiesto REAL,
        energia_bruciata_cal INTEGER,
        fc_max_bpm INTEGER,
        fc_media_bpm INTEGER,
        zona_fc_1_pct REAL,
        zona_fc_2_pct REAL,
        zona_fc_3_pct REAL,
        zona_fc_4_pct REAL,
        zona_fc_5_pct REAL,
        gps_abilitato INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (ora_inizio_ciclo) REFERENCES cicli_fisiologici (ora_inizio_ciclo) ON DELETE CASCADE
      );
    """)

    # 3. voci_diario
    cursor.execute("""
      CREATE TABLE voci_diario (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        ora_inizio_ciclo TEXT NOT NULL,
        ora_fine_ciclo TEXT,
        fuso_orario TEXT NOT NULL,
        testo_domanda TEXT NOT NULL,
        risposta_affermativa INTEGER NOT NULL DEFAULT 0,
        note TEXT,
        FOREIGN KEY (ora_inizio_ciclo) REFERENCES cicli_fisiologici (ora_inizio_ciclo) ON DELETE CASCADE
      );
    """)

    # 4. sonno
    cursor.execute("""
      CREATE TABLE sonno (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        ora_inizio_ciclo TEXT NOT NULL,
        ora_fine_ciclo TEXT,
        fuso_orario TEXT NOT NULL,
        inizio_sonno TEXT NOT NULL,
        inizio_risveglio TEXT NOT NULL,
        andamento_sonno_pct REAL,
        frequenza_respiratoria_rpm REAL,
        durata_sonno_min REAL,
        tempo_a_letto_min REAL,
        sonno_leggero_min REAL,
        sonno_profondo_min REAL,
        sonno_rem_min REAL,
        durata_risveglio_min REAL,
        sonno_arretrato_min REAL,
        efficienza_sonno_pct REAL,
        regolarita_sonno_pct REAL,
        riposo_breve INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (ora_inizio_ciclo) REFERENCES cicli_fisiologici (ora_inizio_ciclo) ON DELETE CASCADE
      );
    """)

    print("[SUCCESS] Tutte le 4 tabelle create con vincoli Primary Key e Foreign Key!")

    # Test Inserimento e JOIN
    c1_time = datetime.datetime.now(datetime.timezone.utc).isoformat()
    cursor.execute("""
        INSERT INTO cicli_fisiologici (ora_inizio_ciclo, fuso_orario, punteggio_recupero_pct, fcr_bpm, vfc_ms, sforzo_giornaliero)
        VALUES (?, 'UTC+02:00', 88.0, 52, 74.5, 14.8);
    """, (c1_time,))

    cursor.execute("""
        INSERT INTO allenamenti (ora_inizio_ciclo, fuso_orario, ora_inizio_allenamento, ora_fine_allenamento, durata_min, nome_attivita, sforzo_richiesto, gps_abilitato)
        VALUES (?, 'UTC+02:00', ?, ?, 75.0, 'Ciclismo', 13.5, 1);
    """, (c1_time, c1_time, c1_time))

    cursor.execute("""
        INSERT INTO voci_diario (ora_inizio_ciclo, fuso_orario, testo_domanda, risposta_affermativa, note)
        VALUES (?, 'UTC+02:00', 'Magnesio preso?', 1, '400mg');
    """, (c1_time,))

    cursor.execute("""
        INSERT INTO sonno (ora_inizio_ciclo, fuso_orario, inizio_sonno, inizio_risveglio, durata_sonno_min, efficienza_sonno_pct)
        VALUES (?, 'UTC+02:00', ?, ?, 455.0, 91.9);
    """, (c1_time, c1_time, c1_time))

    # Query di JOIN per testare la Foreign Key
    cursor.execute("""
        SELECT c.punteggio_recupero_pct, a.nome_attivita, a.sforzo_richiesto, s.durata_sonno_min, d.testo_domanda
        FROM cicli_fisiologici c
        JOIN allenamenti a ON c.ora_inizio_ciclo = a.ora_inizio_ciclo
        JOIN sonno s ON c.ora_inizio_ciclo = s.ora_inizio_ciclo
        JOIN voci_diario d ON c.ora_inizio_ciclo = d.ora_inizio_ciclo;
    """)

    row = cursor.fetchone()
    print("[JOIN QUERY RESULT]:", row)
    assert row[0] == 88.0
    assert row[1] == 'Ciclismo'
    assert row[3] == 455.0
    print("[SUCCESS] Query di JOIN multi-tabella completata con successo!")

if __name__ == "__main__":
    test_whoop_sqlite_schema()
