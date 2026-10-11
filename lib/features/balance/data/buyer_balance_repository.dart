import 'package:blukios_marketplace/config/api_config.dart';
import 'package:blukios_marketplace/core/network/api_client.dart';
import 'package:blukios_marketplace/features/balance/models/buyer_balance_model.dart';

class BuyerBalanceRepository {
  final ApiClient _apiClient;

  BuyerBalanceRepository(this._apiClient);

  /// Throws an ApiException with statusCode 403 when the account has no
  /// buyer profile. The API caps [perPage] at 50.
  Future<BuyerBalancePage> getBalance({int page = 1, int perPage = 20}) async {
    final response = await _apiClient.get(
      ApiConfig.buyerBalance,
      queryParameters: {'page': page, 'per_page': perPage},
    );
    return BuyerBalancePage.fromJson(response.data['data'] as Map<String, dynamic>);
  }
}
