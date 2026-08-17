import 'package:blukios_marketplace/config/api_config.dart';
import 'package:blukios_marketplace/core/network/api_client.dart';
import 'package:blukios_marketplace/features/seller/wallet/models/seller_wallet_model.dart';

class SellerWalletRepository {
  final ApiClient _apiClient;

  SellerWalletRepository(this._apiClient);

  /// Returns null when the store has no balance record yet — the API
  /// responds `{ success: true, data: null }` (200) in that case rather
  /// than a 404.
  Future<StoreBalanceModel?> getMyBalance() async {
    final response = await _apiClient.get(ApiConfig.myStoreBalance);
    final data = response.data['data'];
    if (data is! Map<String, dynamic>) return null;
    return StoreBalanceModel.fromJson(data);
  }

  Future<List<StoreBalanceHistoryModel>> getHistory({
    int page = 1,
    int rowPerPage = 10,
  }) async {
    final response = await _apiClient.get(
      ApiConfig.storeBalanceHistoryPaginated,
      queryParameters: {
        'page': page,
        // Required by the API — omitting it returns a 422.
        'row_per_page': rowPerPage,
      },
    );

    final List data = response.data['data']['data'] ?? response.data['data'];
    return data.map((e) => StoreBalanceHistoryModel.fromJson(e)).toList();
  }

  Future<List<WithdrawalModel>> getWithdrawals({
    int page = 1,
    int rowPerPage = 10,
  }) async {
    final response = await _apiClient.get(
      ApiConfig.withdrawalPaginated,
      queryParameters: {
        'page': page,
        'row_per_page': rowPerPage,
      },
    );

    final List data = response.data['data']['data'] ?? response.data['data'];
    return data.map((e) => WithdrawalModel.fromJson(e)).toList();
  }

  Future<WithdrawalModel> requestWithdrawal({
    required String storeBalanceId,
    required double amount,
    required String bankAccountName,
    required String bankAccountNumber,
    required String bankName,
  }) async {
    final response = await _apiClient.post(
      ApiConfig.withdrawal,
      data: {
        'store_balance_id': storeBalanceId,
        'amount': amount,
        'bank_account_name': bankAccountName,
        'bank_account_number': bankAccountNumber,
        'bank_name': bankName,
      },
    );
    return WithdrawalModel.fromJson(response.data['data'] as Map<String, dynamic>);
  }
}
