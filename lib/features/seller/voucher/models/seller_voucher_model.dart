import 'package:blukios_marketplace/core/utils/json.dart';

/// Coerces a nullable numeric API field (num or numeric string) to
/// [double], or null when absent — mirrors the pattern used by
/// `AddressModel.latitude`/`longitude` for other nullable money-ish fields.
double? _asDoubleOrNull(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v);
  return null;
}

int? _asIntOrNull(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v);
  return null;
}

/// `VoucherResource` — a seller-owned discount code. `type` is one of
/// `fixed` (flat rupiah amount off) or `percentage` (percent off, capped
/// by [maxDiscount] when set).
class SellerVoucherModel {
  final String id;
  final String code;
  final String storeId;
  final String type;
  final double value;
  final double? minPurchase;
  final double? maxDiscount;
  final int? usageLimit;
  final int? usageLimitPerBuyer;
  final int redeemedCount;
  final DateTime? startsAt;
  final DateTime? expiresAt;
  final bool isActive;
  final String? createdAt;

  const SellerVoucherModel({
    required this.id,
    required this.code,
    required this.storeId,
    required this.type,
    required this.value,
    this.minPurchase,
    this.maxDiscount,
    this.usageLimit,
    this.usageLimitPerBuyer,
    this.redeemedCount = 0,
    this.startsAt,
    this.expiresAt,
    this.isActive = true,
    this.createdAt,
  });

  bool get isPercentage => type == 'percentage';
  bool get isFixed => type == 'fixed';

  bool get isExpired =>
      expiresAt != null && expiresAt!.isBefore(DateTime.now());

  factory SellerVoucherModel.fromJson(Map<String, dynamic> json) {
    return SellerVoucherModel(
      id: json.asString('id'),
      code: json.asString('code'),
      storeId: json.asString('store_id'),
      type: json.asString('type'),
      value: json.asDouble('value'),
      minPurchase: _asDoubleOrNull(json['min_purchase']),
      maxDiscount: _asDoubleOrNull(json['max_discount']),
      usageLimit: _asIntOrNull(json['usage_limit']),
      usageLimitPerBuyer: _asIntOrNull(json['usage_limit_per_buyer']),
      redeemedCount: json.asInt('redeemed_count'),
      startsAt: json['starts_at'] != null
          ? DateTime.tryParse(json['starts_at'].toString())
          : null,
      expiresAt: json['expires_at'] != null
          ? DateTime.tryParse(json['expires_at'].toString())
          : null,
      isActive: json.asBool('is_active', true),
      createdAt: json.asStringOrNull('created_at'),
    );
  }
}
