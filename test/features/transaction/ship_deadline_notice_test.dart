import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:blukios_marketplace/config/app_theme.dart';
import 'package:blukios_marketplace/features/transaction/models/transaction_model.dart';
import 'package:blukios_marketplace/features/transaction/widgets/ship_deadline_notice.dart';

void main() {
  final start = DateTime.utc(2026, 11, 2, 9);
  // 24 h 30 min away: "Sisa 1 hari 0 jam." and not urgent yet.
  final order = TransactionModel(
    id: 't1',
    code: 'TRX-1',
    shippingCost: 0,
    deliveryStatus: 'processing',
    tax: 0,
    grandTotal: 1000,
    paymentStatus: 'paid',
    shipDeadlineAt: start.add(const Duration(hours: 24, minutes: 30)).toIso8601String(),
    transactionDetails: const [],
  );

  Color? remainingColor(WidgetTester tester, String text) =>
      tester.widget<Text>(find.textContaining(text)).style?.color;

  testWidgets('refreshes every minute: remaining text and urgent state follow the clock', (tester) async {
    var now = start;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: ShipDeadlineNotice(order: order, now: () => now)),
    ));

    expect(find.textContaining('Sisa 1 hari 0 jam.'), findsOneWidget);
    expect(remainingColor(tester, 'Sisa 1 hari 0 jam.'), isNot(AppTheme.error));

    // One minute later the clock has passed the 30-minute margin: under 24 h.
    now = start.add(const Duration(minutes: 31));
    await tester.pump(const Duration(minutes: 1));

    expect(find.textContaining('Sisa 1 hari'), findsNothing);
    expect(find.textContaining('Sisa 23 jam.'), findsOneWidget);
    expect(remainingColor(tester, 'Sisa 23 jam.'), AppTheme.error);
  });

  testWidgets('does not move before the minute is up', (tester) async {
    var now = start;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: ShipDeadlineNotice(order: order, now: () => now)),
    ));

    now = start.add(const Duration(minutes: 31));
    await tester.pump(const Duration(seconds: 59));

    expect(find.textContaining('Sisa 1 hari 0 jam.'), findsOneWidget);
  });

  // flutter_test fails a test that ends with a Timer still pending, so
  // removing the widget and finishing is the proof the ticker was cancelled.
  testWidgets('leaves no timer pending once removed', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: ShipDeadlineNotice(order: order, now: () => start)),
    ));
    expect(tester.binding.transientCallbackCount, 0);

    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: SizedBox())));
    await tester.pump(const Duration(minutes: 5));

    expect(find.byType(ShipDeadlineNotice), findsNothing);
  });
}
