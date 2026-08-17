import 'package:dio/dio.dart';
import 'package:blukios_marketplace/config/api_config.dart';
import 'package:blukios_marketplace/core/network/api_client.dart';
import 'package:blukios_marketplace/core/utils/idempotency_key.dart';
import 'package:blukios_marketplace/features/transaction/models/transaction_model.dart';

class TransactionRepository {
  final ApiClient _apiClient;

  TransactionRepository(this._apiClient);

  Future<List<TransactionModel>> getTransactions({
    int page = 1,
    String? status,
    int rowPerPage = 10,
    // Optional scoping context, forwarded as `?mode=`. The API's
    // TransactionRepository::scopeToMode() reads this to decide whether the
    // paginated list is scoped to the caller's buyer_id or store_id — a user
    // can be dual-role buyer+store (like Shopee), so without it the backend
    // can't tell which context is being asked for. Pass 'store' for the
    // seller order list; leave null for the existing buyer call sites (their
    // behavior is unchanged).
    String? mode,
  }) async {
    final response = await _apiClient.get(
      ApiConfig.transactionsPaginated,
      queryParameters: {
        'page': page,
        // Required by the API — omitting it returns a 422 "Validasi gagal".
        'row_per_page': rowPerPage,
        if (status != null) 'status': status,
        if (mode != null) 'mode': mode,
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

  /// Updates delivery status / tracking number — `PUT /transaction/{id}`.
  ///
  /// [deliveryStatus] must be one of `processing`, `delivering`,
  /// `completed` per `TransactionUpdateRequest`. Callers on the seller side
  /// should only ever pass `processing` or `delivering` here — `completed`
  /// is deliberately reserved for the buyer-only `POST /transaction/{id}/complete`
  /// endpoint, which also releases escrow funds to the store. Letting the
  /// seller set `completed` through this endpoint would let them mark their
  /// own order as received and short-circuit that release flow, so the
  /// seller UI intentionally never offers it as an option here.
  Future<TransactionModel> updateDeliveryStatus({
    required String id,
    required String deliveryStatus,
    String? trackingNumber,
    String? deliveryProofPath,
  }) async {
    final dynamic data = deliveryProofPath != null
        ? FormData.fromMap({
            'delivery_status': deliveryStatus,
            if (trackingNumber != null) 'tracking_number': trackingNumber,
            'delivery_proof': await MultipartFile.fromFile(deliveryProofPath),
            // Laravel doesn't parse multipart PUT bodies — spoof method
            // via POST, same trick the web app relies on for this route.
            '_method': 'PUT',
          })
        : {
            'delivery_status': deliveryStatus,
            if (trackingNumber != null) 'tracking_number': trackingNumber,
          };

    final response = deliveryProofPath != null
        ? await _apiClient.post('${ApiConfig.transactions}/$id', data: data)
        : await _apiClient.put('${ApiConfig.transactions}/$id', data: data);

    return TransactionModel.fromJson(response.data['data']);
  }
}
