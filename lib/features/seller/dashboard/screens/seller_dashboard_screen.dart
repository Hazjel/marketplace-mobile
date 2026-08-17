import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:blukios_marketplace/config/app_theme.dart';
import 'package:blukios_marketplace/core/utils/currency_formatter.dart';
import 'package:blukios_marketplace/features/home/models/product_model.dart';
import 'package:blukios_marketplace/features/seller/dashboard/models/seller_dashboard_model.dart';
import 'package:blukios_marketplace/features/seller/dashboard/viewmodels/seller_dashboard_viewmodel.dart';
import 'package:blukios_marketplace/shared/widgets/app_icon.dart';
import 'package:blukios_marketplace/shared/widgets/app_scaffold.dart';
import 'package:blukios_marketplace/shared/widgets/state_views.dart';

/// Indonesian labels for the API's status keys. The API combines
/// `payment_status` and `delivery_status` counts into one map, so both
/// sets of keys are covered here.
const _statusLabels = <String, String>{
  'unpaid': 'Belum Bayar',
  'paid': 'Dibayar',
  'failed': 'Gagal',
  'pending': 'Menunggu',
  'shipping': 'Dikirim',
  'delivering': 'Dalam Perjalanan',
  'delivered': 'Diterima',
  'completed': 'Selesai',
  'cancelled': 'Dibatalkan',
};

class SellerDashboardScreen extends ConsumerStatefulWidget {
  const SellerDashboardScreen({super.key});

  @override
  ConsumerState<SellerDashboardScreen> createState() =>
      _SellerDashboardScreenState();
}

class _SellerDashboardScreenState
    extends ConsumerState<SellerDashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(sellerDashboardProvider.notifier).load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(sellerDashboardProvider);
    final notifier = ref.read(sellerDashboardProvider.notifier);

    return AppScaffold(
      title: 'Dashboard Toko',
      body: state.isLoading && state.summary == null
          ? const Center(child: CircularProgressIndicator())
          : state.error != null && state.summary == null
              ? ErrorState(message: state.error!, onRetry: notifier.load)
              : RefreshIndicator(
                  onRefresh: notifier.load,
                  child: ListView(
                    padding: const EdgeInsets.all(AppTheme.spacingLG),
                    children: [
                      _BalanceCard(summary: state.summary!),
                      const SizedBox(height: AppTheme.spacingLG),
                      _StatRow(summary: state.summary!),
                      const SizedBox(height: AppTheme.spacingLG),
                      _RangeSelector(
                        selected: state.days,
                        onSelect: (days) => notifier.load(days: days),
                      ),
                      const SizedBox(height: AppTheme.spacingLG),
                      _RevenueChart(chart: state.summary!.chart),
                      const SizedBox(height: AppTheme.spacingLG),
                      _StatusBreakdown(summary: state.summary!),
                      const SizedBox(height: AppTheme.spacingLG),
                      _TopProducts(products: state.summary!.topProducts),
                    ],
                  ),
                ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  final SellerDashboardSummary summary;

  const _BalanceCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingLG),
      decoration: BoxDecoration(
        gradient: AppTheme.blukiosGradient,
        borderRadius: BorderRadius.circular(AppTheme.radius2XL),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Saldo Toko',
                      style: AppTheme.labelMd.copyWith(color: Colors.white70),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      CurrencyFormatter.formatRupiah(summary.balance),
                      style: AppTheme.priceLg.copyWith(color: Colors.white),
                    ),
                  ],
                ),
              ),
              const AppIcon(AppIcons.wallet, size: 44, color: Colors.white24),
            ],
          ),
          if (summary.pendingBalance > 0) ...[
            const SizedBox(height: AppTheme.spacingMD),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacingMD,
                vertical: AppTheme.spacingSM,
              ),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppTheme.radiusLG),
              ),
              child: Row(
                children: [
                  const AppIcon(
                    AppIcons.alert,
                    size: AppIconSize.sm,
                    color: Colors.white,
                  ),
                  const SizedBox(width: AppTheme.spacingSM),
                  Expanded(
                    child: Text(
                      '${CurrencyFormatter.formatRupiah(summary.pendingBalance)} tertahan (escrow)',
                      style: AppTheme.labelSm.copyWith(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final SellerDashboardSummary summary;

  const _StatRow({required this.summary});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatTile(
            label: 'Pesanan',
            value: '${summary.totalOrders}',
            trend: summary.trend.orders,
          ),
        ),
        const SizedBox(width: AppTheme.spacingSM),
        Expanded(
          child: _StatTile(
            label: 'Produk',
            value: '${summary.totalProducts}',
          ),
        ),
        const SizedBox(width: AppTheme.spacingSM),
        Expanded(
          child: _StatTile(
            label: 'Rating',
            value: summary.totalReviews > 0
                ? summary.averageRating.toStringAsFixed(1)
                : '-',
            sub: '${summary.totalReviews} ulasan',
          ),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final String? sub;
  final TrendValue? trend;

  const _StatTile({
    required this.label,
    required this.value,
    this.sub,
    this.trend,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary;

    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingMD),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : AppTheme.cardWhite,
        borderRadius: BorderRadius.circular(AppTheme.radius2XL),
        border: Border.all(
          color: isDark ? AppTheme.darkBorder : AppTheme.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: AppTheme.labelSm.copyWith(color: muted)),
          const SizedBox(height: 4),
          Text(value, style: AppTheme.titleMd),
          if (sub != null)
            Text(sub!, style: AppTheme.labelSm.copyWith(color: muted)),
          if (trend != null) ...[
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppIcon(
                  trend!.isUp ? AppIcons.plus : AppIcons.close,
                  size: AppIconSize.sm,
                  color: trend!.isUp ? AppTheme.success : AppTheme.error,
                ),
                Text(
                  '${trend!.value}%',
                  style: AppTheme.labelSm.copyWith(
                    color: trend!.isUp ? AppTheme.success : AppTheme.error,
                  ),
                ),
              ],
            ),
          ],
        ],
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

/// Lightweight bar chart. Deliberately hand-drawn rather than pulling in
/// a charting dependency for one screen — mirrors the buyer dashboard.
class _RevenueChart extends StatelessWidget {
  final List<SellerChartPoint> chart;

  const _RevenueChart({required this.chart});

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
          Text('Pendapatan Harian', style: AppTheme.titleMd),
          const SizedBox(height: AppTheme.spacingLG),
          if (maxValue == 0)
            SizedBox(
              height: 60,
              child: Center(
                child: Text(
                  'Belum ada pendapatan di periode ini',
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
  final SellerDashboardSummary summary;

  const _StatusBreakdown({required this.summary});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary;

    // Hide zero-count statuses — showing a wall of "0" rows is noise.
    final entries =
        summary.statusBreakdown.entries.where((e) => e.value > 0).toList();

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

class _TopProducts extends StatelessWidget {
  final List<ProductModel> products;

  const _TopProducts({required this.products});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary;

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
          Text('Produk Terlaris', style: AppTheme.titleMd),
          const SizedBox(height: AppTheme.spacingMD),
          if (products.isEmpty)
            Text(
              'Belum ada produk terjual',
              style: AppTheme.bodySm.copyWith(color: muted),
            )
          else
            for (var i = 0; i < products.length; i++)
              Padding(
                padding: EdgeInsets.only(
                  bottom: i == products.length - 1 ? 0 : AppTheme.spacingMD,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppTheme.darkIconBackground
                            : AppTheme.iconBackground,
                        shape: BoxShape.circle,
                      ),
                      child: Text('${i + 1}', style: AppTheme.labelMd),
                    ),
                    const SizedBox(width: AppTheme.spacingMD),
                    Expanded(
                      child: Text(
                        products[i].name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTheme.bodyMd,
                      ),
                    ),
                    const SizedBox(width: AppTheme.spacingSM),
                    Text(
                      '${products[i].totalSold} terjual',
                      style: AppTheme.labelSm.copyWith(color: muted),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}
