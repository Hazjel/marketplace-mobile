import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:blukios_marketplace/core/providers.dart';
import 'package:blukios_marketplace/features/transaction/models/transaction_model.dart';

class TransactionData {
  final List<TransactionModel> transactions;
  final bool isLoading;
  final String? error;

  const TransactionData({
    this.transactions = const [],
    this.isLoading = true,
    this.error,
  });

  TransactionData copyWith({
    List<TransactionModel>? transactions,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return TransactionData(
      transactions: transactions ?? this.transactions,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class TransactionNotifier extends Notifier<TransactionData> {
  @override
  TransactionData build() => const TransactionData();

  Future<void> loadTransactions() async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final transactions =
          await ref.read(transactionRepositoryProvider).getTransactions();
      state = state.copyWith(transactions: transactions, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Re-checks payment status against Midtrans for one transaction and
  /// updates it in place. Returns null on success, or an error message.
  Future<String?> refreshStatus(String id) async {
    try {
      final updated =
          await ref.read(transactionRepositoryProvider).checkPaymentStatus(id);
      state = state.copyWith(
        transactions:
            state.transactions.map((t) => t.id == id ? updated : t).toList(),
      );
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  /// Marks [productId] as reviewed within [transactionId] locally, so the
  /// "Beri Ulasan" button hides immediately after a successful submit
  /// without needing a full reload.
  void markReviewed(String transactionId, String productId) {
    state = state.copyWith(
      transactions: state.transactions.map((t) {
        if (t.id != transactionId) return t;
        return t.copyWith(reviewedProductIds: {...t.reviewedProductIds, productId});
      }).toList(),
    );
  }

  /// Buyer confirms receipt of a `delivering` order with a photo proof.
  /// Releases escrow to the store server-side. Returns null on success, or
  /// an error message.
  Future<String?> completeOrder(String id, String receivingProofPath) async {
    try {
      final updated = await ref.read(transactionRepositoryProvider).completeOrder(
            id: id,
            receivingProofPath: receivingProofPath,
          );
      state = state.copyWith(
        transactions:
            state.transactions.map((t) => t.id == id ? updated : t).toList(),
      );
      return null;
    } catch (e) {
      return e.toString();
    }
  }
}

final transactionProvider =
    NotifierProvider<TransactionNotifier, TransactionData>(
  TransactionNotifier.new,
);
