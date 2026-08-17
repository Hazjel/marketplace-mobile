import 'package:blukios_marketplace/core/utils/json.dart';
import 'package:blukios_marketplace/features/home/models/product_model.dart';

/// One point of the seller revenue time series.
///
/// Same shape as the buyer dashboard's chart point (`total_revenue` /
/// `total_transaction`), kept as its own type here so this feature doesn't
/// reach into `lib/features/dashboard/` (buyer-only).
class SellerChartPoint {
  final String date;
  final int total;
  final int transactionCount;

  SellerChartPoint({
    required this.date,
    required this.total,
    required this.transactionCount,
  });

  factory SellerChartPoint.fromJson(Map<String, dynamic> json) {
    return SellerChartPoint(
      date: json.asString('date'),
      total: json.asInt('total_revenue'),
      transactionCount: json.asInt('total_transaction'),
    );
  }
}

/// A single week-over-week percentage change, e.g. `{ value: 12.5, direction: "up" }`.
class TrendValue {
  final double value;
  final String direction;

  TrendValue({required this.value, required this.direction});

  bool get isUp => direction == 'up';

  factory TrendValue.fromJson(Map<String, dynamic> json) {
    return TrendValue(
      value: json.asDouble('value'),
      direction: json.asString('direction'),
    );
  }
}

/// Week-over-week trend for revenue and order count.
///
/// Both fields are nullable — the API returns `null` for the whole `trend`
/// object (no store) or for an individual metric when there's no prior-week
/// baseline to compare against.
class SellerTrend {
  final TrendValue? revenue;
  final TrendValue? orders;

  SellerTrend({this.revenue, this.orders});

  factory SellerTrend.fromJson(dynamic json) {
    if (json is! Map<String, dynamic>) return SellerTrend();

    final rev = json['revenue'];
    final ord = json['orders'];
    return SellerTrend(
      revenue: rev is Map<String, dynamic> ? TrendValue.fromJson(rev) : null,
      orders: ord is Map<String, dynamic> ? TrendValue.fromJson(ord) : null,
    );
  }
}

class SellerDashboardSummary {
  final double balance;
  final double pendingBalance;
  final int totalOrders;
  final Map<String, int> statusBreakdown;
  final int totalReviews;
  final double averageRating;
  final int totalProducts;
  final List<ProductModel> topProducts;
  final List<SellerChartPoint> chart;
  final SellerTrend trend;

  SellerDashboardSummary({
    required this.balance,
    required this.pendingBalance,
    required this.totalOrders,
    required this.statusBreakdown,
    required this.totalReviews,
    required this.averageRating,
    required this.totalProducts,
    required this.topProducts,
    required this.chart,
    required this.trend,
  });

  factory SellerDashboardSummary.fromJson(Map<String, dynamic> json) {
    final rawBreakdown = json['status_breakdown'];
    final rawChart = json['chart'];
    final rawTopProducts = json['top_products'];

    return SellerDashboardSummary(
      balance: json.asDouble('balance'),
      pendingBalance: json.asDouble('pending_balance'),
      totalOrders: json.asInt('total_orders'),
      statusBreakdown: rawBreakdown is Map
          ? rawBreakdown.map(
              (key, value) => MapEntry(
                key.toString(),
                value is num ? value.toInt() : 0,
              ),
            )
          : const {},
      totalReviews: json.asInt('total_reviews'),
      averageRating: json.asDouble('average_rating'),
      totalProducts: json.asInt('total_products'),
      topProducts: rawTopProducts is List
          ? rawTopProducts
              .whereType<Map<String, dynamic>>()
              .map(ProductModel.fromJson)
              .toList()
          : const [],
      chart: rawChart is List
          ? rawChart
              .whereType<Map<String, dynamic>>()
              .map(SellerChartPoint.fromJson)
              .toList()
          : const [],
      trend: SellerTrend.fromJson(json['trend']),
    );
  }
}
