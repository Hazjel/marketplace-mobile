import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:blukios_marketplace/core/network/api_response.dart';
import 'package:blukios_marketplace/core/pagination/paged_notifier.dart';
import 'package:blukios_marketplace/core/providers.dart';
import 'package:blukios_marketplace/features/home/models/product_model.dart';
import 'package:blukios_marketplace/features/search/data/search_repository.dart';
import 'package:blukios_marketplace/features/search/models/search_filters.dart';

final searchRepositoryProvider = Provider<SearchRepository>(
  (ref) => SearchRepository(ref.watch(apiClientProvider)),
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
