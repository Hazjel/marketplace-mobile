import 'package:blukios_marketplace/config/api_config.dart';
import 'package:blukios_marketplace/core/network/api_client.dart';
import 'package:blukios_marketplace/features/home/models/product_model.dart';
import 'package:blukios_marketplace/features/home/models/category_model.dart';

class ProductRepository {
  final ApiClient _apiClient;

  ProductRepository(this._apiClient);

  Future<List<ProductModel>> getProducts({int limit = 12, String? search}) async {
    final response = await _apiClient.get(ApiConfig.products, queryParameters: {
      'limit': limit,
      if (search != null) 'search': search,
    });

    final List data = response.data['data'];
    return data.map((e) => ProductModel.fromJson(e)).toList();
  }

  Future<ProductModel> getProductBySlug(String slug) async {
    final response = await _apiClient.get('${ApiConfig.productBySlug}/$slug');
    return ProductModel.fromJson(response.data['data']);
  }

  Future<List<CategoryModel>> getCategories() async {
    final response = await _apiClient.get(ApiConfig.categories);
    final List data = response.data['data'];
    return data.map((e) => CategoryModel.fromJson(e)).toList();
  }
}
