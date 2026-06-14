import 'package:blukios_marketplace/config/api_config.dart';
import 'package:blukios_marketplace/core/network/api_client.dart';
import 'package:blukios_marketplace/features/cart/models/cart_model.dart';

class CartRepository {
  final ApiClient _apiClient;

  CartRepository(this._apiClient);

  Future<List<CartModel>> getCart() async {
    final response = await _apiClient.get(ApiConfig.cart);
    final List data = response.data['data'];
    return data.map((e) => CartModel.fromJson(e)).toList();
  }

  Future<void> addToCart({required String productId, int quantity = 1}) async {
    await _apiClient.post(ApiConfig.cart, data: {
      'product_id': productId,
      'quantity': quantity,
    });
  }

  Future<void> updateQuantity({required String cartId, required int quantity}) async {
    await _apiClient.put('${ApiConfig.cart}/$cartId', data: {
      'quantity': quantity,
    });
  }

  Future<void> removeFromCart(String cartId) async {
    await _apiClient.delete('${ApiConfig.cart}/$cartId');
  }

  Future<void> syncCart(List<Map<String, dynamic>> items) async {
    await _apiClient.post(ApiConfig.cartSync, data: {'items': items});
  }

  Future<bool> validateStock() async {
    final response = await _apiClient.get(ApiConfig.cartValidateStock);
    return response.data['data']['valid'] ?? false;
  }
}
