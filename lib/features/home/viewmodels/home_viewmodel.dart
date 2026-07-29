import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:blukios_marketplace/core/providers.dart';
import 'package:blukios_marketplace/features/home/models/product_model.dart';
import 'package:blukios_marketplace/features/home/models/category_model.dart';

class HomeData {
  final List<ProductModel> products;
  final List<CategoryModel> categories;
  final bool isLoading;
  final String? error;
  final String searchQuery;

  const HomeData({
    this.products = const [],
    this.categories = const [],
    this.isLoading = true,
    this.error,
    this.searchQuery = '',
  });

  HomeData copyWith({
    List<ProductModel>? products,
    List<CategoryModel>? categories,
    bool? isLoading,
    String? error,
    bool clearError = false,
    String? searchQuery,
  }) {
    return HomeData(
      products: products ?? this.products,
      categories: categories ?? this.categories,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }
}

class HomeNotifier extends Notifier<HomeData> {
  @override
  HomeData build() => const HomeData();

  Future<void> loadData() async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final repository = ref.read(productRepositoryProvider);
      final query = state.searchQuery;
      final results = await Future.wait([
        repository.getProducts(search: query.isEmpty ? null : query),
        repository.getCategories(),
      ]);

      state = state.copyWith(
        products: results[0] as List<ProductModel>,
        categories: results[1] as List<CategoryModel>,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> search(String query) async {
    state = state.copyWith(searchQuery: query);
    await loadData();
  }
}

final homeProvider = NotifierProvider<HomeNotifier, HomeData>(HomeNotifier.new);
