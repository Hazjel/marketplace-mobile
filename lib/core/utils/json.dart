/// Defensive JSON value extractors.
///
/// The API returns numeric fields as int, double, or string depending on
/// serialization context and database driver quirks. These helpers
/// normalize to the expected Dart type without throwing.
library;

extension JsonCast on Map<String, dynamic> {
  /// Returns [key] as [int], coercing from num/String.
  /// Falls back to [fallback] when absent, null, or unparseable.
  int asInt(String key, [int fallback = 0]) {
    final v = this[key];
    if (v == null) return fallback;
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? fallback;
    return fallback;
  }

  /// Returns [key] as [double], coercing from num/String.
  double asDouble(String key, [double fallback = 0.0]) {
    final v = this[key];
    if (v == null) return fallback;
    if (v is double) return v;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? fallback;
    return fallback;
  }

  /// Returns [key] as [String]. Non-string primitives are `.toString()`-ed.
  String asString(String key, [String fallback = '']) {
    final v = this[key];
    if (v == null) return fallback;
    if (v is String) return v;
    return v.toString();
  }

  /// Returns [key] as [bool]. Accepts `1`, `'1'`, `'true'` as truthy.
  bool asBool(String key, [bool fallback = false]) {
    final v = this[key];
    if (v == null) return fallback;
    if (v is bool) return v;
    if (v is num) return v != 0;
    if (v is String) return v == '1' || v.toLowerCase() == 'true';
    return fallback;
  }

  /// Returns [key] as nullable [String], or null when absent/null.
  String? asStringOrNull(String key) {
    final v = this[key];
    if (v == null) return null;
    if (v is String) return v;
    return v.toString();
  }
}
