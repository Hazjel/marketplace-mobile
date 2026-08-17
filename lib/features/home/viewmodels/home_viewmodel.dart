import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:blukios_marketplace/core/providers.dart';
import 'package:blukios_marketplace/features/home/models/category_model.dart';

/// Categories are a one-shot fetch — kept separate from the paginated
/// product feed (see [homeProductsProvider]) so loading another page of
/// products never resets or reloads the category strip.
class HomeData {
  final List<CategoryModel> categories;
  final bool isLoading;
  final String? error;

  const HomeData({
    this.categories = const [],
    this.isLoading = true,
    this.error,
  });

  HomeData copyWith({
    List<CategoryModel>? categories,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return HomeData(
      categories: categories ?? this.categories,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
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
      final categories = await repository.getCategories();

      state = state.copyWith(
        categories: categories,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}

final homeProvider = NotifierProvider<HomeNotifier, HomeData>(HomeNotifier.new);
