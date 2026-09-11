import 'package:blukios_marketplace/core/utils/json.dart';

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
    final type = json.asString('type');
    return SellerVoucherModel(
      id: json.asString('id'),
      code: json.asString('code'),
      storeId: json.asString('store_id'),
      type: type,
      // fixed: whole rupiah, JSON integer -- percentage: a decimal rate
      // (e.g. 10.5), never narrowed. money-json-contract.md's `value` is
      // conditional on `type`, so the parser has to be too: moneyNum alone
      // would let a fixed voucher's value regress to a fractional rupiah
      // amount (e.g. 20000.5) without ever throwing.
      value: type == 'fixed' ? json.moneyInt('value').toDouble() : json.moneyNum('value'),
      minPurchase: json.moneyIntOrNull('min_purchase')?.toDouble(),
      maxDiscount: json.moneyIntOrNull('max_discount')?.toDouble(),
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
