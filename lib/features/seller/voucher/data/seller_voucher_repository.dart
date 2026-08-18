import 'package:blukios_marketplace/config/api_config.dart';
import 'package:blukios_marketplace/core/network/api_client.dart';
import 'package:blukios_marketplace/features/seller/voucher/models/seller_voucher_model.dart';

class SellerVoucherRepository {
  final ApiClient _apiClient;

  SellerVoucherRepository(this._apiClient);

  Future<List<SellerVoucherModel>> list() async {
    final response = await _apiClient.get(ApiConfig.sellerVouchers);
    final List data = response.data['data'] ?? [];
    return data
        .whereType<Map<String, dynamic>>()
        .map(SellerVoucherModel.fromJson)
        .toList();
  }

  Future<SellerVoucherModel> create({
    required String code,
    required String type,
    required double value,
    double? minPurchase,
    double? maxDiscount,
    int? usageLimit,
    int? usageLimitPerBuyer,
    DateTime? startsAt,
    DateTime? expiresAt,
    bool? isActive,
  }) async {
    final response = await _apiClient.post(
      ApiConfig.sellerVouchers,
      data: _buildBody(
        code: code,
        type: type,
        value: value,
        minPurchase: minPurchase,
        maxDiscount: maxDiscount,
        usageLimit: usageLimit,
        usageLimitPerBuyer: usageLimitPerBuyer,
        startsAt: startsAt,
        expiresAt: expiresAt,
        isActive: isActive,
      ),
    );
    return SellerVoucherModel.fromJson(
      response.data['data'] as Map<String, dynamic>,
    );
  }

  Future<SellerVoucherModel> update(
    String id, {
    required String code,
    required String type,
    required double value,
    double? minPurchase,
    double? maxDiscount,
    int? usageLimit,
    int? usageLimitPerBuyer,
    DateTime? startsAt,
    DateTime? expiresAt,
    bool? isActive,
  }) async {
    final response = await _apiClient.put(
      ApiConfig.sellerVoucherById(id),
      data: _buildBody(
        code: code,
        type: type,
        value: value,
        minPurchase: minPurchase,
        maxDiscount: maxDiscount,
        usageLimit: usageLimit,
        usageLimitPerBuyer: usageLimitPerBuyer,
        startsAt: startsAt,
        expiresAt: expiresAt,
        isActive: isActive,
      ),
    );
    return SellerVoucherModel.fromJson(
      response.data['data'] as Map<String, dynamic>,
    );
  }

  /// Throws [ApiException]/[ValidationException] (via [ApiClient]) — a
  /// voucher with redemption history comes back as a 422 whose `message`
  /// is already a complete, user-facing sentence telling the seller to
  /// deactivate instead of delete.
  Future<void> delete(String id) async {
    await _apiClient.delete(ApiConfig.sellerVoucherById(id));
  }

  Map<String, dynamic> _buildBody({
    required String code,
    required String type,
    required double value,
    double? minPurchase,
    double? maxDiscount,
    int? usageLimit,
    int? usageLimitPerBuyer,
    DateTime? startsAt,
    DateTime? expiresAt,
    bool? isActive,
  }) {
    return {
      'code': code,
      'type': type,
      'value': value,
      if (minPurchase != null) 'min_purchase': minPurchase,
      if (maxDiscount != null) 'max_discount': maxDiscount,
      if (usageLimit != null) 'usage_limit': usageLimit,
      if (usageLimitPerBuyer != null)
        'usage_limit_per_buyer': usageLimitPerBuyer,
      if (startsAt != null) 'starts_at': startsAt.toIso8601String(),
      if (expiresAt != null) 'expires_at': expiresAt.toIso8601String(),
      if (isActive != null) 'is_active': isActive,
    };
  }
}
