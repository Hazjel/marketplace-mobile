import 'package:blukios_marketplace/config/api_config.dart';
import 'package:blukios_marketplace/core/network/api_client.dart';
import 'package:blukios_marketplace/features/cart/models/cart_model.dart';

class CartRepository {
  final ApiClient _apiClient;

  CartRepository(this._apiClient);

  Future<List<CartGroupModel>> getCart() async {
    final response = await _apiClient.get(ApiConfig.cart);
    final List data = response.data['data'];
    return data.map((e) => CartGroupModel.fromJson(e)).toList();
  }

  Future<void> addToCart({required String productId, String? variantId, int quantity = 1}) async {
    await _apiClient.post(ApiConfig.cart, data: {
      'product_id': productId,
      if (variantId != null) 'variant_id': variantId,
      'quantity': quantity,
    });
  }

  Future<void> updateQuantity({required String productId, String? variantId, required int quantity}) async {
    await _apiClient.put('${ApiConfig.cart}/$productId', data: {
      if (variantId != null) 'variant_id': variantId,
      'quantity': quantity,
    });
  }

  Future<void> removeFromCart(String productId, {String? variantId}) async {
    await _apiClient.delete(
      '${ApiConfig.cart}/$productId',
      queryParameters: variantId != null ? {'variant_id': variantId} : null,
    );
  }

  Future<void> clearCart() async {
    await _apiClient.delete('${ApiConfig.cart}/clear');
  }

  Future<void> syncCart(List<Map<String, dynamic>> items) async {
    await _apiClient.post(ApiConfig.cartSync, data: {'items': items});
  }

  Future<bool> validateStock(List<Map<String, dynamic>> items) async {
    final response = await _apiClient.post(ApiConfig.cartValidateStock, data: {'items': items});
    return response.data['data']['all_valid'] ?? false;
  }
}
