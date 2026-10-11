import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:blukios_marketplace/core/providers.dart';
import 'package:blukios_marketplace/features/transaction/data/transaction_repository.dart';
import 'package:blukios_marketplace/features/transaction/models/transaction_model.dart';
import 'package:blukios_marketplace/features/transaction/viewmodels/transaction_viewmodel.dart';

class MockTransactionRepository extends Mock implements TransactionRepository {}

TransactionModel _transaction({
  String id = 'trx-1',
  String paymentStatus = 'pending',
  String deliveryStatus = 'pending',
  Set<String> reviewedProductIds = const {},
}) {
  return TransactionModel(
    id: id,
    code: 'TRX-$id',
    shippingCost: 5000,
    deliveryStatus: deliveryStatus,
    tax: 2200,
    grandTotal: 27200,
    paymentStatus: paymentStatus,
    transactionDetails: const [],
    reviewedProductIds: reviewedProductIds,
  );
}

void main() {
  late MockTransactionRepository transactionRepository;
  late ProviderContainer container;

  setUp(() {
    transactionRepository = MockTransactionRepository();
    container = ProviderContainer(
      overrides: [transactionRepositoryProvider.overrideWithValue(transactionRepository)],
    );
  });

  tearDown(() => container.dispose());

  group('loadTransactions', () {
    test('populates the list on success', () async {
      final transactions = [_transaction(id: 't1'), _transaction(id: 't2')];
      when(() => transactionRepository.getTransactions()).thenAnswer((_) async => transactions);

      await container.read(transactionProvider.notifier).loadTransactions();

      final state = container.read(transactionProvider);
      expect(state.transactions, transactions);
      expect(state.isLoading, isFalse);
    });
  });

  group('refreshStatus', () {
    test('updates only the matching transaction in place', () async {
      final t1 = _transaction(id: 't1', paymentStatus: 'pending');
      final t2 = _transaction(id: 't2', paymentStatus: 'pending');
      when(() => transactionRepository.getTransactions()).thenAnswer((_) async => [t1, t2]);
      await container.read(transactionProvider.notifier).loadTransactions();

      final t1Updated = _transaction(id: 't1', paymentStatus: 'paid');
      when(() => transactionRepository.checkPaymentStatus('t1')).thenAnswer((_) async => t1Updated);

      final error = await container.read(transactionProvider.notifier).refreshStatus('t1');

      expect(error, isNull);
      final state = container.read(transactionProvider);
      expect(state.transactions.firstWhere((t) => t.id == 't1').paymentStatus, 'paid');
      // t2 untouched.
      expect(state.transactions.firstWhere((t) => t.id == 't2').paymentStatus, 'pending');
    });

    test('failure returns the error message and leaves state unchanged', () async {
      final t1 = _transaction(id: 't1');
      when(() => transactionRepository.getTransactions()).thenAnswer((_) async => [t1]);
      await container.read(transactionProvider.notifier).loadTransactions();
      when(() => transactionRepository.checkPaymentStatus('t1'))
          .thenThrow(Exception('Gagal cek status'));

      final error = await container.read(transactionProvider.notifier).refreshStatus('t1');

      expect(error, contains('Gagal cek status'));
      expect(container.read(transactionProvider).transactions.single.paymentStatus, 'pending');
    });
  });

  group('markReviewed', () {
    test('adds the product id to the matching transaction only', () async {
      final t1 = _transaction(id: 't1');
      final t2 = _transaction(id: 't2');
      when(() => transactionRepository.getTransactions()).thenAnswer((_) async => [t1, t2]);
      await container.read(transactionProvider.notifier).loadTransactions();

      container.read(transactionProvider.notifier).markReviewed('t1', 'prod-1');

      final state = container.read(transactionProvider);
      expect(state.transactions.firstWhere((t) => t.id == 't1').reviewedProductIds, {'prod-1'});
      expect(state.transactions.firstWhere((t) => t.id == 't2').reviewedProductIds, isEmpty);
    });
  });

  group('completeOrder', () {
    test('updates the transaction with the server response on success', () async {
      final t1 = _transaction(id: 't1', deliveryStatus: 'delivering');
      when(() => transactionRepository.getTransactions()).thenAnswer((_) async => [t1]);
      await container.read(transactionProvider.notifier).loadTransactions();

      final completed = _transaction(id: 't1', deliveryStatus: 'completed');
      when(() => transactionRepository.completeOrder(
            id: 't1',
            receivingProofPath: '/tmp/proof.jpg',
          )).thenAnswer((_) async => completed);

      final error =
          await container.read(transactionProvider.notifier).completeOrder('t1', '/tmp/proof.jpg');

      expect(error, isNull);
      expect(container.read(transactionProvider).transactions.single.deliveryStatus, 'completed');
    });

    test('failure returns the error message without changing state', () async {
      final t1 = _transaction(id: 't1', deliveryStatus: 'delivering');
      when(() => transactionRepository.getTransactions()).thenAnswer((_) async => [t1]);
      await container.read(transactionProvider.notifier).loadTransactions();

      when(() => transactionRepository.completeOrder(
            id: 't1',
            receivingProofPath: '/tmp/proof.jpg',
          )).thenThrow(Exception('Gagal mengonfirmasi pesanan'));

      final error =
          await container.read(transactionProvider.notifier).completeOrder('t1', '/tmp/proof.jpg');

      expect(error, contains('Gagal mengonfirmasi pesanan'));
      expect(container.read(transactionProvider).transactions.single.deliveryStatus, 'delivering');
    });
  });

  group('submitRefundAccount', () {
    TransactionModel cancelled({RefundAccount? account}) => TransactionModel(
          id: 't1',
          code: 'TRX-t1',
          shippingCost: 5000,
          deliveryStatus: 'cancelled',
          tax: 0,
          serviceFee: 1000,
          grandTotal: 26000,
          paymentStatus: 'failed',
          transactionDetails: const [],
          refundStatus: 'manual_required',
          refundAccount: account,
        );

    Future<String?> submit() => container.read(transactionProvider.notifier).submitRefundAccount(
          't1',
          bankName: 'BCA',
          accountNumber: '1234567890',
          accountName: 'Budi',
        );

    void stubRepository(Future<TransactionModel> Function() answer) {
      when(() => transactionRepository.submitRefundAccount(
            id: 't1',
            bankName: 'BCA',
            accountNumber: '1234567890',
            accountName: 'Budi',
          )).thenAnswer((_) => answer());
    }

    setUp(() async {
      when(() => transactionRepository.getTransactions()).thenAnswer((_) async => [cancelled()]);
      await container.read(transactionProvider.notifier).loadTransactions();
    });

    test('stores the account the server returns', () async {
      const account = RefundAccount(bankName: 'BCA', accountNumber: '1234567890', accountName: 'Budi');
      stubRepository(() async => cancelled(account: account));

      expect(await submit(), isNull);
      expect(
        container.read(transactionProvider).transactions.single.refundAccount?.accountNumber,
        '1234567890',
      );
    });

    test('failure returns the error message without changing state', () async {
      stubRepository(() async => throw Exception('Pesanan ini tidak membutuhkan rekening refund'));

      expect(await submit(), contains('tidak membutuhkan rekening refund'));
      expect(container.read(transactionProvider).transactions.single.refundAccount, isNull);
    });
  });

  group('complaints', () {
    TransactionModel withComplaint(String status) => TransactionModel(
          id: 't1',
          code: 'TRX-t1',
          shippingCost: 0,
          deliveryStatus: 'delivering',
          tax: 0,
          grandTotal: 26000,
          paymentStatus: 'paid',
          transactionDetails: const [],
          complaint: TransactionComplaint(id: 'c1', status: status),
        );

    setUp(() async {
      when(() => transactionRepository.getTransactions())
          .thenAnswer((_) async => [_transaction(id: 't1', paymentStatus: 'paid', deliveryStatus: 'delivering')]);
      await container.read(transactionProvider.notifier).loadTransactions();
    });

    test('createComplaint sends the form and stores the returned order', () async {
      when(() => transactionRepository.createComplaint(
            id: 't1',
            reason: 'damaged',
            description: 'Kemasan penyok parah',
            photoPaths: ['/tmp/a.jpg'],
          )).thenAnswer((_) async => withComplaint('open'));

      final error = await container.read(transactionProvider.notifier).createComplaint(
            't1',
            reason: 'damaged',
            description: 'Kemasan penyok parah',
            photoPaths: ['/tmp/a.jpg'],
          );

      expect(error, isNull);
      expect(container.read(transactionProvider).transactions.single.complaint?.status, 'open');
    });

    test('withdrawComplaint calls the withdraw endpoint with the complaint id', () async {
      when(() => transactionRepository.withdrawComplaint('c1'))
          .thenAnswer((_) async => withComplaint('withdrawn'));

      final error = await container.read(transactionProvider.notifier).withdrawComplaint('t1', 'c1');

      expect(error, isNull);
      verify(() => transactionRepository.withdrawComplaint('c1')).called(1);
      expect(container.read(transactionProvider).transactions.single.complaint?.status, 'withdrawn');
    });

    test('a failed retry re-reads the order so the card shows what really happened', () async {
      when(() => transactionRepository.withdrawComplaint('c1'))
          .thenThrow(Exception('Status komplain sudah berubah'));
      when(() => transactionRepository.getTransactionDetail('t1'))
          .thenAnswer((_) async => withComplaint('withdrawn'));

      final error = await container.read(transactionProvider.notifier).withdrawComplaint('t1', 'c1');

      expect(error, contains('Status komplain sudah berubah'));
      expect(container.read(transactionProvider).transactions.single.complaint?.status, 'withdrawn');
    });
  });
}
