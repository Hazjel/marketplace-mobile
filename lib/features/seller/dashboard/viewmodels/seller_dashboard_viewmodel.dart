import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:blukios_marketplace/core/network/api_exceptions.dart';
import 'package:blukios_marketplace/core/providers.dart';
import 'package:blukios_marketplace/features/seller/dashboard/models/seller_dashboard_model.dart';

class SellerDashboardData {
  final SellerDashboardSummary? summary;
  final int days;
  final bool isLoading;
  final String? error;

  const SellerDashboardData({
    this.summary,
    this.days = 7,
    this.isLoading = true,
    this.error,
  });

  SellerDashboardData copyWith({
    SellerDashboardSummary? summary,
    int? days,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return SellerDashboardData(
      summary: summary ?? this.summary,
      days: days ?? this.days,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class SellerDashboardNotifier extends Notifier<SellerDashboardData> {
  @override
  SellerDashboardData build() => const SellerDashboardData();

  Future<void> load({int? days}) async {
    final range = days ?? state.days;
    state = state.copyWith(days: range, isLoading: true, clearError: true);

    try {
      final summary = await ref
          .read(sellerDashboardRepositoryProvider)
          .getSummary(days: range);
      state = state.copyWith(summary: summary, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e is ValidationException ? e.firstError : e.toString(),
      );
    }
  }
}

final sellerDashboardProvider =
    NotifierProvider<SellerDashboardNotifier, SellerDashboardData>(
  SellerDashboardNotifier.new,
);
