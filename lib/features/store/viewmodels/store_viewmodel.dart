import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:blukios_marketplace/core/providers.dart';
import 'package:blukios_marketplace/features/home/models/product_model.dart';
import 'package:blukios_marketplace/features/review/models/review_model.dart';
import 'package:blukios_marketplace/features/search/models/search_filters.dart';
import 'package:blukios_marketplace/features/search/viewmodels/search_viewmodel.dart';
import 'package:blukios_marketplace/features/store/data/store_repository.dart';
import 'package:blukios_marketplace/features/store/models/store_model.dart';

final storeRepositoryProvider = Provider<StoreRepository>(
  (ref) => StoreRepository(ref.watch(apiClientProvider)),
);

class StoreData {
  final StoreModel? store;
  final List<ProductModel> products;
  final List<ReviewModel> reviews;
  final bool isFollowing;
  final bool isLoading;
  final bool isTogglingFollow;
  final String? error;

  /// True when the store lookup succeeded but returned no store — the
  /// API's 404 shape, which is distinct from a request failure.
  final bool notFound;

  const StoreData({
    this.store,
    this.products = const [],
    this.reviews = const [],
    this.isFollowing = false,
    this.isLoading = true,
    this.isTogglingFollow = false,
    this.error,
    this.notFound = false,
  });

  StoreData copyWith({
    StoreModel? store,
    List<ProductModel>? products,
    List<ReviewModel>? reviews,
    bool? isFollowing,
    bool? isLoading,
    bool? isTogglingFollow,
    String? error,
    bool clearError = false,
    bool? notFound,
  }) {
    return StoreData(
      store: store ?? this.store,
      products: products ?? this.products,
      reviews: reviews ?? this.reviews,
      isFollowing: isFollowing ?? this.isFollowing,
      isLoading: isLoading ?? this.isLoading,
      isTogglingFollow: isTogglingFollow ?? this.isTogglingFollow,
      error: clearError ? null : (error ?? this.error),
      notFound: notFound ?? this.notFound,
    );
  }
}

/// Keyed by store username so each store page keeps its own state and is
/// disposed when the screen closes.
class StoreNotifier extends AutoDisposeFamilyNotifier<StoreData, String> {
  bool _disposed = false;

  @override
  StoreData build(String username) {
    ref.onDispose(() => _disposed = true);
    return const StoreData();
  }

  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearError: true, notFound: false);

    try {
      final repo = ref.read(storeRepositoryProvider);
      final store = await repo.getByUsername(arg);
      if (_disposed) return;

      if (store == null) {
        state = state.copyWith(isLoading: false, notFound: true);
        return;
      }

      // Products and reviews are non-critical: a failure there shouldn't
      // blank out the store header that already loaded.
      final results = await Future.wait([
        ref
            .read(searchRepositoryProvider)
            .searchProducts(
              filters: SearchFilters.empty.copyWith(storeId: store.id),
              page: 1,
            )
            .then<Object?>((r) => r.items)
            .catchError((_) => null),
        repo
            .getReviews(arg)
            .then<Object?>((r) => r.items)
            .catchError((_) => null),
        repo.getFollowStatus(store.id).then<Object?>((v) => v).catchError((_) => null),
      ]);
      if (_disposed) return;

      state = state.copyWith(
        store: store,
        products: (results[0] as List<ProductModel>?) ?? const [],
        reviews: (results[1] as List<ReviewModel>?) ?? const [],
        isFollowing: (results[2] as bool?) ?? false,
        isLoading: false,
      );
    } catch (e) {
      if (_disposed) return;
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Optimistically flips the follow state, reverting if the call fails.
  /// Returns null on success, or an error message.
  Future<String?> toggleFollow() async {
    final store = state.store;
    if (store == null || state.isTogglingFollow) return null;

    final wasFollowing = state.isFollowing;
    state = state.copyWith(isFollowing: !wasFollowing, isTogglingFollow: true);

    try {
      final repo = ref.read(storeRepositoryProvider);
      if (wasFollowing) {
        await repo.unfollow(store.id);
      } else {
        await repo.follow(store.id);
      }
      if (_disposed) return null;
      state = state.copyWith(isTogglingFollow: false);
      return null;
    } catch (e) {
      if (_disposed) return e.toString();
      state = state.copyWith(isFollowing: wasFollowing, isTogglingFollow: false);
      return e.toString();
    }
  }
}

final storeProvider =
    AutoDisposeNotifierProviderFamily<StoreNotifier, StoreData, String>(
  StoreNotifier.new,
);
