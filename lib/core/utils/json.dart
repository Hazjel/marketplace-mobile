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
    // int.tryParse() gagal untuk string berdesimal seperti "150000.00" --
    // itu persis bentuk Laravel decimal-cast fields (mis. harga varian
    // produk, ProductVariantMongo::price cast 'decimal:2') sebelum ada
    // normalisasi eksplisit di resource-nya. double.tryParse() menerima
    // keduanya ("7" dan "150000.00"), fallback tetap sama kalau memang
    // bukan angka sama sekali.
    if (v is String) return double.tryParse(v)?.round() ?? fallback;
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

  /// Strict parser for an API field the Sprint C1 money contract
  /// (`api-blue/docs/money-json-contract.md`) guarantees is a JSON
  /// integer -- product/variant price, transaction money fields, a fixed
  /// voucher's rupiah fields. Throws [FormatException] instead of
  /// silently defaulting to 0: a missing, fractional, or **float-typed**
  /// value there is a contract violation and must surface, not display as
  /// a wrong/zero amount. Only an actual Dart `int` is accepted -- a
  /// whole-valued `double` (`150000.0`) is rejected too, since the
  /// contract is "JSON integer, never float" and silently coercing it
  /// would mask a backend wire-format regression.
  int moneyInt(String key) {
    final v = this[key];
    if (v is int) return v;
    throw FormatException(
      'Expected integer money field "$key" per money-json-contract.md, got: $v (${v.runtimeType})',
    );
  }

  /// [moneyInt], but returns null when [key] is absent or JSON `null` --
  /// for optional integer-money fields (a voucher's `min_purchase`/
  /// `max_discount`). Still throws if the key is present with a
  /// non-integer value.
  int? moneyIntOrNull(String key) {
    if (this[key] == null) return null;
    return moneyInt(key);
  }

  /// Strict numeric parser for a money-ish field that is a decimal rate,
  /// not whole rupiah (a percentage voucher's `value`, e.g. `10.5`).
  /// Throws instead of silently defaulting to 0 -- a malformed value must
  /// not render as a free/zero-value voucher. For a field the contract
  /// says is whole rupiah, use [moneyInt] instead.
  double moneyNum(String key) {
    final v = this[key];
    if (v is num) return v.toDouble();
    throw FormatException(
      'Expected numeric money field "$key" per money-json-contract.md, got: $v (${v.runtimeType})',
    );
  }
}
