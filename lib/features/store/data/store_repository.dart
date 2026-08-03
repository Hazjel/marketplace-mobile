import 'package:blukios_marketplace/config/api_config.dart';
import 'package:blukios_marketplace/core/network/api_client.dart';
import 'package:blukios_marketplace/core/network/api_response.dart';
import 'package:blukios_marketplace/features/category/models/category_detail_model.dart';
import 'package:blukios_marketplace/features/review/models/review_model.dart';
import 'package:blukios_marketplace/features/store/models/store_model.dart';

class StoreRepository {
  final ApiClient _apiClient;

  StoreRepository(this._apiClient);

  /// Returns null when the store doesn't exist. The API answers 404 with
  /// `success: true, data: null`, so absence is signalled by the payload,
  /// not the status flag.
  Future<StoreModel?> getByUsername(String username) async {
    final response = await _apiClient.get(ApiConfig.storeByUsername(username));
    final data = response.data['data'];
    if (data == null) return null;
    return StoreModel.fromJson(data as Map<String, dynamic>);
  }

  Future<List<CategoryDetailModel>> getCategories(String username) async {
    final response = await _apiClient.get(ApiConfig.storeCategories(username));
    final List data = response.data['data'] ?? [];
    return data
        .whereType<Map<String, dynamic>>()
        .map(CategoryDetailModel.fromJson)
        .toList();
  }

  /// Store reviews are fixed at 10 per page server-side; only `page` is
  /// honoured.
  Future<PaginatedResponse<ReviewModel>> getReviews(
    String username, {
    int page = 1,
  }) async {
    final response = await _apiClient.get(
      ApiConfig.storeReviews(username),
      queryParameters: {'page': page},
    );
    return PaginatedResponse.parse(
      response.data as Map<String, dynamic>,
      ReviewModel.fromJson,
    );
  }

  Future<bool> getFollowStatus(String storeId) async {
    final response = await _apiClient.get(ApiConfig.storeFollowStatus(storeId));
    return response.data['data']?['is_following'] == true;
  }

  Future<void> follow(String storeId) async {
    await _apiClient.post(ApiConfig.storeFollow(storeId));
  }

  Future<void> unfollow(String storeId) async {
    await _apiClient.post(ApiConfig.storeUnfollow(storeId));
  }
}
