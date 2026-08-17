import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:blukios_marketplace/core/providers.dart';
import 'package:blukios_marketplace/features/home/models/product_model.dart';
import 'package:blukios_marketplace/features/seller/product/models/seller_product_model.dart';

class SellerProductListData {
  final StoreMini? store;
  final List<SellerProductModel> products;
  final bool isLoading;
  final String? error;
  final String? deletingId;

  const SellerProductListData({
    this.store,
    this.products = const [],
    this.isLoading = true,
    this.error,
    this.deletingId,
  });

  SellerProductListData copyWith({
    StoreMini? store,
    List<SellerProductModel>? products,
    bool? isLoading,
    String? error,
    bool clearError = false,
    String? deletingId,
    bool clearDeletingId = false,
  }) {
    return SellerProductListData(
      store: store ?? this.store,
      products: products ?? this.products,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      deletingId: clearDeletingId ? null : (deletingId ?? this.deletingId),
    );
  }
}

/// Drives the seller's own product catalog screen: fetches the seller's
/// store once, then lists only that store's products.
class SellerProductListNotifier extends Notifier<SellerProductListData> {
  @override
  SellerProductListData build() => const SellerProductListData();

  Future<void> loadProducts() async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      var store = state.store;
      store ??= await ref.read(sellerProductRepositoryProvider).getMyStore();

      final products = await ref
          .read(sellerProductRepositoryProvider)
          .getMyProducts(storeId: store.id);

      state = state.copyWith(store: store, products: products, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Returns null on success, or an error message.
  Future<String?> deleteProduct(String id) async {
    state = state.copyWith(deletingId: id);

    try {
      await ref.read(sellerProductRepositoryProvider).deleteProduct(id);
      state = state.copyWith(
        products: state.products.where((p) => p.id != id).toList(),
        clearDeletingId: true,
      );
      return null;
    } catch (e) {
      state = state.copyWith(clearDeletingId: true);
      return e.toString();
    }
  }
}

final sellerProductListProvider =
    NotifierProvider<SellerProductListNotifier, SellerProductListData>(
  SellerProductListNotifier.new,
);
