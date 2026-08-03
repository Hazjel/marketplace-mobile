import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:blukios_marketplace/core/providers.dart';
import 'package:blukios_marketplace/features/dashboard/data/dashboard_repository.dart';

final dashboardRepositoryProvider = Provider<DashboardRepository>(
  (ref) => DashboardRepository(ref.watch(apiClientProvider)),
);

class DashboardData {
  final BuyerSummary? summary;
  final int days;
  final bool isLoading;
  final String? error;

  const DashboardData({
    this.summary,
    this.days = 7,
    this.isLoading = true,
    this.error,
  });

  DashboardData copyWith({
    BuyerSummary? summary,
    int? days,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return DashboardData(
      summary: summary ?? this.summary,
      days: days ?? this.days,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class DashboardNotifier extends Notifier<DashboardData> {
  @override
  DashboardData build() => const DashboardData();

  Future<void> load({int? days}) async {
    final range = days ?? state.days;
    state = state.copyWith(days: range, isLoading: true, clearError: true);

    try {
      final summary = await ref
          .read(dashboardRepositoryProvider)
          .getBuyerSummary(days: range);
      state = state.copyWith(summary: summary, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}

final dashboardProvider =
    NotifierProvider<DashboardNotifier, DashboardData>(DashboardNotifier.new);
