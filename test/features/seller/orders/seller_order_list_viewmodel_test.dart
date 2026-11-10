import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:blukios_marketplace/core/providers.dart';
import 'package:blukios_marketplace/features/seller/orders/viewmodels/seller_order_list_viewmodel.dart';
import 'package:blukios_marketplace/features/transaction/data/transaction_repository.dart';

class MockTransactionRepository extends Mock implements TransactionRepository {}

void main() {
  test('the seller list asks for the store\'s orders (mode=store)', () async {
    final repository = MockTransactionRepository();
    when(() => repository.getTransactions(mode: 'store', rowPerPage: 50)).thenAnswer((_) async => []);
    final container = ProviderContainer(
      overrides: [transactionRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);

    await container.read(sellerOrderListProvider.notifier).loadOrders();

    verify(() => repository.getTransactions(mode: 'store', rowPerPage: 50)).called(1);
    verifyNever(() => repository.getTransactions(mode: 'buyer'));
  });
}
