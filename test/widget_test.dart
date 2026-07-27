import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:blukios_marketplace/app.dart';

void main() {
  testWidgets('BlukiosApp builds without throwing', (WidgetTester tester) async {
    // AuthViewModel.checkAuthStatus() and HomeViewModel.loadData() fire real
    // Dio calls on startup with no server present in the test environment;
    // runAsync lets those requests actually fail (connection refused) instead
    // of leaving a pending timer behind at teardown.
    await tester.runAsync(() async {
      await tester.pumpWidget(const BlukiosApp());
      await tester.pump();
    });

    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
