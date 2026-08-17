import 'package:dio/dio.dart';
import 'package:blukios_marketplace/config/api_config.dart';
import 'package:blukios_marketplace/core/network/api_client.dart';
import 'package:blukios_marketplace/features/home/models/product_model.dart';
import 'package:blukios_marketplace/features/seller/product/models/seller_product_form_models.dart';
import 'package:blukios_marketplace/features/seller/product/models/seller_product_model.dart';

class SellerProductRepository {
  final ApiClient _apiClient;

  SellerProductRepository(this._apiClient);

  /// The logged-in seller's own store. Reuses [StoreMini] (home/product
  /// feature) since it already covers the id/name/username/logo this
  /// screen needs — no reason to duplicate a store model here.
  Future<StoreMini> getMyStore() async {
    final response = await _apiClient.get(ApiConfig.myStore);
    return StoreMini.fromJson(response.data['data'] as Map<String, dynamic>);
  }

  /// All products belonging to [storeId]. `GET /product` has no pagination
  /// envelope, so a generous single page covers a seller's whole catalog
  /// the same way [TransactionRepository.getTransactions] does for orders.
  Future<List<SellerProductModel>> getMyProducts({
    required String storeId,
    String? search,
  }) async {
    final response = await _apiClient.get(
      ApiConfig.products,
      queryParameters: {
        'store_id': storeId,
        if (search != null && search.isNotEmpty) 'search': search,
      },
    );

    final List data = response.data['data'] ?? [];
    return data
        .whereType<Map<String, dynamic>>()
        .map(SellerProductModel.fromJson)
        .toList();
  }

  Future<SellerProductModel> createProduct(SellerProductPayload payload) async {
    final form = await _buildFormData(payload);
    final response = await _apiClient.post(ApiConfig.products, data: form);
    return SellerProductModel.fromJson(
      response.data['data'] as Map<String, dynamic>,
    );
  }

  Future<SellerProductModel> updateProduct(
    String id,
    SellerProductPayload payload,
  ) async {
    final form = await _buildFormData(payload);
    final response = await _apiClient.put(ApiConfig.productById(id), data: form);
    return SellerProductModel.fromJson(
      response.data['data'] as Map<String, dynamic>,
    );
  }

  Future<void> deleteProduct(String id) async {
    await _apiClient.delete(ApiConfig.productById(id));
  }

  Future<FormData> _buildFormData(SellerProductPayload payload) async {
    return FormData.fromMap({
      'store_id': payload.storeId,
      'product_category_id': payload.categoryId,
      'name': payload.name,
      'description': payload.description,
      'condition': payload.condition,
      'price': payload.price,
      'weight': payload.weight,
      'stock': payload.stock,
      if (payload.newImages.isNotEmpty)
        'product_images': [
          for (final image in payload.newImages)
            {
              'image': await MultipartFile.fromFile(image.localPath),
              'is_thumbnail': image.isThumbnail ? 1 : 0,
            },
        ],
    });
  }
}
