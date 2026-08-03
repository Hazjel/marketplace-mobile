/// Immutable filter parameters for product search.
///
/// Mirrors the query params accepted by `GET /product/all/paginated`.
class SearchFilters {
  final String? search;
  final String? productCategoryId;
  final String? storeId;
  final double? minPrice;
  final double? maxPrice;
  final String? condition;
  final String? city;
  final double? minRating;
  final String? stockStatus;
  final int? createdSince;
  final String? sortBy;
  final String? sortDirection;

  const SearchFilters({
    this.search,
    this.productCategoryId,
    this.storeId,
    this.minPrice,
    this.maxPrice,
    this.condition,
    this.city,
    this.minRating,
    this.stockStatus,
    this.createdSince,
    this.sortBy,
    this.sortDirection,
  });

  /// Default — sends `stock_status` filter to sidestep the API
  /// page-cache bug (cache key excludes `page`).
  static const empty = SearchFilters(stockStatus: 'all');

  bool get hasActiveFilters =>
      search != null ||
      productCategoryId != null ||
      minPrice != null ||
      maxPrice != null ||
      condition != null ||
      city != null ||
      minRating != null ||
      createdSince != null;

  /// Convert to API query parameters, omitting nulls.
  Map<String, dynamic> toQueryParams({required int page, int rowPerPage = 12}) {
    return {
      'page': page,
      'row_per_page': rowPerPage,
      // Always include at least one filter to bypass page-cache bug
      'stock_status': stockStatus ?? 'all',
      if (search != null && search!.isNotEmpty) 'search': search,
      if (productCategoryId != null) 'product_category_id': productCategoryId,
      if (storeId != null) 'store_id': storeId,
      if (minPrice != null) 'min_price': minPrice,
      if (maxPrice != null) 'max_price': maxPrice,
      if (condition != null) 'condition': condition,
      if (city != null) 'city': city,
      if (minRating != null) 'min_rating': minRating,
      if (createdSince != null) 'created_since': createdSince,
      if (sortBy != null) 'sort_by': sortBy,
      if (sortDirection != null) 'sort_direction': sortDirection,
    };
  }

  SearchFilters copyWith({
    String? search,
    String? productCategoryId,
    String? storeId,
    double? minPrice,
    double? maxPrice,
    String? condition,
    String? city,
    double? minRating,
    String? stockStatus,
    int? createdSince,
    String? sortBy,
    String? sortDirection,
    bool clearSearch = false,
    bool clearCategory = false,
    bool clearMinPrice = false,
    bool clearMaxPrice = false,
    bool clearCondition = false,
    bool clearCity = false,
    bool clearMinRating = false,
    bool clearCreatedSince = false,
    bool clearSortBy = false,
    bool clearSortDirection = false,
  }) {
    return SearchFilters(
      search: clearSearch ? null : (search ?? this.search),
      productCategoryId: clearCategory ? null : (productCategoryId ?? this.productCategoryId),
      storeId: storeId ?? this.storeId,
      minPrice: clearMinPrice ? null : (minPrice ?? this.minPrice),
      maxPrice: clearMaxPrice ? null : (maxPrice ?? this.maxPrice),
      condition: clearCondition ? null : (condition ?? this.condition),
      city: clearCity ? null : (city ?? this.city),
      minRating: clearMinRating ? null : (minRating ?? this.minRating),
      stockStatus: stockStatus ?? this.stockStatus,
      createdSince: clearCreatedSince ? null : (createdSince ?? this.createdSince),
      sortBy: clearSortBy ? null : (sortBy ?? this.sortBy),
      sortDirection: clearSortDirection ? null : (sortDirection ?? this.sortDirection),
    );
  }
}
