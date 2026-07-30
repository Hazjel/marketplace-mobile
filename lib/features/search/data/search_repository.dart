import 'package:blukios_marketplace/config/api_config.dart';
import 'package:blukios_marketplace/core/network/api_client.dart';
import 'package:blukios_marketplace/core/network/api_response.dart';
import 'package:blukios_marketplace/features/home/models/product_model.dart';
import 'package:blukios_marketplace/features/search/models/search_filters.dart';

class SearchRepository {
  final ApiClient _apiClient;

  SearchRepository(this._apiClient);

  /// Fetch paginated products with filters.
  ///
  /// Uses the paginated endpoint (not `/product`) because only the
  /// paginated endpoint supports `sort_by`.
  Future<PaginatedResponse<ProductModel>> searchProducts({
    required SearchFilters filters,
    required int page,
    int rowPerPage = 12,
  }) async {
    final response = await _apiClient.get(
      ApiConfig.productSearch,
      queryParameters: filters.toQueryParams(
        page: page,
        rowPerPage: rowPerPage,
      ),
    );

    return PaginatedResponse.parse(
      response.data as Map<String, dynamic>,
      (json) => ProductModel.fromJson(json),
    );
  }
}
