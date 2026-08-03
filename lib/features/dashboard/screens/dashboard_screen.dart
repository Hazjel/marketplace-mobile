import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:blukios_marketplace/config/app_theme.dart';
import 'package:blukios_marketplace/core/utils/currency_formatter.dart';
import 'package:blukios_marketplace/features/dashboard/data/dashboard_repository.dart';
import 'package:blukios_marketplace/features/dashboard/viewmodels/dashboard_viewmodel.dart';
import 'package:blukios_marketplace/shared/widgets/app_icon.dart';
import 'package:blukios_marketplace/shared/widgets/app_scaffold.dart';
import 'package:blukios_marketplace/shared/widgets/state_views.dart';

/// Indonesian labels for the API's status keys.
const _statusLabels = <String, String>{
  'unpaid': 'Belum Bayar',
  'paid': 'Dibayar',
  'pending': 'Menunggu',
  'shipping': 'Dikirim',
  'delivering': 'Dalam Perjalanan',
  'delivered': 'Diterima',
  'completed': 'Selesai',
  'cancelled': 'Dibatalkan',
  'failed': 'Gagal',
};

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(dashboardProvider.notifier).load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(dashboardProvider);
    final notifier = ref.read(dashboardProvider.notifier);

    return AppScaffold(
      title: 'Ringkasan Belanja',
      body: state.isLoading && state.summary == null
          ? const Center(child: CircularProgressIndicator())
          : state.error != null && state.summary == null
              ? ErrorState(message: state.error!, onRetry: notifier.load)
              : RefreshIndicator(
                  onRefresh: notifier.load,
                  child: ListView(
                    padding: const EdgeInsets.all(AppTheme.spacingLG),
                    children: [
                      _RangeSelector(
                        selected: state.days,
                        onSelect: (days) => notifier.load(days: days),
                      ),
                      const SizedBox(height: AppTheme.spacingLG),
                      _ExpenseCard(summary: state.summary!),
                      const SizedBox(height: AppTheme.spacingLG),
                      _SpendChart(chart: state.summary!.chart),
                      const SizedBox(height: AppTheme.spacingLG),
                      _StatusBreakdown(summary: state.summary!),
                    ],
                  ),
                ),
    );
  }
}

class _RangeSelector extends StatelessWidget {
  final int selected;
  final ValueChanged<int> onSelect;

  const _RangeSelector({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    // Only 7/30/90 — any other value is silently coerced to 7 by the API.
    const options = [(7, '7 Hari'), (30, '30 Hari'), (90, '90 Hari')];

    return Row(
      children: [
        for (final (days, label) in options) ...[
          Expanded(
            child: _RangeChip(
              label: label,
              selected: selected == days,
              onTap: () => onSelect(days),
            ),
          ),
          if (days != 90) const SizedBox(width: AppTheme.spacingSM),
        ],
      ],
    );
  }
}

class _RangeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _RangeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final active = isDark ? AppTheme.darkPrimary : AppTheme.primary;

    return Material(
      color: selected ? active : Colors.transparent,
      borderRadius: BorderRadius.circular(AppTheme.radiusFull),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusFull),
        child: Container(
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.radiusFull),
            border: Border.all(
              color: selected
                  ? active
                  : (isDark ? AppTheme.darkBorder : AppTheme.border),
            ),
          ),
          child: Text(
            label,
            style: AppTheme.labelMd.copyWith(
              color: selected
                  ? Colors.white
                  : (isDark
                      ? AppTheme.darkTextSecondary
                      : AppTheme.textSecondary),
            ),
          ),
        ),
      ),
    );
  }
}

class _ExpenseCard extends StatelessWidget {
  final BuyerSummary summary;

  const _ExpenseCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingLG),
      decoration: BoxDecoration(
        gradient: AppTheme.blukiosGradient,
        borderRadius: BorderRadius.circular(AppTheme.radius2XL),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Total Pengeluaran',
                  style: AppTheme.labelMd.copyWith(color: Colors.white70),
                ),
                const SizedBox(height: 4),
                Text(
                  CurrencyFormatter.formatRupiah(summary.totalExpense),
                  style: AppTheme.priceLg.copyWith(color: Colors.white),
                ),
                const SizedBox(height: 4),
                Text(
                  '${summary.totalOrders} pesanan',
                  style: AppTheme.bodySm.copyWith(color: Colors.white70),
                ),
              ],
            ),
          ),
          const AppIcon(AppIcons.wallet, size: 44, color: Colors.white24),
        ],
      ),
    );
  }
}

/// Lightweight bar chart. Deliberately hand-drawn rather than pulling in
/// a charting dependency for one screen.
class _SpendChart extends StatelessWidget {
  final List<DashboardChartPoint> chart;

  const _SpendChart({required this.chart});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary;
    final barColor = isDark ? AppTheme.darkPrimary : AppTheme.primary;

    if (chart.isEmpty) {
      return const SizedBox.shrink();
    }

    final maxValue = chart.fold<int>(0, (max, p) => p.total > max ? p.total : max);

    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingLG),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : AppTheme.cardWhite,
        borderRadius: BorderRadius.circular(AppTheme.radius2XL),
        border: Border.all(
          color: isDark ? AppTheme.darkBorder : AppTheme.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Pengeluaran Harian', style: AppTheme.titleMd),
          const SizedBox(height: AppTheme.spacingLG),
          if (maxValue == 0)
            SizedBox(
              height: 60,
              child: Center(
                child: Text(
                  'Belum ada pengeluaran di periode ini',
                  style: AppTheme.bodySm.copyWith(color: muted),
                ),
              ),
            )
          else
            SizedBox(
              height: 120,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final point in chart)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 1.5),
                        child: Tooltip(
                          message:
                              '${point.date}\n${CurrencyFormatter.formatRupiah(point.total.toDouble())}',
                          child: Container(
                            // Floor of 3px so zero-days stay visible as a
                            // baseline instead of vanishing.
                            height: maxValue == 0
                                ? 3
                                : (point.total / maxValue * 110).clamp(3, 110),
                            decoration: BoxDecoration(
                              color: point.total > 0
                                  ? barColor
                                  : barColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          const SizedBox(height: AppTheme.spacingSM),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                chart.first.date,
                style: AppTheme.labelSm.copyWith(color: muted),
              ),
              Text(
                chart.last.date,
                style: AppTheme.labelSm.copyWith(color: muted),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusBreakdown extends StatelessWidget {
  final BuyerSummary summary;

  const _StatusBreakdown({required this.summary});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary;

    // Hide zero-count statuses — showing nine rows of "0" is noise.
    final entries = summary.statusBreakdown.entries
        .where((e) => e.value > 0)
        .toList();

    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingLG),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : AppTheme.cardWhite,
        borderRadius: BorderRadius.circular(AppTheme.radius2XL),
        border: Border.all(
          color: isDark ? AppTheme.darkBorder : AppTheme.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Status Pesanan', style: AppTheme.titleMd),
          const SizedBox(height: AppTheme.spacingMD),
          if (entries.isEmpty)
            Text(
              'Belum ada pesanan di periode ini',
              style: AppTheme.bodySm.copyWith(color: muted),
            )
          else
            for (final entry in entries)
              Padding(
                padding: const EdgeInsets.only(bottom: AppTheme.spacingSM),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _statusLabels[entry.key] ?? entry.key,
                        style: AppTheme.bodyMd,
                      ),
                    ),
                    Text('${entry.value}', style: AppTheme.titleSm),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}
