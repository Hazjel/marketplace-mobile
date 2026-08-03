import 'package:dio/dio.dart';
import 'package:blukios_marketplace/config/api_config.dart';
import 'package:blukios_marketplace/core/network/api_client.dart';
import 'package:blukios_marketplace/core/network/api_response.dart';
import 'package:blukios_marketplace/features/review/models/review_model.dart';

class ReviewRepository {
  final ApiClient _apiClient;

  ReviewRepository(this._apiClient);

  /// Note: this endpoint returns a raw Laravel paginator rather than the
  /// PaginateResource envelope used elsewhere. [PaginatedResponse.parse]
  /// handles both shapes.
  Future<PaginatedResponse<ReviewModel>> getReviews({
    String? storeId,
    int page = 1,
    int rowPerPage = 10,
  }) async {
    final response = await _apiClient.get(
      ApiConfig.productReviewsPaginated,
      queryParameters: {
        'page': page,
        'row_per_page': rowPerPage,
        if (storeId != null) 'store_id': storeId,
      },
    );

    return PaginatedResponse.parse(
      response.data as Map<String, dynamic>,
      ReviewModel.fromJson,
    );
  }

  /// Submits a review. Must be multipart — the endpoint accepts image and
  /// video attachments.
  ///
  /// The API rejects this with 403 unless the transaction's
  /// `delivery_status` is `completed`, and 409 if the product in that
  /// transaction was already reviewed.
  Future<ReviewModel> submitReview({
    required String transactionId,
    required String productId,
    required int rating,
    String? review,
    bool isAnonymous = false,
    List<String> attachmentPaths = const [],
  }) async {
    final form = FormData.fromMap({
      'transaction_id': transactionId,
      'product_id': productId,
      'rating': rating,
      if (review != null && review.isNotEmpty) 'review': review,
      'is_anonymous': isAnonymous ? 1 : 0,
      if (attachmentPaths.isNotEmpty)
        'attachments': [
          for (final path in attachmentPaths)
            await MultipartFile.fromFile(path),
        ],
    });

    final response = await _apiClient.post(ApiConfig.productReviews, data: form);
    return ReviewModel.fromJson(response.data['data'] as Map<String, dynamic>);
  }
}
