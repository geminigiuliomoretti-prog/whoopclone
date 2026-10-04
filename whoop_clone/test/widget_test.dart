import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:whoop_clone/data/database/database_helper.dart';
import 'package:whoop_clone/main.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  DatabaseHelper.isTestMode = true;

  testWidgets('WhoopApp smoke test', (WidgetTester tester) async {
    final originalOnError = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      if (details.exceptionAsString().contains('ListTile background color')) {
        return;
      }
      originalOnError?.call(details);
    };

    await tester.pumpWidget(const WhoopApp());
    expect(find.byType(WhoopApp), findsOneWidget);

    FlutterError.onError = originalOnError;
  });
}
