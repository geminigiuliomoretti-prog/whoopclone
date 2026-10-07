import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:whoop_clone/core/logging/structured_logger.dart';
import 'package:whoop_clone/data/ble/ble_diagnostic_service.dart';
import 'package:whoop_clone/data/database/database_helper.dart';
import 'package:whoop_clone/main.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    DatabaseHelper.isTestMode = true;
    StructuredLogger.enableFileFlushTimer = false;
    BleDiagnosticService.enableGapMonitorTimer = false;
  });

  testWidgets('Capture screen rendering for visual audit - 0 overflows', (tester) async {
    final originalOnError = FlutterError.onError;
    int overflowCount = 0;
    FlutterError.onError = (FlutterErrorDetails details) {
      if (details.exceptionAsString().contains('A RenderFlex overflowed')) {
        overflowCount++;
      }
      originalOnError?.call(details);
    };

    await tester.pumpWidget(const WhoopApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(WhoopApp), findsOneWidget);
    expect(overflowCount, 0, reason: 'Must have 0 RenderFlex overflow exceptions');

    FlutterError.onError = originalOnError;
  });
}
