import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:blukios_marketplace/core/providers.dart';
import 'package:blukios_marketplace/features/auth/viewmodels/auth_viewmodel.dart';
import 'package:blukios_marketplace/features/home/models/product_model.dart';
import 'package:blukios_marketplace/features/recommendation/viewmodels/recommendation_viewmodel.dart';

class ProductDetailData {
  final ProductModel? product;
  final bool isLoading;
  final bool addingToCart;
  final String? error;
  final ProductVariantModel? selectedVariant;

  const ProductDetailData({
    this.product,
    this.isLoading = true,
    this.addingToCart = false,
    this.error,
    this.selectedVariant,
  });

  /// Harga/stok yang sebenarnya berlaku untuk baris yang akan dibeli --
  /// varian terpilih kalau ada, kalau tidak agregat produk (produk tanpa
  /// varian). product.price/stock sendiri adalah agregat (varian
  /// termurah/total stok) untuk produk bervarian, bukan nilai baris.
  int get effectivePrice => selectedVariant?.price ?? product?.price ?? 0;
  int get effectiveStock => selectedVariant?.stock ?? product?.stock ?? 0;

  ProductDetailData copyWith({
    ProductModel? product,
    bool? isLoading,
    bool? addingToCart,
    String? error,
    bool clearError = false,
    ProductVariantModel? selectedVariant,
  }) {
    return ProductDetailData(
      product: product ?? this.product,
      isLoading: isLoading ?? this.isLoading,
      addingToCart: addingToCart ?? this.addingToCart,
      error: clearError ? null : (error ?? this.error),
      selectedVariant: selectedVariant ?? this.selectedVariant,
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
      state = state.copyWith(
        product: product,
        isLoading: false,
        // Auto-pilih varian pertama, sama seperti web's ProductDetail.vue
        // -- supaya harga/stok yang ditampilkan begitu halaman terbuka
        // sudah valid (varian mana pun boleh jadi default, bukan berarti
        // "termurah" seperti products.price -- itu cuma kebetulan urutan
        // array dari backend).
        selectedVariant:
            product.hasVariants && product.variants.isNotEmpty
                ? product.variants.first
                : null,
      );

      // Recommendations & view tracking only make sense once the product's
      // id is known — mirrors web's `fetchProduct` in ProductDetail.vue.
      final userId = ref.read(authProvider).currentUser?.id;
      ref.read(recommendationRepositoryProvider).trackView(
            productId: product.id,
            userId: userId,
          );
      ref.read(similarProductsProvider(product.id).notifier).load();
    } catch (e) {
      if (_disposed) return;
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void selectVariant(ProductVariantModel variant) {
    state = state.copyWith(selectedVariant: variant);
  }

  /// Returns null on success, or an error message on failure.
  Future<String?> addToCart() async {
    final product = state.product;
    if (product == null) return 'Produk tidak ditemukan';

    // Server (TransactionRepository::resolveVariant()) menolak checkout
    // produk bervarian tanpa variant_id -- jangan sampai request ini
    // lolos ke server lalu baru gagal di sana. Seharusnya tidak pernah
    // ke sini kalau UI benar (auto-select di loadProduct() menjamin ada
    // pilihan default), tapi tetap dijaga di sini.
    if (product.hasVariants && state.selectedVariant == null) {
      return 'Pilih varian terlebih dahulu';
    }

    state = state.copyWith(addingToCart: true);

    try {
      await ref.read(cartRepositoryProvider).addToCart(
            productId: product.id,
            variantId: state.selectedVariant?.id,
          );
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
