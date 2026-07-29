import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:blukios_marketplace/core/providers.dart';
import 'package:blukios_marketplace/features/cart/models/cart_model.dart';

class CartData {
  final List<CartGroupModel> groups;
  final bool isLoading;
  final String? error;

  const CartData({
    this.groups = const [],
    this.isLoading = true,
    this.error,
  });

  double get totalPrice => groups.fold(0, (sum, group) => sum + group.subtotal);

  CartData copyWith({
    List<CartGroupModel>? groups,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return CartData(
      groups: groups ?? this.groups,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class CartNotifier extends Notifier<CartData> {
  @override
  CartData build() => const CartData();

  Future<void> loadCart() async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final groups = await ref.read(cartRepositoryProvider).getCart();
      state = state.copyWith(groups: groups, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Returns null on success, or an error message on failure.
  Future<String?> removeItem(String productId, {String? variantId}) async {
    try {
      await ref
          .read(cartRepositoryProvider)
          .removeFromCart(productId, variantId: variantId);

      // Rebuild rather than mutate in place — Riverpod compares state
      // identity, so an in-place edit would not notify listeners.
      final groups = state.groups
          .map((group) => group.copyWith(
                items: group.items
                    .where((item) =>
                        item.productId != productId || item.variantId != variantId)
                    .toList(),
              ))
          .where((group) => group.items.isNotEmpty)
          .toList();

      state = state.copyWith(groups: groups);
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  /// Drops a whole store group locally after its transaction has been
  /// committed server-side — matches the web checkout's "clear immediately
  /// after transaction is created" pattern.
  void removeGroup(String storeId) {
    state = state.copyWith(
      groups: state.groups.where((group) => group.storeId != storeId).toList(),
    );
  }
}

final cartProvider = NotifierProvider<CartNotifier, CartData>(CartNotifier.new);
