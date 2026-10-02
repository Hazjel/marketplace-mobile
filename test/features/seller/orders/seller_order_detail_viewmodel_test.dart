import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
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
}
