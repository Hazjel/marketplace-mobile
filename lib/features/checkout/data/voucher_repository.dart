import 'package:blukios_marketplace/config/api_config.dart';
import 'package:blukios_marketplace/core/network/api_client.dart';
import 'package:blukios_marketplace/features/checkout/models/voucher_model.dart';

class VoucherRepository {
  final ApiClient _apiClient;

  VoucherRepository(this._apiClient);

  /// Preview-validates a code against a store + subtotal. Throws
  /// [ApiException] (via [ApiClient]) with the backend's specific reason
  /// (e.g. "Minimal belanja Rp...") on 404/422 — callers should show that
  /// message directly, not a generic "kode tidak valid".
  ///
  /// This is a preview only — it does not redeem the voucher. The actual
  /// redemption happens atomically server-side at checkout, so a valid
  /// preview here can still be rejected at submit time (e.g. someone else
  /// exhausted the usage limit in between).
  Future<VoucherModel> validateVoucher({
    required String code,
    required String storeId,
    required double subtotal,
  }) async {
    final response = await _apiClient.post(
      ApiConfig.voucherValidate,
      data: {
        'code': code,
        'store_id': storeId,
        'subtotal': subtotal,
      },
    );
    return VoucherModel.fromJson(response.data['data']);
  }
}
