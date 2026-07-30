/// Lenient API response envelope parsers.
///
/// The API uses multiple pagination shapes:
///   1. `PaginateResource` → items at `data.data`, meta at `data.meta` (7 keys)
///   2. Raw Laravel paginator → items at `data.data`, meta at `data` (with `links`, `meta.links`)
///
/// [PaginatedResponse] handles both by reading items from `data.data` and
/// meta from either `data.meta` or `data` itself.
library;

class ApiEnvelope<T> {
  final bool success;
  final String message;
  final T? data;

  const ApiEnvelope({
    required this.success,
    required this.message,
    this.data,
  });

  /// Unwraps `{ success, message, data }`.
  ///
  /// Treats missing `success` as `true` (422 bodies omit it).
  /// Treats `null` data as absent rather than error — the caller decides
  /// whether null is valid (e.g. 404 returns `success: true, data: null`).
  factory ApiEnvelope.fromResponse(
    Map<String, dynamic> json, {
    T Function(dynamic raw)? dataMapper,
  }) {
    return ApiEnvelope(
      success: json['success'] as bool? ?? true,
      message: (json['message'] as String?) ?? '',
      data: json['data'] != null && dataMapper != null
          ? dataMapper(json['data'])
          : json['data'] as T?,
    );
  }

  bool get hasData => data != null;
}

/// Pagination metadata extracted from either envelope shape.
class PaginationMeta {
  final int currentPage;
  final int lastPage;
  final int perPage;
  final int total;

  const PaginationMeta({
    required this.currentPage,
    required this.lastPage,
    required this.perPage,
    required this.total,
  });

  bool get hasMore => currentPage < lastPage;

  factory PaginationMeta.fromJson(Map<String, dynamic> json) {
    return PaginationMeta(
      currentPage: _toInt(json['current_page']),
      lastPage: _toInt(json['last_page']),
      perPage: _toInt(json['per_page']),
      total: _toInt(json['total']),
    );
  }

  static int _toInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }
}

/// Paginated API response — works with both PaginateResource and raw paginator.
class PaginatedResponse<T> {
  final List<T> items;
  final PaginationMeta meta;

  const PaginatedResponse({required this.items, required this.meta});

  bool get hasMore => meta.hasMore;
  int get nextPage => meta.currentPage + 1;

  /// Parses paginated response.
  ///
  /// Expected shapes:
  /// - `{ success, data: { data: [...], meta: {...} } }` (PaginateResource)
  /// - `{ success, data: { data: [...], current_page, last_page, ... } }` (raw paginator)
  ///
  /// [itemMapper] converts each raw item JSON to [T].
  factory PaginatedResponse.parse(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) itemMapper,
  ) {
    // Navigate to the envelope `data` field
    final envelope = json['data'];

    if (envelope is! Map<String, dynamic>) {
      return const PaginatedResponse(
        items: [],
        meta: PaginationMeta(
          currentPage: 1, lastPage: 1, perPage: 0, total: 0,
        ),
      );
    }

    // Items always live at `data.data`
    final rawItems = envelope['data'];
    final List<T> items = rawItems is List
        ? rawItems
            .whereType<Map<String, dynamic>>()
            .map(itemMapper)
            .toList()
        : [];

    // Meta: prefer `data.meta` (PaginateResource), fall back to `data` itself (raw paginator)
    final metaSource = envelope['meta'] is Map<String, dynamic>
        ? envelope['meta'] as Map<String, dynamic>
        : envelope;

    return PaginatedResponse(
      items: items,
      meta: PaginationMeta.fromJson(metaSource),
    );
  }
}
