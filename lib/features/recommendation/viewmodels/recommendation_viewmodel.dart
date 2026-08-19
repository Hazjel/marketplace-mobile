import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:blukios_marketplace/core/providers.dart';
import 'package:blukios_marketplace/features/recommendation/data/recommendation_repository.dart';
import 'package:blukios_marketplace/features/recommendation/models/recommended_product_model.dart';

final recommendationRepositoryProvider = Provider<RecommendationRepository>(
  (ref) => RecommendationRepository(ref.watch(apiClientProvider)),
);

class SimilarProductsData {
  final List<RecommendedProductModel> products;
  final bool isLoading;

  const SimilarProductsData({this.products = const [], this.isLoading = true});

  SimilarProductsData copyWith({
    List<RecommendedProductModel>? products,
    bool? isLoading,
  }) {
    return SimilarProductsData(
      products: products ?? this.products,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

/// "Produk Serupa" section on the product detail page. Keyed by product id
/// so each detail screen gets its own state. Never surfaces an error — the
/// repository already fails silently, so the worst case here is an empty,
/// hidden section.
class SimilarProductsNotifier
    extends AutoDisposeFamilyNotifier<SimilarProductsData, String> {
  bool _disposed = false;

  @override
  SimilarProductsData build(String productId) {
    ref.onDispose(() => _disposed = true);
    return const SimilarProductsData();
  }

  Future<void> load() async {
    final products =
        await ref.read(recommendationRepositoryProvider).fetchSimilar(arg);
    if (_disposed) return;
    state = state.copyWith(products: products, isLoading: false);
  }
}

final similarProductsProvider = AutoDisposeNotifierProviderFamily<
    SimilarProductsNotifier, SimilarProductsData, String>(
  SimilarProductsNotifier.new,
);

class PersonalizedRecommendationsData {
  final PersonalizedRecommendations recommendations;
  final bool isLoading;

  const PersonalizedRecommendationsData({
    this.recommendations = PersonalizedRecommendations.empty,
    this.isLoading = true,
  });

  PersonalizedRecommendationsData copyWith({
    PersonalizedRecommendations? recommendations,
    bool? isLoading,
  }) {
    return PersonalizedRecommendationsData(
      recommendations: recommendations ?? this.recommendations,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

/// "Rekomendasi Buat Kamu" / "Sedang Trending" section on the home screen.
/// Keyed by user id — only meaningful for a logged-in user (see the home
/// screen, which skips this entirely for guests).
class PersonalizedRecommendationsNotifier extends AutoDisposeFamilyNotifier<
    PersonalizedRecommendationsData, String> {
  bool _disposed = false;

  @override
  PersonalizedRecommendationsData build(String userId) {
    ref.onDispose(() => _disposed = true);
    return const PersonalizedRecommendationsData();
  }

  Future<void> load() async {
    final recommendations = await ref
        .read(recommendationRepositoryProvider)
        .fetchPersonalized(arg);
    if (_disposed) return;
    state = state.copyWith(recommendations: recommendations, isLoading: false);
  }
}

final personalizedRecommendationsProvider = AutoDisposeNotifierProviderFamily<
    PersonalizedRecommendationsNotifier, PersonalizedRecommendationsData, String>(
  PersonalizedRecommendationsNotifier.new,
);
