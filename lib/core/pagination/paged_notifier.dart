import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:blukios_marketplace/core/network/api_response.dart';

/// State for any paginated list screen.
class PagedState<T> {
  final List<T> items;
  final int currentPage;
  final bool hasMore;
  final bool isLoading;
  final bool isLoadingMore;
  final String? error;

  const PagedState({
    this.items = const [],
    this.currentPage = 0,
    this.hasMore = true,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.error,
  });

  PagedState<T> copyWith({
    List<T>? items,
    int? currentPage,
    bool? hasMore,
    bool? isLoading,
    bool? isLoadingMore,
    String? error,
    bool clearError = false,
  }) {
    return PagedState(
      items: items ?? this.items,
      currentPage: currentPage ?? this.currentPage,
      hasMore: hasMore ?? this.hasMore,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Reusable infinite-scroll base notifier.
///
/// Subclasses only implement [fetchPage] — loading state, pagination tracking,
/// append vs. replace, and error handling are handled here.
///
/// Sends a default filter param on all requests to sidestep the API's
/// page-cache bug (cache key excludes `page`, so unfiltered page 2+ can
/// return page 1 data).
abstract class PagedNotifier<T> extends Notifier<PagedState<T>> {
  @override
  PagedState<T> build() => const PagedState();

  /// Fetch a single page of data from the API.
  ///
  /// Implementations should call the repository and return a [PaginatedResponse].
  Future<PaginatedResponse<T>> fetchPage(int page);

  /// Load the first page, replacing existing items.
  Future<void> loadFirstPage() async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final response = await fetchPage(1);
      state = PagedState(
        items: response.items,
        currentPage: response.meta.currentPage,
        hasMore: response.hasMore,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Load the next page, appending items.
  Future<void> loadNextPage() async {
    if (!state.hasMore || state.isLoadingMore || state.isLoading) return;

    state = state.copyWith(isLoadingMore: true);

    try {
      final response = await fetchPage(state.currentPage + 1);
      state = state.copyWith(
        items: [...state.items, ...response.items],
        currentPage: response.meta.currentPage,
        hasMore: response.hasMore,
        isLoadingMore: false,
      );
    } catch (e) {
      state = state.copyWith(isLoadingMore: false, error: e.toString());
    }
  }

  /// Refresh — reload from page 1 while keeping current items visible.
  Future<void> refresh() async => loadFirstPage();
}
