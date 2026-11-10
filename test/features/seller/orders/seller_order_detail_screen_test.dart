import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:blukios_marketplace/core/providers.dart';
import 'package:blukios_marketplace/features/seller/orders/screens/seller_order_detail_screen.dart';
import 'package:blukios_marketplace/features/transaction/data/transaction_repository.dart';
import 'package:blukios_marketplace/features/transaction/models/transaction_model.dart';

class MockTransactionRepository extends Mock implements TransactionRepository {}

TransactionModel _order(String complaintStatus, {String? sellerResponse}) => TransactionModel(
      id: 'o1',
      code: 'TRX-o1',
      shippingCost: 5000,
      deliveryStatus: 'delivering',
      tax: 0,
      grandTotal: 26000,
      paymentStatus: 'paid',
      transactionDetails: const [],
      complaint: TransactionComplaint(
        id: 'c1',
        status: complaintStatus,
        reason: 'damaged',
        description: 'Kemasan penyok parah',
        sellerResponse: sellerResponse,
        deadlineAt: '2099-01-01T00:00:00.000000Z',
      ),
    );

TransactionModel _unshipped({String deliveryStatus = 'processing', String? tracking, String? deadline}) =>
    TransactionModel(
      id: 'o1',
      code: 'TRX-o1',
      shippingCost: 5000,
      deliveryStatus: deliveryStatus,
      trackingNumber: tracking,
      tax: 0,
      grandTotal: 26000,
      paymentStatus: 'paid',
      shipDeadlineAt: deadline,
      transactionDetails: const [],
    );

const _resiHint = 'Isi nomor resi dulu untuk menandai pesanan dikirim.';

void main() {
  late MockTransactionRepository repository;

  setUp(() => repository = MockTransactionRepository());

  Future<void> pumpDetail(WidgetTester tester, TransactionModel order) async {
    when(() => repository.getTransactionDetail('o1')).thenAnswer((_) async => order);
    final router = GoRouter(
      initialLocation: '/o1',
      routes: [
        GoRoute(path: '/o1', builder: (_, __) => const SellerOrderDetailScreen(orderId: 'o1')),
      ],
    );
    await tester.pumpWidget(ProviderScope(
      overrides: [transactionRepositoryProvider.overrideWithValue(repository)],
      child: MaterialApp.router(routerConfig: router),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('an open complaint shows details, deadline and both actions', (tester) async {
    await pumpDetail(tester, _order('open'));

    expect(find.text('Komplain Pembeli'), findsOneWidget);
    expect(find.text('Menunggu tanggapan penjual'), findsOneWidget);
    expect(find.text('Barang rusak'), findsOneWidget);
    expect(find.textContaining('Batas tanggapan penjual:'), findsOneWidget);
    expect(find.text('Setujui & Refund'), findsOneWidget);
    expect(find.text('Tolak'), findsOneWidget);
  });

  testWidgets('an escalated complaint has no seller actions', (tester) async {
    await pumpDetail(tester, _order('escalated', sellerResponse: 'Barang sudah sesuai foto'));

    expect(find.text('Ditinjau admin'), findsOneWidget);
    expect(find.text('Barang sudah sesuai foto'), findsOneWidget);
    expect(find.text('Setujui & Refund'), findsNothing);
    expect(find.text('Tolak'), findsNothing);
  });

  testWidgets('accepting confirms the full refund first, then calls accept', (tester) async {
    when(() => repository.acceptComplaint('c1')).thenAnswer((_) async => _order('approved'));
    await pumpDetail(tester, _order('open'));

    await tester.ensureVisible(find.text('Setujui & Refund'));
    await tester.tap(find.text('Setujui & Refund'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Seluruh dana pesanan (Rp 26.000)'), findsOneWidget);
    expect(find.textContaining('stok produk TIDAK dikembalikan'), findsOneWidget);

    await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Setujui & Refund')));
    await tester.pumpAndSettle();

    verify(() => repository.acceptComplaint('c1')).called(1);
    expect(find.text('Disetujui – dana dikembalikan'), findsOneWidget);
    expect(find.text('Setujui & Refund'), findsNothing);
  });

  testWidgets('rejecting needs a response before calling reject', (tester) async {
    when(() => repository.rejectComplaint('c1', 'Barang sudah sesuai foto'))
        .thenAnswer((_) async => _order('escalated', sellerResponse: 'Barang sudah sesuai foto'));
    await pumpDetail(tester, _order('open'));

    await tester.ensureVisible(find.text('Tolak'));
    await tester.tap(find.text('Tolak'));
    await tester.pumpAndSettle();
    final submit = find.descendant(of: find.byType(AlertDialog), matching: find.text('Tolak'));
    expect(tester.widget<TextButton>(find.ancestor(of: submit, matching: find.byType(TextButton))).onPressed,
        isNull);

    await tester.enterText(find.byType(TextField).last, 'Barang sudah sesuai foto');
    await tester.pump();
    await tester.tap(submit);
    await tester.pumpAndSettle();

    verify(() => repository.rejectComplaint('c1', 'Barang sudah sesuai foto')).called(1);
    expect(find.text('Ditinjau admin'), findsOneWidget);
  });

  group('ship action', () {
    VoidCallback? shipPressed(WidgetTester tester) => tester
        .widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Tandai Dikirim'))
        .onPressed;

    testWidgets('is disabled while the resi is empty and enabled once one is typed', (tester) async {
      await pumpDetail(tester, _unshipped());

      expect(shipPressed(tester), isNull);
      expect(find.text(_resiHint), findsOneWidget);

      await tester.enterText(find.byType(TextField).first, 'JNE123');
      await tester.pump();
      expect(shipPressed(tester), isNotNull);
      expect(find.text(_resiHint), findsNothing);

      await tester.enterText(find.byType(TextField).first, '   ');
      await tester.pump();
      expect(shipPressed(tester), isNull);
    });

    testWidgets('is enabled right away when the order already has a resi', (tester) async {
      await pumpDetail(tester, _unshipped(tracking: 'JNE123'));
      expect(shipPressed(tester), isNotNull);
    });

    testWidgets('an order already delivering shows no resi hint and keeps the field editable', (tester) async {
      await pumpDetail(tester, _unshipped(deliveryStatus: 'delivering', tracking: 'JNE123'));
      expect(find.text(_resiHint), findsNothing);
      expect(tester.widget<TextField>(find.byType(TextField).first).enabled, isNot(false));
    });
  });

  group('ship deadline', () {
    testWidgets('shows "Kirim sebelum" with the remaining time for a paid, unshipped order', (tester) async {
      final deadline = DateTime.now().toUtc().add(const Duration(hours: 5, minutes: 30)).toIso8601String();
      await pumpDetail(tester, _unshipped(deadline: deadline));

      expect(find.textContaining('Kirim sebelum '), findsOneWidget);
      expect(find.textContaining('Sisa 5 jam.'), findsOneWidget);
    });

    testWidgets('is hidden once the order is delivering', (tester) async {
      final deadline = DateTime.now().toUtc().add(const Duration(days: 2)).toIso8601String();
      await pumpDetail(tester, _unshipped(deliveryStatus: 'delivering', tracking: 'X1', deadline: deadline));

      expect(find.textContaining('Kirim sebelum '), findsNothing);
    });
  });
}
