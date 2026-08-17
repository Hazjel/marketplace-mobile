import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:blukios_marketplace/core/providers.dart';
import 'package:blukios_marketplace/features/transaction/models/transaction_model.dart';

/// Tabs the seller can filter incoming orders by. `all` shows everything;
/// the rest map 1:1 onto [TransactionModel.deliveryStatus].
enum SellerOrderFilter { all, pending, processing, delivering, completed }

extension SellerOrderFilterX on SellerOrderFilter {
  String get label => switch (this) {
        SellerOrderFilter.all => 'Semua',
        SellerOrderFilter.pending => 'Menunggu Diproses',
        SellerOrderFilter.processing => 'Diproses',
        SellerOrderFilter.delivering => 'Dikirim',
        SellerOrderFilter.completed => 'Selesai',
      };

  /// `null` for [SellerOrderFilter.all] — matches every delivery_status.
  String? get deliveryStatus => switch (this) {
        SellerOrderFilter.all => null,
        SellerOrderFilter.pending => 'pending',
        SellerOrderFilter.processing => 'processing',
        SellerOrderFilter.delivering => 'delivering',
        SellerOrderFilter.completed => 'completed',
      };
}

class SellerOrderListData {
  final List<TransactionModel> orders;
  final bool isLoading;
  final String? error;
  final SellerOrderFilter filter;

  const SellerOrderListData({
    this.orders = const [],
    this.isLoading = true,
    this.error,
    this.filter = SellerOrderFilter.all,
  });

  List<TransactionModel> get visibleOrders {
    final status = filter.deliveryStatus;
    if (status == null) return orders;
    return orders.where((o) => o.deliveryStatus == status).toList();
  }

  SellerOrderListData copyWith({
    List<TransactionModel>? orders,
    bool? isLoading,
    String? error,
    bool clearError = false,
    SellerOrderFilter? filter,
  }) {
    return SellerOrderListData(
      orders: orders ?? this.orders,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      filter: filter ?? this.filter,
    );
  }
}

/// Lists orders placed on the seller's own store — the seller-side mirror
/// of [TransactionNotifier], scoped server-side via `?mode=store`.
class SellerOrderListNotifier extends Notifier<SellerOrderListData> {
  @override
  SellerOrderListData build() => const SellerOrderListData();

  Future<void> loadOrders() async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final orders = await ref.read(transactionRepositoryProvider).getTransactions(
            mode: 'store',
            rowPerPage: 50,
          );
      state = state.copyWith(orders: orders, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void setFilter(SellerOrderFilter filter) {
    state = state.copyWith(filter: filter);
  }

  /// Replaces one order in place after its detail screen updates it, so the
  /// list reflects a new status/tracking number without a full reload.
  void replaceOrder(TransactionModel updated) {
    state = state.copyWith(
      orders: state.orders.map((o) => o.id == updated.id ? updated : o).toList(),
    );
  }
}

final sellerOrderListProvider =
    NotifierProvider<SellerOrderListNotifier, SellerOrderListData>(
  SellerOrderListNotifier.new,
);
