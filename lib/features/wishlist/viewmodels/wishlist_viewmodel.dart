import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:blukios_marketplace/core/providers.dart';
import 'package:blukios_marketplace/features/home/models/product_model.dart';
import 'package:blukios_marketplace/features/wishlist/data/wishlist_repository.dart';

final wishlistRepositoryProvider = Provider<WishlistRepository>(
  (ref) => WishlistRepository(ref.watch(apiClientProvider)),
);

class WishlistData {
  final List<ProductModel> products;
  final bool isLoading;
  final String? error;
  // Ids currently mid-toggle — disables the heart button to avoid
  // double-taps racing the same product's toggle request.
  final Set<String> pendingIds;

  const WishlistData({
    this.products = const [],
    this.isLoading = true,
    this.error,
    this.pendingIds = const {},
  });

  Set<String> get productIds => products.map((p) => p.id).toSet();

  WishlistData copyWith({
    List<ProductModel>? products,
    bool? isLoading,
    String? error,
    bool clearError = false,
    Set<String>? pendingIds,
  }) {
    return WishlistData(
      products: products ?? this.products,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      pendingIds: pendingIds ?? this.pendingIds,
    );
  }
}

/// Single source of truth for wishlist membership across the app — the
/// wishlist screen and every heart button (product card, product detail)
/// all read/write this same notifier so toggling in one place updates
/// the other instantly.
class WishlistNotifier extends Notifier<WishlistData> {
  @override
  WishlistData build() => const WishlistData();

  Future<void> loadWishlist() async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final products = await ref.read(wishlistRepositoryProvider).getWishlist();
      state = state.copyWith(products: products, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  bool isWishlisted(String productId) => state.productIds.contains(productId);

  /// Toggles [product] in the wishlist. Safe to call before [loadWishlist]
  /// has ever run — membership starts empty, so the first tap always adds.
  Future<void> toggle(ProductModel product) async {
    if (state.pendingIds.contains(product.id)) return;

    final wasWishlisted = isWishlisted(product.id);
    state = state.copyWith(pendingIds: {...state.pendingIds, product.id});

    try {
      final nowWishlisted =
          await ref.read(wishlistRepositoryProvider).toggle(product.id);

      final products = nowWishlisted
          ? (wasWishlisted ? state.products : [...state.products, product])
          : state.products.where((p) => p.id != product.id).toList();

      state = state.copyWith(
        products: products,
        pendingIds: {...state.pendingIds}..remove(product.id),
      );
    } catch (_) {
      // Leave membership unchanged on failure — caller shows its own error.
      state = state.copyWith(
        pendingIds: {...state.pendingIds}..remove(product.id),
      );
      rethrow;
    }
  }
}

final wishlistProvider =
    NotifierProvider<WishlistNotifier, WishlistData>(WishlistNotifier.new);
