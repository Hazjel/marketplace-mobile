import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:blukios_marketplace/core/providers.dart';
import 'package:blukios_marketplace/features/transaction/data/transaction_repository.dart';
import 'package:blukios_marketplace/features/transaction/models/transaction_model.dart';
import 'package:blukios_marketplace/features/transaction/screens/transaction_list_screen.dart';

class MockTransactionRepository extends Mock implements TransactionRepository {}

TransactionModel _cancelled({String refundStatus = 'manual_required', RefundAccount? account}) {
  return TransactionModel(
    id: 't1',
    code: 'TRX-t1',
    storeName: 'Toko Uji',
    shippingCost: 5000,
    deliveryStatus: 'cancelled',
    tax: 0,
    serviceFee: 1000,
    grandTotal: 26000,
    paymentStatus: 'failed',
    transactionDetails: const [],
    refundStatus: refundStatus,
    refundAmount: 26000,
    refundReason: 'Stok habis',
    refundAccount: account,
  );
}

void main() {
  late MockTransactionRepository repository;

  setUp(() => repository = MockTransactionRepository());

  Future<void> pumpList(WidgetTester tester, List<TransactionModel> transactions) async {
    when(() => repository.getTransactions()).thenAnswer((_) async => transactions);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [transactionRepositoryProvider.overrideWithValue(repository)],
        child: const MaterialApp(home: TransactionListScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('an order cancelled after payment shows the refund, not "Gagal"', (tester) async {
    await pumpList(tester, [_cancelled()]);

    expect(find.text('Menunggu Refund'), findsOneWidget);
    expect(find.text('Gagal'), findsNothing);
    expect(find.text('Alasan penjual: Stok habis'), findsOneWidget);
    expect(find.text('Isi Rekening Refund'), findsOneWidget);
  });

  testWidgets('the account form rejects a non-numeric account number', (tester) async {
    await pumpList(tester, [_cancelled()]);

    await tester.tap(find.text('Isi Rekening Refund'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Nama Bank'), 'BCA');
    await tester.enterText(find.widgetWithText(TextFormField, 'Nomor Rekening'), '12-34');
    await tester.enterText(find.widgetWithText(TextFormField, 'Nama Pemilik Rekening'), 'Budi');
    await tester.tap(find.text('Simpan Rekening'));
    await tester.pumpAndSettle();

    expect(find.text('Hanya angka, 5-30 digit'), findsOneWidget);
    verifyNever(() => repository.submitRefundAccount(
          id: any(named: 'id'),
          bankName: any(named: 'bankName'),
          accountNumber: any(named: 'accountNumber'),
          accountName: any(named: 'accountName'),
        ));
  });

  testWidgets('a finished refund offers no account form', (tester) async {
    await pumpList(tester, [_cancelled(refundStatus: 'refunded')]);

    expect(find.text('Dana Dikembalikan'), findsOneWidget);
    expect(find.text('Isi Rekening Refund'), findsNothing);
    expect(find.text('Ubah Rekening'), findsNothing);
  });

  testWidgets('a saldo refund says so, not the e-wallet wait', (tester) async {
    final trx = TransactionModel(
      id: 't2',
      code: 'TRX-t2',
      shippingCost: 0,
      deliveryStatus: 'cancelled',
      tax: 0,
      grandTotal: 50000,
      paymentStatus: 'failed',
      transactionDetails: const [],
      refundStatus: 'refunded',
      refundMethod: 'balance',
      refundAmount: 30000,
      balanceUsed: 20000,
      refundNote: 'catatan internal admin',
    );
    await pumpList(tester, [trx]);

    expect(find.text('Rp 50.000 sudah masuk ke Saldo Blukios dan bisa dipakai untuk belanja.'),
        findsOneWidget);
    expect(find.textContaining('e-wallet'), findsNothing);
    expect(find.textContaining('catatan internal'), findsNothing);
  });

  TransactionModel delivering({TransactionComplaint? complaint}) => TransactionModel(
        id: 't3',
        code: 'TRX-t3',
        shippingCost: 0,
        deliveryStatus: 'delivering',
        tax: 0,
        grandTotal: 50000,
        paymentStatus: 'paid',
        transactionDetails: const [],
        complaint: complaint,
      );

  testWidgets('an active complaint hides "Konfirmasi Pesanan Diterima"', (tester) async {
    await pumpList(tester, [delivering(complaint: const TransactionComplaint(id: 'c1', status: 'open'))]);

    expect(find.text('Konfirmasi Pesanan Diterima'), findsNothing);
    expect(find.text('Komplain sedang diproses — pesanan belum bisa diselesaikan'), findsOneWidget);
  });

  testWidgets('without an active complaint the order can be confirmed', (tester) async {
    await pumpList(tester, [delivering(complaint: const TransactionComplaint(id: 'c1', status: 'rejected'))]);

    expect(find.text('Konfirmasi Pesanan Diterima'), findsOneWidget);
    expect(find.textContaining('Komplain sedang diproses'), findsNothing);
  });
}
