import 'package:dio/dio.dart';
import 'package:blukios_marketplace/config/api_config.dart';
import 'package:blukios_marketplace/core/network/api_client.dart';
import 'package:blukios_marketplace/features/recommendation/data/guest_session_store.dart';
import 'package:blukios_marketplace/features/recommendation/models/recommended_product_model.dart';

/// Wraps the `source` field alongside the personalized product list from
/// `GET /recommend/user/{id}` — `"collaborative"` (real personalization),
/// `"trending_fallback"` (new user / model not ready), or `"empty"`.
class PersonalizedRecommendations {
  final String source;
  final List<RecommendedProductModel> products;

  const PersonalizedRecommendations({
    required this.source,
    required this.products,
  });

  static const empty = PersonalizedRecommendations(source: 'empty', products: []);
}

/// Client for the recommendation service — a separate Python service
/// reachable at `/recommend` on the same host as the API, sibling to `/api`
/// (not nested under it), no auth token required. Uses its own minimal Dio
/// instance rather than [ApiClient], which is hardcoded to `ApiConfig.baseUrl`
/// and attaches an auth bearer token this endpoint doesn't need.
///
/// [fetchSimilar] and [fetchPersonalized] are non-critical, nice-to-have
/// calls — they MUST fail silently (mirrors web's `fetchSimilarProducts`/
/// `fetchPersonalizedProducts` in `stores/recommendation.js`), never
/// surfacing an error to the page that renders them.
class RecommendationRepository {
  final ApiClient _apiClient;
  late final Dio _recoDio;

  RecommendationRepository(this._apiClient) {
    _recoDio = Dio(BaseOptions(
      baseUrl: ApiConfig.recommendationBaseUrl,
      connectTimeout: ApiConfig.connectTimeout,
      receiveTimeout: ApiConfig.receiveTimeout,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));
  }

  /// Content-based "similar products" — always works, no user history
  /// needed. Used on the product detail page.
  Future<List<RecommendedProductModel>> fetchSimilar(
    String productId, {
    int topK = 8,
  }) async {
    try {
      final response = await _recoDio.get(
        ApiConfig.similarProducts(productId),
        queryParameters: {'top_k': topK},
      );
      final data = response.data;
      final List items = (data is Map && data['data'] is List) ? data['data'] : const [];
      return items
          .whereType<Map<String, dynamic>>()
          .map(RecommendedProductModel.fromJson)
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Personalized "for you" recommendations — needs a real user id.
  Future<PersonalizedRecommendations> fetchPersonalized(
    String userId, {
    int topK = 10,
  }) async {
    try {
      final response = await _recoDio.get(
        ApiConfig.personalizedForUser(userId),
        queryParameters: {'top_k': topK},
      );
      final data = response.data;
      if (data is! Map) return PersonalizedRecommendations.empty;
      final List items = data['data'] is List ? data['data'] : const [];
      return PersonalizedRecommendations(
        source: data['source']?.toString() ?? 'empty',
        products: items
            .whereType<Map<String, dynamic>>()
            .map(RecommendedProductModel.fromJson)
            .toList(),
      );
    } catch (_) {
      return PersonalizedRecommendations.empty;
    }
  }

  /// Fire-and-forget product view tracking, feeding the recommendation
  /// model's training data. Goes through the NORMAL authenticated
  /// [ApiClient] (not the recommendation service). If [userId] is null
  /// (guest), resolves/creates the persisted guest session id; a logged-in
  /// user must send a null `session_id` — the server identifies them via
  /// the auth token instead.
  Future<void> trackView({
    required String productId,
    required String? userId,
  }) async {
    try {
      final sessionId =
          userId == null ? await GuestSessionStore.getOrCreate() : null;
      await _apiClient.post(
        ApiConfig.productView(productId),
        data: {'session_id': sessionId},
      );
    } catch (_) {
      // Never let a tracking failure affect the product page.
    }
  }
}
