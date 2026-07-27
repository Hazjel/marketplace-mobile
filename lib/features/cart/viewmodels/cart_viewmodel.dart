import 'package:flutter/foundation.dart';
import 'package:blukios_marketplace/features/cart/data/cart_repository.dart';
import 'package:blukios_marketplace/features/cart/models/cart_model.dart';

class CartViewModel extends ChangeNotifier {
  final CartRepository _cartRepository;

  CartViewModel(this._cartRepository);

  List<CartGroupModel> groups = [];
  bool isLoading = true;
  String? error;

  double get totalPrice => groups.fold(0, (sum, group) => sum + group.subtotal);

  Future<void> loadCart() async {
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      groups = await _cartRepository.getCart();
    } catch (e) {
      error = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// Returns null on success, or an error message on failure.
  Future<String?> removeItem(String productId, {String? variantId}) async {
    try {
      await _cartRepository.removeFromCart(productId, variantId: variantId);
      for (final group in groups) {
        group.items.removeWhere(
          (item) => item.productId == productId && item.variantId == variantId,
        );
      }
      groups.removeWhere((group) => group.items.isEmpty);
      notifyListeners();
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  /// Drops a whole store group locally after its transaction has been
  /// committed server-side — matches the web checkout's "clear immediately
  /// after transaction is created" pattern.
  void removeGroup(String storeId) {
    groups.removeWhere((group) => group.storeId == storeId);
    notifyListeners();
  }
}
