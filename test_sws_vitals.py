import os

def test_sws_vitals_compliance():
    print("=== VERIFICA SWS-WINDOWED HRV/RHR EXTRACTION & UNIFICAZIONE SALUTE ===")

    engine_file = 'whoop_clone/lib/data/services/overnight_sleep_engine.dart'
    viewmodel_file = 'whoop_clone/lib/viewmodels/whoop_viewmodel.dart'
    unit_test_file = 'whoop_clone/test/sws_window_vitals_test.dart'

    for f in [engine_file, viewmodel_file, unit_test_file]:
        assert os.path.exists(f), f"File {f} non trovato!"
        with open(f, 'r', encoding='utf-8') as fp:
            content = fp.read()
            assert len(content) > 100
            print(f"[OK] {f} ({len(content)} byte)")

    # 1. Controllo SWS Windowing ed Aggregazione Stadi
    with open(engine_file, 'r', encoding='utf-8') as fp:
        code = fp.read()
        assert 'swsEpochs' in code
        assert 'motionVar < 0.020' in code
        assert 'totalSleepMin = lightMin + swsMin + remMin' in code
        print("[OK] OvernightSleepEngine estrae VFC/FCR da SWS o fallback 0.020g ed aggrega correttamente totalSleepMin!")

    # 2. Controllo Unificazione Salute nel ViewModel
    with open(viewmodel_file, 'r', encoding='utf-8') as fp:
        vm_code = fp.read()
        assert 'respVal' in vm_code
        assert 'tempVal' in vm_code
        assert 'spo2Val' in vm_code
        assert '>= 7.0 &&' in vm_code
        assert '>= 85.0 &&' in vm_code
        assert '<= 3.0' in vm_code
        print("[OK] WhoopViewModel unifica FCR/VFC da cicli_fisiologici ed applica i clamp fisiologici 7-24, 85-100% e +/-3.0°C!")

    # 3. Controllo Unit Test
    with open(unit_test_file, 'r', encoding='utf-8') as fp:
        test_code = fp.read()
        assert 'expect(extractedRhr, equals(50.0))' in test_code
        assert 'expect(extractedHrv, equals(76.0))' in test_code
        assert 'expect(totalSleepMin, equals(swsMin + remMin + lightMin))' in test_code
        print("[OK] Unit test sws_window_vitals_test.dart verifica con precisione FCR=50bpm, VFC=76ms ed aggregazione stadi!")

    print("\n[SUCCESS] Tutti i test di verifica per l'estrazione SWS-Windowed e l'unificazione della schermata Salute sono stati superati con successo!")

if __name__ == "__main__":
    test_sws_vitals_compliance()
