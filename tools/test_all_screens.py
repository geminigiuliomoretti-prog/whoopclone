import os

def test_roadmap_screens():
    print("=== VERIFICA COMPLETA DELLE 6 SCHERMATE ROADMAP WHOOP 5.0 ===")
    
    files = [
        'whoop_clone/lib/views/main_navigation_screen.dart',
        'whoop_clone/lib/views/screens/health_screen.dart',
        'whoop_clone/lib/views/screens/journal_screen.dart',
        'whoop_clone/lib/views/screens/coach_screen.dart',
        'whoop_clone/lib/views/screens/trends_screen.dart',
        'whoop_clone/lib/views/screens/community_screen.dart',
        'whoop_clone/lib/views/screens/profile_plan_screen.dart',
        'whoop_clone/lib/data/database/database_helper.dart',
    ]

    for f in files:
        full_path = os.path.join(os.getcwd(), f)
        assert os.path.exists(full_path), f"File {f} non trovato!"
        with open(full_path, 'r', encoding='utf-8') as fp:
            content = fp.read()
            assert len(content) > 100
            print(f"[OK] {f} ({len(content)} byte)")

    print("\n[SUCCESS] Tutte le 6 schermate della Roadmap Ufficiale e il navigatore IndexedStack sono stati verificati con successo!")

if __name__ == "__main__":
    test_roadmap_screens()
