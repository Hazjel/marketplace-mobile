import 'package:blukios_marketplace/config/api_config.dart';
import 'package:blukios_marketplace/core/network/api_client.dart';
import 'package:blukios_marketplace/features/seller/dashboard/models/seller_dashboard_model.dart';

class SellerDashboardRepository {
  final ApiClient _apiClient;

  SellerDashboardRepository(this._apiClient);

  /// [days] must be 7, 30 or 90 — the API silently coerces anything else
  /// to 7, so passing an unsupported value fails quietly.
  Future<SellerDashboardSummary> getSummary({int days = 7}) async {
    final response = await _apiClient.get(
      ApiConfig.sellerDashboard,
      queryParameters: {'days': days},
    );
    return SellerDashboardSummary.fromJson(
      response.data['data'] as Map<String, dynamic>,
    );
  }
}
