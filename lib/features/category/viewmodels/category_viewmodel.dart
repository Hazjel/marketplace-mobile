import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:blukios_marketplace/core/providers.dart';
import 'package:blukios_marketplace/features/category/data/category_repository.dart';
import 'package:blukios_marketplace/features/category/models/category_detail_model.dart';

final categoryRepositoryProvider = Provider<CategoryRepository>(
  (ref) => CategoryRepository(ref.watch(apiClientProvider)),
);

class CategoryListData {
  final List<CategoryDetailModel> categories;
  final bool isLoading;
  final String? error;

  const CategoryListData({
    this.categories = const [],
    this.isLoading = true,
    this.error,
  });

  CategoryListData copyWith({
    List<CategoryDetailModel>? categories,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return CategoryListData(
      categories: categories ?? this.categories,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Top-level category grid shown on the browse screen.
///
/// Products *within* a category are not fetched here — the category
/// screen navigates to [SearchScreen] with `productCategoryId` pre-set,
/// reusing its paginated search/sort/filter machinery instead of
/// duplicating it.
class CategoryListNotifier extends Notifier<CategoryListData> {
  @override
  CategoryListData build() => const CategoryListData();

  Future<void> loadCategories() async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final categories =
          await ref.read(categoryRepositoryProvider).getParentCategories();
      state = state.copyWith(categories: categories, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}

final categoryListProvider =
    NotifierProvider<CategoryListNotifier, CategoryListData>(
  CategoryListNotifier.new,
);
