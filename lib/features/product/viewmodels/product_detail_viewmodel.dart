import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:blukios_marketplace/core/providers.dart';
import 'package:blukios_marketplace/features/home/models/product_model.dart';

class ProductDetailData {
  final ProductModel? product;
  final bool isLoading;
  final bool addingToCart;
  final String? error;

  const ProductDetailData({
    this.product,
    this.isLoading = true,
    this.addingToCart = false,
    this.error,
  });

  ProductDetailData copyWith({
    ProductModel? product,
    bool? isLoading,
    bool? addingToCart,
    String? error,
    bool clearError = false,
  }) {
    return ProductDetailData(
      product: product ?? this.product,
      isLoading: isLoading ?? this.isLoading,
      addingToCart: addingToCart ?? this.addingToCart,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Keyed by product slug so each product detail screen gets its own state.
class ProductDetailNotifier
    extends AutoDisposeFamilyNotifier<ProductDetailData, String> {
  bool _disposed = false;

  @override
  ProductDetailData build(String slug) {
    ref.onDispose(() => _disposed = true);
    return const ProductDetailData();
  }

  Future<void> loadProduct() async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final product =
          await ref.read(productRepositoryProvider).getProductBySlug(arg);
      if (_disposed) return;
      state = state.copyWith(product: product, isLoading: false);
    } catch (e) {
      if (_disposed) return;
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Returns null on success, or an error message on failure.
  Future<String?> addToCart() async {
    final product = state.product;
    if (product == null) return 'Produk tidak ditemukan';

    state = state.copyWith(addingToCart: true);

    try {
      await ref.read(cartRepositoryProvider).addToCart(productId: product.id);
      return null;
    } catch (e) {
      return e.toString();
    } finally {
      if (!_disposed) {
        state = state.copyWith(addingToCart: false);
      }
    }
  }
}

final productDetailProvider = AutoDisposeNotifierProviderFamily<
    ProductDetailNotifier, ProductDetailData, String>(
  ProductDetailNotifier.new,
);
