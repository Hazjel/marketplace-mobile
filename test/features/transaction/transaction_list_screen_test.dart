import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:blukios_marketplace/core/network/api_exceptions.dart';
import 'package:blukios_marketplace/core/providers.dart';
import 'package:blukios_marketplace/features/auth/models/user_model.dart';
import 'package:blukios_marketplace/features/auth/viewmodels/auth_viewmodel.dart';
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

class _FakeAuth extends AuthNotifier {
  final String? userId;

  _FakeAuth(this.userId);

  @override
  AuthData build() => AuthData(
        currentUser: userId == null
            ? null
            : UserModel(id: userId!, name: 'U', email: 'u@x.id', role: 'buyer'),
      );
}

TransactionModel _order(
  String id, {
  String paymentStatus = 'unpaid',
  String deliveryStatus = 'pending',
  String buyerUserId = 'buyer-1',
  String store = 'Toko Satu',
  double total = 26000,
}) {
  return TransactionModel(
    id: id,
    code: 'TRX-$id',
    storeName: store,
    buyerUserId: buyerUserId,
    shippingCost: 5000,
    deliveryStatus: deliveryStatus,
    tax: 0,
    grandTotal: total,
    paymentStatus: paymentStatus,
    transactionDetails: const [],
  );
}

void main() {
  late MockTransactionRepository repository;

  setUp(() => repository = MockTransactionRepository());

  Future<void> pumpList(
    WidgetTester tester,
    List<TransactionModel> transactions, {
    String? userId = 'buyer-1',
  }) async {
    when(() => repository.getTransactions(mode: 'buyer')).thenAnswer((_) async => transactions);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          transactionRepositoryProvider.overrideWithValue(repository),
          authProvider.overrideWith(() => _FakeAuth(userId)),
        ],
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

  testWidgets('a paid order not shipped yet tells the buyer the deadline and the auto-refund', (tester) async {
    final deadline = DateTime.now().toUtc().add(const Duration(days: 2, hours: 3)).toIso8601String();
    await pumpList(tester, [
      TransactionModel(
        id: 't2',
        code: 'TRX-t2',
        shippingCost: 5000,
        deliveryStatus: 'processing',
        tax: 0,
        grandTotal: 26000,
        paymentStatus: 'paid',
        shipDeadlineAt: deadline,
        transactionDetails: const [],
      ),
    ]);

    expect(find.textContaining('Penjual wajib mengirim sebelum '), findsOneWidget);
    expect(find.textContaining('Jika belum dikirim, pesanan dibatalkan dan dana dikembalikan otomatis.'),
        findsOneWidget);
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

  testWidgets('an order paid partly with saldo shows how much', (tester) async {
    await pumpList(tester, [
      TransactionModel(
        id: 't4',
        code: 'TRX-t4',
        shippingCost: 0,
        deliveryStatus: 'pending',
        tax: 0,
        grandTotal: 50000,
        balanceUsed: 20000,
        paymentStatus: 'paid',
        transactionDetails: const [],
      ),
      _cancelled(refundStatus: 'refunded'),
    ]);

    expect(find.text('Dibayar dengan Saldo Blukios: Rp 20.000'), findsOneWidget);
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

  group('complaint entry', () {
    testWidgets('a paid, delivering order without a complaint offers "Ajukan Komplain"',
        (tester) async {
      await pumpList(tester, [delivering()]);

      expect(find.text('Ajukan Komplain'), findsOneWidget);
      expect(find.text('Lihat Komplain'), findsNothing);
    });

    testWidgets('an order with a complaint offers "Lihat Komplain" with its status',
        (tester) async {
      await pumpList(tester, [
        delivering(complaint: const TransactionComplaint(id: 'c1', status: 'open')),
      ]);

      expect(find.text('Lihat Komplain'), findsOneWidget);
      expect(find.text('Menunggu tanggapan penjual'), findsOneWidget);
      expect(find.text('Ajukan Komplain'), findsNothing);
    });

    testWidgets('a withdrawn complaint cannot be filed again', (tester) async {
      await pumpList(tester, [
        delivering(complaint: const TransactionComplaint(id: 'c1', status: 'withdrawn')),
      ]);

      expect(find.text('Lihat Komplain'), findsOneWidget);
      expect(find.text('Ajukan Komplain'), findsNothing);
    });

    testWidgets('orders not on their way offer neither', (tester) async {
      await pumpList(tester, [
        TransactionModel(
          id: 't5',
          code: 'TRX-t5',
          shippingCost: 0,
          deliveryStatus: 'processing',
          tax: 0,
          grandTotal: 50000,
          paymentStatus: 'paid',
          transactionDetails: const [],
        ),
        _cancelled(),
      ]);

      expect(find.text('Ajukan Komplain'), findsNothing);
      expect(find.text('Lihat Komplain'), findsNothing);
    });
  });

  group('cancel an unpaid order', () {
    testWidgets('lists every order of the payment, cancels once and refreshes the list', (tester) async {
      final orders = [
        _order('t1', store: 'Toko Satu', total: 26000),
        _order('t2', store: 'Toko Dua', total: 41000),
      ];
      when(() => repository.previewCancelUnpaid('t1')).thenAnswer((_) async => orders);
      when(() => repository.cancelUnpaid('t1')).thenAnswer((_) async => const CancelUnpaidResult(
            message: 'Pesanan dibatalkan. Saldo Blukios yang digunakan sudah dikembalikan.',
            orders: [],
          ));
      await pumpList(tester, [orders.first]);
      clearInteractions(repository);
      when(() => repository.getTransactions(mode: 'buyer')).thenAnswer((_) async => []);

      await tester.tap(find.text('Batalkan Pesanan'));
      await tester.pumpAndSettle();

      expect(find.text('Batalkan pesanan dalam pembayaran ini?'), findsOneWidget);
      expect(find.text('TRX-t1 - Toko Satu\nRp 26.000'), findsOneWidget);
      expect(find.text('TRX-t2 - Toko Dua\nRp 41.000'), findsOneWidget);
      expect(find.textContaining('Semua pesanan di atas dibatalkan.'), findsOneWidget);
      verifyNever(() => repository.cancelUnpaid(any()));

      await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Batalkan Pesanan')));
      await tester.pumpAndSettle();

      verify(() => repository.cancelUnpaid('t1')).called(1);
      verify(() => repository.getTransactions(mode: 'buyer')).called(1);
      expect(find.text('Pesanan dibatalkan. Saldo Blukios yang digunakan sudah dikembalikan.'), findsOneWidget);
      expect(find.text('Batalkan Pesanan'), findsNothing);
    });

    testWidgets('going back from the confirmation cancels nothing', (tester) async {
      when(() => repository.previewCancelUnpaid('t1')).thenAnswer((_) async => [_order('t1')]);
      await pumpList(tester, [_order('t1')]);

      await tester.tap(find.text('Batalkan Pesanan'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kembali'));
      await tester.pumpAndSettle();

      verifyNever(() => repository.cancelUnpaid(any()));
      expect(find.text('Batalkan Pesanan'), findsOneWidget);
    });

    testWidgets('a failed preview shows the API message and opens no confirmation', (tester) async {
      when(() => repository.previewCancelUnpaid('t1')).thenThrow(
        ApiException(message: 'Anda tidak memiliki izin untuk membatalkan pesanan ini', statusCode: 403),
      );
      await pumpList(tester, [_order('t1')]);

      await tester.tap(find.text('Batalkan Pesanan'));
      await tester.pumpAndSettle();

      expect(find.text('Anda tidak memiliki izin untuk membatalkan pesanan ini'), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
      verifyNever(() => repository.cancelUnpaid(any()));
    });

    testWidgets('a failed cancel shows the API message as returned', (tester) async {
      when(() => repository.previewCancelUnpaid('t1')).thenAnswer((_) async => [_order('t1')]);
      when(() => repository.cancelUnpaid('t1'))
          .thenThrow(ApiException(message: 'Too Many Attempts.', statusCode: 429));
      await pumpList(tester, [_order('t1')]);

      await tester.tap(find.text('Batalkan Pesanan'));
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Batalkan Pesanan')));
      await tester.pumpAndSettle();

      expect(find.text('Too Many Attempts.'), findsOneWidget);
    });

    // What ApiClient throws when there is no HTTP response at all.
    ApiException offline() => ApiException.fromDioError(
          DioException(requestOptions: RequestOptions(), type: DioExceptionType.connectionError),
        );

    testWidgets('no connection while loading the preview shows the message and changes nothing', (tester) async {
      when(() => repository.previewCancelUnpaid('t1')).thenThrow(offline());
      await pumpList(tester, [_order('t1')]);
      clearInteractions(repository);

      await tester.tap(find.text('Batalkan Pesanan'));
      await tester.pumpAndSettle();

      expect(find.text('Tidak ada koneksi internet'), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('Batalkan Pesanan'), findsOneWidget);
      expect(find.text('TRX-t1'), findsOneWidget);
      verifyNever(() => repository.cancelUnpaid(any()));
      verifyNever(() => repository.getTransactions(mode: any(named: 'mode')));
    });

    testWidgets('no connection while cancelling shows the message, re-enables the action and does not retry', (tester) async {
      when(() => repository.previewCancelUnpaid('t1')).thenAnswer((_) async => [_order('t1')]);
      when(() => repository.cancelUnpaid('t1')).thenThrow(offline());
      await pumpList(tester, [_order('t1')]);
      clearInteractions(repository);

      await tester.tap(find.text('Batalkan Pesanan'));
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Batalkan Pesanan')));
      await tester.pumpAndSettle();

      expect(find.text('Tidak ada koneksi internet'), findsOneWidget);
      expect(find.text('TRX-t1'), findsOneWidget);
      final action = find.widgetWithText(OutlinedButton, 'Batalkan Pesanan');
      expect(tester.widget<OutlinedButton>(action).onPressed, isNotNull);
      verify(() => repository.cancelUnpaid('t1')).called(1);
      verifyNever(() => repository.getTransactions(mode: any(named: 'mode')));
    });

    testWidgets('repeated taps on the action and on confirm send the cancellation once', (tester) async {
      final preview = Completer<List<TransactionModel>>();
      final cancel = Completer<CancelUnpaidResult>();
      when(() => repository.previewCancelUnpaid('t1')).thenAnswer((_) => preview.future);
      when(() => repository.cancelUnpaid('t1')).thenAnswer((_) => cancel.future);
      await pumpList(tester, [_order('t1')]);

      // Action tapped again while the preview is still loading.
      await tester.tap(find.text('Batalkan Pesanan'));
      await tester.pump();
      await tester.tap(find.text('Memproses pembatalan...'), warnIfMissed: false);
      await tester.pump();
      verify(() => repository.previewCancelUnpaid('t1')).called(1);

      preview.complete([_order('t1')]);
      await tester.pumpAndSettle();

      // Confirm tapped twice, a frame apart, while the cancellation is in flight.
      final confirm = find.descendant(of: find.byType(AlertDialog), matching: find.text('Batalkan Pesanan'));
      await tester.tap(confirm);
      await tester.pump();
      await tester.tap(confirm, warnIfMissed: false);
      await tester.pump();
      await tester.tap(find.text('Memproses pembatalan...'), warnIfMissed: false);
      await tester.pump();

      cancel.complete(const CancelUnpaidResult(message: 'Pesanan dibatalkan.', orders: []));
      await tester.pumpAndSettle();

      verify(() => repository.cancelUnpaid('t1')).called(1);
      verifyNever(() => repository.previewCancelUnpaid('t1')); // no preview beyond the one verified above
      expect(find.text('Pesanan dibatalkan.'), findsOneWidget);
    });

    testWidgets('the action is offered for a pending order too', (tester) async {
      await pumpList(tester, [_order('t1', paymentStatus: 'pending')]);

      expect(find.text('Batalkan Pesanan'), findsOneWidget);
    });

    for (final (name, order, userId) in <(String, TransactionModel, String?)>[
      ('paid', _order('t1', paymentStatus: 'paid', deliveryStatus: 'processing'), 'buyer-1'),
      ('cancelled', _order('t1', paymentStatus: 'failed', deliveryStatus: 'cancelled'), 'buyer-1'),
      ('expired', _order('t1', paymentStatus: 'expired'), 'buyer-1'),
      ('placed by someone else', _order('t1', buyerUserId: 'buyer-2'), 'buyer-1'),
      ('not signed in', _order('t1'), null),
    ]) {
      testWidgets('no action on an order that is $name', (tester) async {
        await pumpList(tester, [order], userId: userId);

        expect(find.text('Batalkan Pesanan'), findsNothing);
      });
    }
  });
}
