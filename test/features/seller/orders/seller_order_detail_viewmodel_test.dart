import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:blukios_marketplace/core/network/api_exceptions.dart';
import 'package:blukios_marketplace/core/providers.dart';
import 'package:blukios_marketplace/features/seller/orders/viewmodels/seller_order_detail_viewmodel.dart';
import 'package:blukios_marketplace/features/transaction/data/transaction_repository.dart';
import 'package:blukios_marketplace/features/transaction/models/transaction_model.dart';

class MockTransactionRepository extends Mock implements TransactionRepository {}

TransactionModel _order({
  String deliveryStatus = 'pending',
  String paymentStatus = 'paid',
  String? refundStatus,
}) {
  return TransactionModel(
    id: 'o1',
    code: 'TRX-o1',
    shippingCost: 5000,
    deliveryStatus: deliveryStatus,
    tax: 0,
    serviceFee: 1000,
    grandTotal: 26000,
    paymentStatus: paymentStatus,
    transactionDetails: const [],
    refundStatus: refundStatus,
  );
}

void main() {
  late MockTransactionRepository repository;
  late ProviderContainer container;

  setUp(() async {
    repository = MockTransactionRepository();
    container = ProviderContainer(
      overrides: [transactionRepositoryProvider.overrideWithValue(repository)],
    );
    // Keep the auto-dispose family alive for the whole test.
    container.listen(sellerOrderDetailProvider('o1'), (_, __) {});

    when(() => repository.getTransactionDetail('o1')).thenAnswer((_) async => _order());
    await container.read(sellerOrderDetailProvider('o1').notifier).load();
  });

  tearDown(() => container.dispose());

  group('cancel', () {
    test('replaces the order with the cancelled one from the server', () async {
      when(() => repository.cancelOrder(id: 'o1', reason: 'Stok habis'))
          .thenAnswer((_) async => _order(
                deliveryStatus: 'cancelled',
                paymentStatus: 'failed',
                refundStatus: 'processing',
              ));

      final success = await container
          .read(sellerOrderDetailProvider('o1').notifier)
          .cancel(reason: 'Stok habis');

      final state = container.read(sellerOrderDetailProvider('o1'));
      expect(success, isTrue);
      expect(state.isUpdating, isFalse);
      expect(state.order?.deliveryStatus, 'cancelled');
      expect(state.order?.refundStatusLabel, 'Refund Diproses');
    });

    test('failure keeps the order and exposes the API message', () async {
      when(() => repository.cancelOrder(id: 'o1', reason: 'Stok habis'))
          .thenThrow(Exception('Pesanan yang sudah dikirim tidak bisa dibatalkan'));

      final success = await container
          .read(sellerOrderDetailProvider('o1').notifier)
          .cancel(reason: 'Stok habis');

      final state = container.read(sellerOrderDetailProvider('o1'));
      expect(success, isFalse);
      expect(state.order?.deliveryStatus, 'pending');
      expect(state.updateError, contains('tidak bisa dibatalkan'));
    });
  });

  group('complaints', () {
    SellerOrderDetailNotifier notifier() => container.read(sellerOrderDetailProvider('o1').notifier);

    test('acceptComplaint calls accept with the complaint id', () async {
      when(() => repository.acceptComplaint('c1')).thenAnswer((_) async => _order(
            deliveryStatus: 'cancelled',
            paymentStatus: 'failed',
            refundStatus: 'processing',
          ));

      expect(await notifier().acceptComplaint('c1'), isTrue);
      verify(() => repository.acceptComplaint('c1')).called(1);
      expect(container.read(sellerOrderDetailProvider('o1')).order?.deliveryStatus, 'cancelled');
    });

    test('rejectComplaint sends the response to reject', () async {
      when(() => repository.rejectComplaint('c1', 'Barang sudah sesuai foto'))
          .thenAnswer((_) async => _order(deliveryStatus: 'delivering'));

      expect(await notifier().rejectComplaint('c1', 'Barang sudah sesuai foto'), isTrue);
      verify(() => repository.rejectComplaint('c1', 'Barang sudah sesuai foto')).called(1);
      verifyNever(() => repository.acceptComplaint(any()));
    });

    test('a rejected response shows the field message, not the summary', () async {
      when(() => repository.rejectComplaint('c1', 'ok')).thenThrow(ValidationException.fromBody(const {
        'message': 'Tanggapan minimal 5 karakter.',
        'errors': {
          'response': ['Tanggapan minimal 5 karakter.'],
        },
      }));
      when(() => repository.getTransactionDetail('o1')).thenAnswer((_) async => _order());

      expect(await notifier().rejectComplaint('c1', 'ok'), isFalse);
      expect(container.read(sellerOrderDetailProvider('o1')).updateError,
          'Tanggapan minimal 5 karakter.');
    });

    test('failure keeps the server message and re-reads the order', () async {
      // What ApiClient throws for the API's domain 422 body.
      when(() => repository.acceptComplaint('c1')).thenThrow(ValidationException.fromBody(const {
        'success': false,
        'message': 'Status komplain sudah berubah',
        'data': null,
      }));
      when(() => repository.getTransactionDetail('o1'))
          .thenAnswer((_) async => _order(deliveryStatus: 'delivering'));

      expect(await notifier().acceptComplaint('c1'), isFalse);
      final state = container.read(sellerOrderDetailProvider('o1'));
      expect(state.updateError, 'Status komplain sudah berubah');
      expect(state.order?.deliveryStatus, 'delivering');
      expect(state.isUpdating, isFalse);
    });
  });
}
