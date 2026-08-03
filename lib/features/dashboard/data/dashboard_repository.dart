import 'package:blukios_marketplace/config/api_config.dart';
import 'package:blukios_marketplace/core/network/api_client.dart';
import 'package:blukios_marketplace/core/utils/json.dart';

class DashboardChartPoint {
  final String date;
  final int total; // spend for that day
  final int transactionCount;

  DashboardChartPoint({
    required this.date,
    required this.total,
    required this.transactionCount,
  });

  factory DashboardChartPoint.fromJson(Map<String, dynamic> json) {
    return DashboardChartPoint(
      date: json.asString('date'),
      // Named total_revenue server-side even in buyer mode, where it
      // actually means spend.
      total: json.asInt('total_revenue'),
      transactionCount: json.asInt('total_transaction'),
    );
  }
}

class BuyerSummary {
  final double totalExpense;
  final Map<String, int> statusBreakdown;
  final List<DashboardChartPoint> chart;

  BuyerSummary({
    required this.totalExpense,
    required this.statusBreakdown,
    required this.chart,
  });

  int get totalOrders =>
      statusBreakdown.values.fold<int>(0, (sum, count) => sum + count);

  factory BuyerSummary.fromJson(Map<String, dynamic> json) {
    final rawBreakdown = json['status_breakdown'];
    final rawChart = json['chart'];

    return BuyerSummary(
      totalExpense: json.asDouble('total_expense'),
      statusBreakdown: rawBreakdown is Map
          ? rawBreakdown.map(
              (key, value) => MapEntry(
                key.toString(),
                value is num ? value.toInt() : 0,
              ),
            )
          : const {},
      chart: rawChart is List
          ? rawChart
              .whereType<Map<String, dynamic>>()
              .map(DashboardChartPoint.fromJson)
              .toList()
          : const [],
    );
  }
}

class DashboardRepository {
  final ApiClient _apiClient;

  DashboardRepository(this._apiClient);

  /// [days] must be 7, 30 or 90 — the API silently coerces anything else
  /// to 7, so passing an unsupported value fails quietly.
  Future<BuyerSummary> getBuyerSummary({int days = 7}) async {
    final response = await _apiClient.get(
      ApiConfig.buyerDashboard,
      queryParameters: {'days': days},
    );
    return BuyerSummary.fromJson(response.data['data'] as Map<String, dynamic>);
  }
}
