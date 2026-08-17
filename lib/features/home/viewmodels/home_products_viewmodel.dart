import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:blukios_marketplace/core/network/api_response.dart';
import 'package:blukios_marketplace/core/pagination/paged_notifier.dart';
import 'package:blukios_marketplace/features/home/models/product_model.dart';
import 'package:blukios_marketplace/features/search/data/search_repository.dart';
import 'package:blukios_marketplace/features/search/models/search_filters.dart';
import 'package:blukios_marketplace/features/search/viewmodels/search_viewmodel.dart'
    show searchRepositoryProvider;

/// Paginated home feed — reuses [SearchRepository.searchProducts] (same
/// `/product/all/paginated` endpoint as [ApiConfig.products]) with the
/// unfiltered [SearchFilters.empty], instead of a second parsing/duplication
/// path in [ProductRepository].
class HomeProductsNotifier extends PagedNotifier<ProductModel> {
  @override
  Future<PaginatedResponse<ProductModel>> fetchPage(int page) {
    final repo = ref.read(searchRepositoryProvider);
    return repo.searchProducts(filters: SearchFilters.empty, page: page);
  }
}

final homeProductsProvider =
    NotifierProvider<HomeProductsNotifier, PagedState<ProductModel>>(
  HomeProductsNotifier.new,
);
