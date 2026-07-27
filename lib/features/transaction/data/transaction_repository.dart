import 'package:blukios_marketplace/config/api_config.dart';
import 'package:blukios_marketplace/core/network/api_client.dart';
import 'package:blukios_marketplace/core/utils/idempotency_key.dart';
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

  Future<TransactionModel> getTransactionDetail(String id) async {
    final response = await _apiClient.get('${ApiConfig.transactions}/$id');
    return TransactionModel.fromJson(response.data['data']);
  }

  Future<TransactionModel> getTransactionByCode(String code) async {
    final response = await _apiClient.get('${ApiConfig.transactions}/code/$code');
    return TransactionModel.fromJson(response.data['data']);
  }

  Future<TransactionModel> createTransaction({
    required String buyerId,
    required String storeId,
    required String addressId,
    required String address,
    required String city,
    required String postalCode,
    double? destLatitude,
    double? destLongitude,
    required String shipping,
    required String shippingType,
    required double shippingCost,
    required List<Map<String, dynamic>> products,
  }) async {
    final response = await _apiClient.post(
      ApiConfig.transactions,
      data: {
        'buyer_id': buyerId,
        'store_id': storeId,
        'address_id': addressId,
        'address': address,
        'city': city,
        'postal_code': postalCode,
        'dest_latitude': destLatitude,
        'dest_longitude': destLongitude,
        'shipping': shipping,
        'shipping_type': shippingType,
        'shipping_cost': shippingCost,
        'products': products,
      },
      headers: {'X-Idempotency-Key': IdempotencyKey.generate()},
    );
    return TransactionModel.fromJson(response.data['data']);
  }

  Future<TransactionModel> checkPaymentStatus(String id) async {
    final response = await _apiClient.post(ApiConfig.transactionCheckStatus(id));
    return TransactionModel.fromJson(response.data['data']);
  }
}
