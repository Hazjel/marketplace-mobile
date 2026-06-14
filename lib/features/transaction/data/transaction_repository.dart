import 'package:blukios_marketplace/config/api_config.dart';
import 'package:blukios_marketplace/core/network/api_client.dart';
import 'package:blukios_marketplace/features/transaction/models/transaction_model.dart';

class TransactionRepository {
  final ApiClient _apiClient;

  TransactionRepository(this._apiClient);

  Future<List<TransactionModel>> getTransactions({int page = 1, String? status}) async {
    final response = await _apiClient.get(
      ApiConfig.transactionsPaginated,
      queryParameters: {
        'page': page,
        if (status != null) 'status': status,
      },
    );

    final List data = response.data['data']['data'] ?? response.data['data'];
    return data.map((e) => TransactionModel.fromJson(e)).toList();
  }

  Future<TransactionModel> getTransactionDetail(int id) async {
    final response = await _apiClient.get('${ApiConfig.transactions}/$id');
    return TransactionModel.fromJson(response.data['data']);
  }

  Future<TransactionModel> createTransaction({
    required List<int> cartIds,
    required String shippingMethod,
    required int addressId,
  }) async {
    final response = await _apiClient.post(ApiConfig.transactions, data: {
      'cart_ids': cartIds,
      'shipping_method': shippingMethod,
      'address_id': addressId,
    });
    return TransactionModel.fromJson(response.data['data']);
  }
}
