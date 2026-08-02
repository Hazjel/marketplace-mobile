import 'package:blukios_marketplace/config/api_config.dart';
import 'package:blukios_marketplace/core/network/api_client.dart';
import 'package:blukios_marketplace/core/network/api_response.dart';
import 'package:blukios_marketplace/features/category/models/category_detail_model.dart';

class CategoryRepository {
  final ApiClient _apiClient;

  CategoryRepository(this._apiClient);

  /// Top-level categories for the browse grid.
  Future<List<CategoryDetailModel>> getParentCategories() async {
    final response = await _apiClient.get(
      ApiConfig.categories,
      queryParameters: {'is_parent': true},
    );

    final List data = response.data['data'] ?? [];
    return data
        .whereType<Map<String, dynamic>>()
        .map(CategoryDetailModel.fromJson)
        .toList();
  }

  Future<PaginatedResponse<CategoryDetailModel>> getCategoriesPaginated({
    required int page,
    String? search,
    bool? isParent,
    int rowPerPage = 20,
  }) async {
    final response = await _apiClient.get(
      ApiConfig.categoriesPaginated,
      queryParameters: {
        'page': page,
        'row_per_page': rowPerPage,
        if (search != null && search.isNotEmpty) 'search': search,
        if (isParent != null) 'is_parent': isParent,
      },
    );

    return PaginatedResponse.parse(
      response.data as Map<String, dynamic>,
      CategoryDetailModel.fromJson,
    );
  }

  /// Returns null on 404 (API returns `success: true, data: null`).
  Future<CategoryDetailModel?> getCategoryBySlug(String slug) async {
    final response = await _apiClient.get(ApiConfig.categoryBySlug(slug));
    final data = response.data['data'];
    if (data == null) return null;
    return CategoryDetailModel.fromJson(data as Map<String, dynamic>);
  }
}
