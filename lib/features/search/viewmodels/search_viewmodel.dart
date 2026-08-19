import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:blukios_marketplace/core/network/api_response.dart';
import 'package:blukios_marketplace/core/pagination/paged_notifier.dart';
import 'package:blukios_marketplace/core/providers.dart';
import 'package:blukios_marketplace/features/home/models/product_model.dart';
import 'package:blukios_marketplace/features/search/data/search_history_repository.dart';
import 'package:blukios_marketplace/features/search/data/search_repository.dart';
import 'package:blukios_marketplace/features/search/models/search_filters.dart';
import 'package:blukios_marketplace/features/search/models/search_suggestions_model.dart';

final searchRepositoryProvider = Provider<SearchRepository>(
  (ref) => SearchRepository(ref.watch(apiClientProvider)),
);

final searchHistoryRepositoryProvider = Provider<SearchHistoryRepository>(
  (ref) => SearchHistoryRepository(),
);

/// Manages the current filter state, persisted across rebuilds.
class SearchFilterNotifier extends Notifier<SearchFilters> {
  @override
  SearchFilters build() => SearchFilters.empty;

  void updateFilters(SearchFilters filters) {
    state = filters;
    // Trigger a fresh search when filters change
    ref.read(searchResultsProvider.notifier).loadFirstPage();
  }

  void clearAll() {
    state = SearchFilters.empty;
    ref.read(searchResultsProvider.notifier).loadFirstPage();
  }
}

final searchFilterProvider =
    NotifierProvider<SearchFilterNotifier, SearchFilters>(
  SearchFilterNotifier.new,
);

/// Paginated search results — extends [PagedNotifier] to reuse
/// infinite-scroll loading, pagination tracking, and error handling.
class SearchResultsNotifier extends PagedNotifier<ProductModel> {
  @override
  Future<PaginatedResponse<ProductModel>> fetchPage(int page) {
    final filters = ref.read(searchFilterProvider);
    final repo = ref.read(searchRepositoryProvider);
    return repo.searchProducts(filters: filters, page: page);
  }
}

final searchResultsProvider =
    NotifierProvider<SearchResultsNotifier, PagedState<ProductModel>>(
  SearchResultsNotifier.new,
);

/// Live typeahead suggestions for the search bar dropdown. Debounced
/// 300ms, matching both the backend's throttling expectations and the web
/// app's `handleSearchInput`. Separate from [SearchResultsNotifier], which
/// backs the full results grid — this is purely for the as-you-type
/// overlay.
class SearchSuggestionsNotifier
    extends AutoDisposeNotifier<AsyncValue<SearchSuggestions>> {
  Timer? _debounce;

  @override
  AsyncValue<SearchSuggestions> build() {
    ref.onDispose(() => _debounce?.cancel());
    return const AsyncValue.data(SearchSuggestions.empty);
  }

  void onQueryChanged(String query) {
    _debounce?.cancel();
    final trimmed = query.trim();
    // Same 2-char floor as the backend — no point firing a request that
    // would come back empty anyway.
    if (trimmed.length < 2) {
      state = const AsyncValue.data(SearchSuggestions.empty);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      state = const AsyncValue.loading();
      try {
        final result = await ref.read(searchRepositoryProvider).getSuggestions(trimmed);
        state = AsyncValue.data(result);
      } catch (e, st) {
        state = AsyncValue.error(e, st);
      }
    });
  }

  /// Clears any in-flight debounce/result — used when the dropdown is
  /// dismissed (submit, blur, or a suggestion tap).
  void reset() {
    _debounce?.cancel();
    state = const AsyncValue.data(SearchSuggestions.empty);
  }
}

final searchSuggestionsProvider =
    AutoDisposeNotifierProvider<SearchSuggestionsNotifier, AsyncValue<SearchSuggestions>>(
  SearchSuggestionsNotifier.new,
);

/// Recent search history, backed by [SearchHistoryRepository]
/// (SharedPreferences). Kept separate from [SearchSuggestionsNotifier] —
/// different concern, loaded once and mutated in place rather than
/// debounced.
class SearchHistoryNotifier extends AutoDisposeNotifier<List<String>> {
  @override
  List<String> build() {
    _load();
    return const [];
  }

  Future<void> _load() async {
    state = await ref.read(searchHistoryRepositoryProvider).load();
  }

  /// Re-reads history from storage. Called when the search bar regains
  /// focus, in case it changed elsewhere while this screen stayed mounted.
  Future<void> refresh() => _load();

  Future<void> save(String query) async {
    state = await ref.read(searchHistoryRepositoryProvider).save(query);
  }

  Future<void> removeAt(int index) async {
    state = await ref.read(searchHistoryRepositoryProvider).removeAt(index);
  }

  Future<void> clear() async {
    await ref.read(searchHistoryRepositoryProvider).clear();
    state = const [];
  }
}

final searchHistoryProvider =
    AutoDisposeNotifierProvider<SearchHistoryNotifier, List<String>>(
  SearchHistoryNotifier.new,
);
