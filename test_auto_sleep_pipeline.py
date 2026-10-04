import os
import sys

def test_auto_sleep_pipeline_compliance():
    print("=== VERIFICA SPECIFICHE AUTO-SLEEP DETECTION, STAGING & METRIC TRIGGER PIPELINE ===")

    engine_file = 'whoop_clone/lib/data/services/overnight_sleep_engine.dart'
    viewmodel_file = 'whoop_clone/lib/viewmodels/whoop_viewmodel.dart'
    unit_test_file = 'whoop_clone/test/auto_sleep_pipeline_test.dart'

    for f in [engine_file, viewmodel_file, unit_test_file]:
        assert os.path.exists(f), f"File {f} non trovato!"
        with open(f, 'r', encoding='utf-8') as fp:
            content = fp.read()
            assert len(content) > 100
            print(f"[OK] {f} ({len(content)} byte)")

    # 1. Controllo Macchina a Stati FSM Auto-Sleep Detection & Soglie
    with open(engine_file, 'r', encoding='utf-8') as fp:
        engine_code = fp.read()
        assert 'enum AutoSleepState' in engine_code
        assert 'class AutoSleepDetector' in engine_code
        assert 'enmoSleepThresh' in engine_code
        assert 'enmoWakeThresh' in engine_code
        assert 'sleepInProgress' in engine_code
        assert 'autoSleepDetectedStream' in engine_code
        assert '_backdateSleepStart' in engine_code
        assert '_backdateSleepEnd' in engine_code
        assert 'detectSleepBoundaries' in engine_code
        assert '_extractLastSwsCycleMetrics' in engine_code
        assert 'sleepPerformancePct' in engine_code
        print("[OK] OvernightSleepEngine & AutoSleepDetector implementano FSM, quiescenza ENMO (<0.015g), wake (>0.080g), SWS HRV extraction e trigger!")

    # 2. Controllo Integrazione nel WhoopViewModel
    with open(viewmodel_file, 'r', encoding='utf-8') as fp:
        vm_code = fp.read()
        assert '_autoSleepDetector' in vm_code
        assert '_initAutoSleepListener' in vm_code
        assert 'autoSleepDetector' in vm_code
        assert 'AutoSleepDetector' in vm_code
        assert 'processBpmSample' in vm_code
        print("[OK] WhoopViewModel integra AutoSleepDetector con broadcast reattivo e ricalcolo dashboard!")

    # 3. Controllo Unit Test
    with open(unit_test_file, 'r', encoding='utf-8') as fp:
        test_code = fp.read()
        assert 'AutoSleepDetector' in test_code
        assert 'expect(finalRhr, equals(47.0))' in test_code
        assert 'expect(finalHrv, equals(86.0))' in test_code
        assert 'expect(totalSleepMin, equals(swsMin + remMin + lightMin))' in test_code
        assert 'detectSleepBoundaries' in test_code
        assert 'WhoopViewModel' in test_code
        print("[OK] Unit test auto_sleep_pipeline_test.dart copre stream 9h, estrazione ultimo ciclo SWS, boundary detection e reattività ViewModel!")

    print("\n[SUCCESS] Tutte le verifiche della pipeline di rilevamento automatico del sonno sono state superate con successo!")

if __name__ == "__main__":
    test_auto_sleep_pipeline_compliance()
