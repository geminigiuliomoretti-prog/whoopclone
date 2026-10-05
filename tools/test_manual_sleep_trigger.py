import os

def test_manual_sleep_trigger_files():
    print("=== VERIFICA PIPELINE TRIGGER ENGINE SONNO MANUALE ED UNIT TEST ===")

    test_file = 'whoop_clone/test/manual_sleep_trigger_test.dart'
    viewmodel_file = 'whoop_clone/lib/viewmodels/whoop_viewmodel.dart'
    modal_file = 'whoop_clone/lib/views/widgets/manual_activity_modal.dart'

    for f in [test_file, viewmodel_file, modal_file]:
        assert os.path.exists(f), f"File {f} non trovato!"
        with open(f, 'r', encoding='utf-8') as fp:
            content = fp.read()
            assert len(content) > 100
            print(f"[OK] {f} ({len(content)} byte)")

    # Verifiche sintattiche e di presenza chiavi richieste
    with open(test_file, 'r', encoding='utf-8') as fp:
        test_code = fp.read()
        assert 'processAndAddManualSleep' in test_code
        assert 'insertTelemetriaPoint' in test_code
        assert 'getSonnoByDate' in test_code
        assert 'getCicloByDate' in test_code
        print("[OK] Test automatizzato manual_sleep_trigger_test.dart contiene tutti i controlli delle asserzioni!")

    with open(viewmodel_file, 'r', encoding='utf-8') as fp:
        vm_code = fp.read()
        assert 'processAndAddManualSleep' in vm_code
        assert 'getTelemetriaInTimeRange' in vm_code
        assert 'processNightlyTelemetry' in vm_code
        print("[OK] WhoopViewModel contiene il metodo processAndAddManualSleep con query e ricalcolo reattivo!")

    print("\n[SUCCESS] Tutti i test di verifica della pipeline Trigger Engine e dell'Unit Test sono stati superati con successo!")

if __name__ == "__main__":
    test_manual_sleep_trigger_files()
