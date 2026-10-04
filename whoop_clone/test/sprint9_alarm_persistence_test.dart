import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:whoop_clone/data/database/database_helper.dart';
import 'package:whoop_clone/data/ble/ble_connection_manager.dart';
import 'package:whoop_clone/data/ble/noop_protocol_decoder.dart';
import 'package:whoop_clone/data/repositories/whoop_repository.dart';
import 'package:whoop_clone/data/repositories/sqlite_whoop_repository.dart';
import 'package:whoop_clone/data/repositories/dashboard_preferences_repository.dart';
import 'package:whoop_clone/viewmodels/whoop_viewmodel.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    DatabaseHelper.isTestMode = true;
  });

  group('Sprint 9 — Persistent Haptic Alarm & BLE Integration Tests', () {
    late DatabaseHelper dbHelper;
    late WhoopRepository repository;
    late BleConnectionManager bleManager;
    late DashboardPreferencesRepository prefRepo;
    late WhoopViewModel viewModel;

    setUp(() async {
      dbHelper = DatabaseHelper();
      await dbHelper.clearAllTables();

      repository = SqliteWhoopRepository(dbHelper: dbHelper);
      bleManager = BleConnectionManager();
      prefRepo = DashboardPreferencesRepository(dbHelper: dbHelper);

      viewModel = WhoopViewModel(
        repository: repository,
        bleManager: bleManager,
        dashboardPreferencesRepository: prefRepo,
      );

      await viewModel.loadData();
    });

    test('1. Stato Sveglia Iniziale: Disattivata di default in SQLite', () async {
      expect(viewModel.isAlarmEnabled, false);
      expect(viewModel.alarmTime.hour, 7);
      expect(viewModel.alarmTime.minute, 0);

      final row = await dbHelper.getImpostazioniSveglia();
      expect(row['is_enabled'], 0);
      expect(row['alarm_hour'], 7);
      expect(row['alarm_minute'], 0);
    });

    test('2. Salva Sveglia: Scrittura su SQLite e ripristino su loadData', () async {
      const newTime = TimeOfDay(hour: 6, minute: 30);
      await viewModel.saveAlarmSettings(
        isEnabled: true,
        alarmTime: newTime,
        selectedMode: 2,
        targetGoalIdx: 0,
        hapticIntensity: 2,
      );

      expect(viewModel.isAlarmEnabled, true);
      expect(viewModel.alarmTime.hour, 6);
      expect(viewModel.alarmTime.minute, 30);
      expect(viewModel.alarmModeIdx, 2);
      expect(viewModel.alarmGoalIdx, 0);
      expect(viewModel.alarmHapticIntensity, 2);

      final reloadedVm = WhoopViewModel(
        repository: repository,
        bleManager: bleManager,
        dashboardPreferencesRepository: prefRepo,
      );
      await reloadedVm.loadData();

      expect(reloadedVm.isAlarmEnabled, true);
      expect(reloadedVm.alarmTime.hour, 6);
      expect(reloadedVm.alarmTime.minute, 30);
      expect(reloadedVm.alarmModeIdx, 2);
      expect(reloadedVm.alarmGoalIdx, 0);
      expect(reloadedVm.alarmHapticIntensity, 2);
    });

    test('3. Generazione Pacchetto Aptico 20-Byte HapticClockEncoder con CRC-32 Custom', () {
      final alarmTime = DateTime(2026, 8, 10, 7, 15);
      final payload = HapticClockEncoder.encodeAlarmTime(
        alarmTime: alarmTime,
        vibrationPattern: 2,
      );

      expect(payload.length, 20);
      expect(payload[0], 0xAA);
      expect(payload[1], 0x10);
      expect(payload[2], 0x00);
      expect(payload[3], 0x57);
      expect(payload[4], 0x23);
      expect(WhoopCrc32.verify(payload), isTrue);
    });
  });
}
