import math

# 1. Strain Engine
def tanaka_hr_max(age):
    return 208.0 - (0.7 * age)

def bannister_trimp(duration_min, hr_mean, hr_rest, hr_max, gender='male'):
    delta_hr = max(0.0, min(1.0, (hr_mean - hr_rest) / (hr_max - hr_rest)))
    a = 0.64 if gender == 'male' else 0.86
    b = 1.92 if gender == 'male' else 1.67
    y = a * math.exp(b * delta_hr)
    return duration_min * delta_hr * y

def trimp_to_whoop_strain(trimp):
    if trimp <= 0:
        return 0.0
    k = 0.018
    trimp_max_ref = 450.0
    strain = 21.0 * (math.log(1.0 + k * trimp) / math.log(1.0 + k * trimp_max_ref))
    return max(0.0, min(21.0, strain))

# 2. Strength Trainer Engine
def muscular_load(sets, reps, load_kg, velocity_ms=1.0, rpe=10.0):
    vol = sets * reps * load_kg
    vel_mult = 1.0 + (0.4 * max(0.2, min(3.0, velocity_ms)))
    rpe_mult = 0.5 + (0.05 * max(1.0, min(20.0, rpe)))
    return vol * vel_mult * rpe_mult

# 3. Recovery Engine & Cold Start
def calculate_recovery_baseline(history_ln_rmssd):
    days = len(history_ln_rmssd)
    if days < 4:
        mean = sum(history_ln_rmssd)/days if days > 0 else math.log(65.0)
        return {'mean': mean, 'std': 0.25, 'is_calibrating': True, 'days': days}
    window = history_ln_rmssd[-30:] if days > 30 else history_ln_rmssd
    mean = sum(window) / len(window)
    variance = sum((x - mean)**2 for x in window) / len(window)
    std = math.sqrt(variance)
    if std < 0.05: std = 0.05
    return {'mean': mean, 'std': std, 'is_calibrating': False, 'days': len(window)}

def recovery_score_pct(current_rmssd, history_ln_rmssd, fcr_current, fcr_baseline):
    ln_rmssd = math.log(current_rmssd)
    b = calculate_recovery_baseline(history_ln_rmssd)
    z_hrv = (ln_rmssd - b['mean']) / b['std']
    hrv_pct = 100.0 / (1.0 + math.exp(-1.2 * z_hrv))
    
    z_fcr = -(fcr_current - fcr_baseline) / 3.0
    fcr_pct = 100.0 / (1.0 + math.exp(-1.2 * z_fcr))
    
    score = (0.65 * hrv_pct) + (0.25 * fcr_pct) + (0.10 * 95.0)
    return max(1.0, min(99.0, score)), b

# 4. Sleep Need Engine
def sleep_need_minutes(daily_strain, baseline_min=480.0, debt_min=0.0):
    strain_debt = daily_strain * 12.0
    return max(300.0, baseline_min + strain_debt + debt_min)

# 5. Stress Monitor EMA
def ema_stress(raw_stress, prev_ema, alpha=0.20):
    if prev_ema == 0.0:
        return raw_stress
    return (alpha * raw_stress) + ((1.0 - alpha) * prev_ema)

# 6. Journal Impact (5 Yes / 5 No rule)
def journal_impact(yes_list, no_list):
    count_yes = len(yes_list)
    count_no = len(no_list)
    if count_yes < 5 or count_no < 5:
        return {'is_valid': False, 'impact': 0.0, 'msg': f'Invalid: {count_yes} Yes, {count_no} No (Need >=5)'}
    mean_yes = sum(yes_list) / count_yes
    mean_no = sum(no_list) / count_no
    return {'is_valid': True, 'impact': mean_yes - mean_no, 'msg': 'Valid'}

def main():
    print("=== TEST COMPLETO WHOOP BIOMETRIC ENGINE (6 MODULI) ===")

    # 1. Strain Test
    hr_max = tanaka_hr_max(30)
    print(f"[STRAIN] HRmax (30 anni): {hr_max} bpm")
    trimp = bannister_trimp(60, 150, 55, hr_max, 'male')
    strain = trimp_to_whoop_strain(trimp)
    print(f"[STRAIN] TRIMP: {round(trimp, 2)} -> Whoop Strain: {round(strain, 1)} / 21.0")
    assert 0.0 <= strain <= 21.0

    # 2. Strength Trainer Test
    m_load = muscular_load(sets=4, reps=10, load_kg=80.0, velocity_ms=1.2, rpe=14.0)
    print(f"[STRENGTH TRAINER] Muscular Load (Squat 4x10x80kg): {round(m_load, 1)}")
    assert m_load > 0

    # 3. Recovery Engine Test & Cold Start
    cold_history = [math.log(60.0), math.log(62.0)] # 2 giorni (Cold Start)
    rec_cold, b_cold = recovery_score_pct(65.0, cold_history, 54, 55)
    print(f"[RECOVERY COLD START] Score: {round(rec_cold, 1)}% | Status: {b_cold['is_calibrating']} ({b_cold['days']}/3 giorni)")
    assert b_cold['is_calibrating'] is True

    full_history = [math.log(60.0 + (i%10)) for i in range(35)] # 35 giorni
    rec_full, b_full = recovery_score_pct(72.0, full_history, 51, 55)
    print(f"[RECOVERY REGIME] Score: {round(rec_full, 1)}% | Status: Calibrating={b_full['is_calibrating']} ({b_full['days']} giorni)")
    assert b_full['is_calibrating'] is False

    # 4. Sleep Need Test
    s_need = sleep_need_minutes(daily_strain=16.5, baseline_min=480.0, debt_min=45.0)
    print(f"[SLEEP NEED] Fabbisogno Sonno (Strain 16.5): {round(s_need/60.0, 2)} ore ({round(s_need)} min)")
    assert s_need > 480.0

    # 5. Stress Monitor EMA Test
    ema = 0.0
    for raw in [0.8, 1.2, 2.5, 2.8, 1.0]:
        ema = ema_stress(raw, ema, 0.20)
    print(f"[STRESS MONITOR EMA]: {round(ema, 2)} / 3.0")
    assert 0.0 <= ema <= 3.0

    # 6. Journal Impact Test (Rule 5 Yes / 5 No)
    invalid_res = journal_impact([80, 85, 78], [70, 72])
    print(f"[JOURNAL IMPACT INVALID]: Valid={invalid_res['is_valid']} -> {invalid_res['msg']}")
    assert invalid_res['is_valid'] is False

    valid_res = journal_impact([80, 82, 85, 78, 88, 84], [68, 70, 72, 65, 71])
    print(f"[JOURNAL IMPACT VALID]: Valid={valid_res['is_valid']} -> Impatto: +{round(valid_res['impact'], 1)}%")
    assert valid_res['is_valid'] is True
    assert valid_res['impact'] > 0

    print("\n[SUCCESS] Tutti i 6 motori algoritmi biometrici testati e convalidati con successo!")

if __name__ == "__main__":
    main()
