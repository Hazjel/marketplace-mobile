import 'package:blukios_marketplace/config/api_config.dart';
import 'package:blukios_marketplace/core/network/api_client.dart';
import 'package:blukios_marketplace/features/home/models/product_model.dart';

class WishlistRepository {
  final ApiClient _apiClient;

  WishlistRepository(this._apiClient);

  /// Products in the buyer's wishlist. Skips null entries — the API
  /// plucks `product` from the wishlist join, so a product deleted after
  /// being wishlisted comes back as `null` in the list.
  Future<List<ProductModel>> getWishlist() async {
    final response = await _apiClient.get(ApiConfig.wishlist);
    final List data = response.data['data'] ?? [];
    return data
        .whereType<Map<String, dynamic>>()
        .map(ProductModel.fromJson)
        .toList();
  }

  /// Toggles wishlist membership for [productId].
  /// Returns `true` if the product is now wishlisted, `false` if removed.
  Future<bool> toggle(String productId) async {
    final response = await _apiClient.post(
      ApiConfig.wishlist,
      data: {'product_id': productId},
    );
    return response.data['data']?['status'] == 'added';
  }
}
