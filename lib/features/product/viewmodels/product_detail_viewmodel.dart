import 'package:flutter/foundation.dart';
import 'package:blukios_marketplace/features/home/data/product_repository.dart';
import 'package:blukios_marketplace/features/home/models/product_model.dart';
import 'package:blukios_marketplace/features/cart/data/cart_repository.dart';

class ProductDetailViewModel extends ChangeNotifier {
  final ProductRepository _productRepository;
  final CartRepository _cartRepository;

  ProductDetailViewModel(this._productRepository, this._cartRepository);

  ProductModel? product;
  bool isLoading = true;
  bool addingToCart = false;
  String? error;

  Future<void> loadProduct(String slug) async {
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      product = await _productRepository.getProductBySlug(slug);
    } catch (e) {
      error = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// Returns null on success, or an error message on failure.
  Future<String?> addToCart() async {
    if (product == null) return 'Produk tidak ditemukan';

    addingToCart = true;
    notifyListeners();

    try {
      await _cartRepository.addToCart(productId: product!.id);
      return null;
    } catch (e) {
      return e.toString();
    } finally {
      addingToCart = false;
      notifyListeners();
    }
  }
}
