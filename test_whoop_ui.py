import os

def test_ui_files():
    print("=== VERIFICA COMPONENTI UI WHOOP 5.0 HOME SCREEN ===")
    
    files = [
        'whoop_clone/lib/core/constants/whoop_theme.dart',
        'whoop_clone/lib/views/widgets/whoop_header.dart',
        'whoop_clone/lib/views/widgets/tri_ring_dial.dart',
        'whoop_clone/lib/views/widgets/stress_wave_chart.dart',
        'whoop_clone/lib/views/widgets/weekly_dual_axis_chart.dart',
        'whoop_clone/lib/views/widgets/tonight_sleep_card.dart',
        'whoop_clone/lib/views/widgets/customizable_dashboard_grid.dart',
        'whoop_clone/lib/views/widgets/whoop_fab_modal.dart',
        'whoop_clone/lib/views/home_screen.dart',
    ]

    for f in files:
        full_path = os.path.join(os.getcwd(), f)
        assert os.path.exists(full_path), f"File {f} non trovato!"
        with open(full_path, 'r', encoding='utf-8') as fp:
            content = fp.read()
            assert len(content) > 100
            print(f"[OK] {f} ({len(content)} byte)")

    print("\n[SUCCESS] Tutti i 7 componenti UI e il tema WhoopTheme sono stati verificati con successo!")

if __name__ == "__main__":
    test_ui_files()
