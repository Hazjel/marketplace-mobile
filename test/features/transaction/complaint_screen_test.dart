import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:blukios_marketplace/core/providers.dart';
import 'package:blukios_marketplace/features/transaction/data/transaction_repository.dart';
import 'package:blukios_marketplace/features/transaction/models/transaction_model.dart';
import 'package:blukios_marketplace/features/transaction/screens/complaint_screen.dart';
import 'package:blukios_marketplace/features/transaction/viewmodels/transaction_viewmodel.dart';

class MockTransactionRepository extends Mock implements TransactionRepository {}

TransactionModel _order(String status) => TransactionModel(
      id: 't1',
      code: 'TRX-t1',
      shippingCost: 0,
      deliveryStatus: 'delivering',
      tax: 0,
      grandTotal: 26000,
      paymentStatus: 'paid',
      transactionDetails: const [],
      complaint: TransactionComplaint(
        id: 'c1',
        status: status,
        reason: 'not_received',
        description: 'Paket belum sampai sudah seminggu',
      ),
    );

void main() {
  late MockTransactionRepository repository;

  setUp(() => repository = MockTransactionRepository());

  Future<void> pumpScreen(WidgetTester tester, String status) async {
    when(() => repository.getTransactions()).thenAnswer((_) async => [_order(status)]);
    final container = ProviderContainer(
      overrides: [transactionRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
    await container.read(transactionProvider.notifier).loadTransactions();

    final router = GoRouter(
      initialLocation: '/c',
      routes: [GoRoute(path: '/c', builder: (_, __) => const ComplaintScreen(transactionId: 't1'))],
    );
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(routerConfig: router),
    ));
    await tester.pumpAndSettle();
  }

  Finder dialogButton(String label) =>
      find.descendant(of: find.byType(AlertDialog), matching: find.text(label));

  testWidgets('confirming withdraws the complaint', (tester) async {
    when(() => repository.withdrawComplaint('c1')).thenAnswer((_) async => _order('withdrawn'));
    await pumpScreen(tester, 'open');

    expect(find.text('Barang tidak sampai'), findsOneWidget);
    await tester.tap(find.text('Tarik Komplain'));
    await tester.pumpAndSettle();
    await tester.tap(dialogButton('Tarik Komplain'));
    await tester.pumpAndSettle();

    verify(() => repository.withdrawComplaint('c1')).called(1);
    expect(find.text('Ditarik'), findsOneWidget);
    expect(find.text('Tarik Komplain'), findsNothing);
  });

  testWidgets('cancelling the dialog does not withdraw', (tester) async {
    await pumpScreen(tester, 'escalated');

    await tester.tap(find.text('Tarik Komplain'));
    await tester.pumpAndSettle();
    await tester.tap(dialogButton('Batal'));
    await tester.pumpAndSettle();

    verifyNever(() => repository.withdrawComplaint(any()));
    expect(find.text('Tarik Komplain'), findsOneWidget);
  });

  for (final status in ['approved', 'rejected', 'withdrawn']) {
    testWidgets('no withdraw button once $status', (tester) async {
      await pumpScreen(tester, status);

      expect(find.text(TransactionComplaint.statuses[status]!), findsOneWidget);
      expect(find.text('Tarik Komplain'), findsNothing);
    });
  }
}
