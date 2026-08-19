import 'package:blukios_marketplace/core/utils/json.dart';
import 'package:blukios_marketplace/features/home/models/product_model.dart';

/// A category match from `/search/suggestions`.
///
/// Deliberately not [CategoryModel] — that model requires `product_count`,
/// which this lightweight suggestions endpoint doesn't send.
class SearchCategorySuggestion {
  final String id;
  final String name;
  final String slug;

  SearchCategorySuggestion({
    required this.id,
    required this.name,
    required this.slug,
  });

  factory SearchCategorySuggestion.fromJson(Map<String, dynamic> json) {
    return SearchCategorySuggestion(
      id: json.asString('id'),
      name: json.asString('name'),
      slug: json.asString('slug'),
    );
  }
}

/// A store match from `/search/suggestions`.
///
/// Deliberately not [StoreModel] — that model requires fields (e.g.
/// `is_verified`, `product_count`, `transaction_count`) this endpoint
/// doesn't send.
class SearchStoreSuggestion {
  final String id;
  final String name;
  final String username;
  final String? logo;

  SearchStoreSuggestion({
    required this.id,
    required this.name,
    required this.username,
    this.logo,
  });

  factory SearchStoreSuggestion.fromJson(Map<String, dynamic> json) {
    return SearchStoreSuggestion(
      id: json.asString('id'),
      name: json.asString('name'),
      username: json.asString('username'),
      logo: json.asStringOrNull('logo'),
    );
  }
}

/// Wraps the three suggestion lists returned by `/search/suggestions`.
class SearchSuggestions {
  final List<ProductModel> products;
  final List<SearchCategorySuggestion> categories;
  final List<SearchStoreSuggestion> stores;

  const SearchSuggestions({
    required this.products,
    required this.categories,
    required this.stores,
  });

  static const empty = SearchSuggestions(
    products: [],
    categories: [],
    stores: [],
  );

  bool get isEmpty => products.isEmpty && categories.isEmpty && stores.isEmpty;

  factory SearchSuggestions.fromJson(Map<String, dynamic> json) {
    List<T> parseList<T>(String key, T Function(Map<String, dynamic>) mapper) {
      final raw = json[key];
      if (raw is! List) return const [];
      return raw.whereType<Map<String, dynamic>>().map(mapper).toList();
    }

    return SearchSuggestions(
      products: parseList('products', ProductModel.fromJson),
      categories: parseList('categories', SearchCategorySuggestion.fromJson),
      stores: parseList('stores', SearchStoreSuggestion.fromJson),
    );
  }
}
