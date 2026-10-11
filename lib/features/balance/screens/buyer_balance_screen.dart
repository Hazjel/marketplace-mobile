import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:blukios_marketplace/config/app_theme.dart';
import 'package:blukios_marketplace/core/utils/currency_formatter.dart';
import 'package:blukios_marketplace/core/utils/date_formatter.dart';
import 'package:blukios_marketplace/features/balance/models/buyer_balance_model.dart';
import 'package:blukios_marketplace/features/balance/viewmodels/buyer_balance_viewmodel.dart';
import 'package:blukios_marketplace/shared/widgets/app_icon.dart';
import 'package:blukios_marketplace/shared/widgets/app_scaffold.dart';
import 'package:blukios_marketplace/shared/widgets/state_views.dart';

class BuyerBalanceScreen extends ConsumerStatefulWidget {
  const BuyerBalanceScreen({super.key});

  @override
  ConsumerState<BuyerBalanceScreen> createState() => _BuyerBalanceScreenState();
}

class _BuyerBalanceScreenState extends ConsumerState<BuyerBalanceScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(buyerBalanceProvider.notifier).load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(buyerBalanceProvider);
    final notifier = ref.read(buyerBalanceProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary;

    final Widget body;
    if (state.notBuyer) {
      body = const EmptyState(
        icon: AppIcons.wallet,
        title: 'Saldo Blukios hanya untuk akun pembeli',
      );
    } else if (state.balance == null && state.error != null) {
      body = ErrorState(message: state.error!, onRetry: notifier.load);
    } else if (state.balance == null) {
      body = const Center(child: CircularProgressIndicator());
    } else {
      body = RefreshIndicator(
        onRefresh: notifier.load,
        child: NotificationListener<ScrollNotification>(
          onNotification: (n) {
            if (n.metrics.extentAfter < 200) notifier.loadMore();
            return false;
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(AppTheme.spacingLG),
            children: [
              Container(
                padding: const EdgeInsets.all(AppTheme.spacingLG),
                decoration: BoxDecoration(
                  gradient: AppTheme.blukiosGradient,
                  borderRadius: BorderRadius.circular(AppTheme.radius2XL),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Saldo Blukios',
                        style: AppTheme.bodySm.copyWith(color: Colors.white70)),
                    const SizedBox(height: AppTheme.spacingXS),
                    Text(
                      CurrencyFormatter.formatRupiah(state.balance),
                      style: AppTheme.displayMd.copyWith(color: Colors.white),
                    ),
                    const SizedBox(height: AppTheme.spacingSM),
                    Text(
                      'Dari refund pesanan. Bisa dipakai saat checkout, tidak bisa ditarik.',
                      style: AppTheme.bodySm.copyWith(color: Colors.white70),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppTheme.spacingLG),
              Text('Riwayat', style: AppTheme.titleSm),
              const SizedBox(height: AppTheme.spacingSM),
              if (state.histories.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingXL),
                  child: Text(
                    'Belum ada riwayat saldo',
                    textAlign: TextAlign.center,
                    style: AppTheme.bodyMd.copyWith(color: muted),
                  ),
                ),
              for (final row in state.histories) _HistoryRow(row: row, muted: muted),
              if (state.isLoadingMore)
                const Padding(
                  padding: EdgeInsets.all(AppTheme.spacingMD),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (state.hasMore)
                TextButton(
                  onPressed: notifier.loadMore,
                  child: Text(state.error != null
                      ? 'Gagal memuat. Coba lagi'
                      : 'Muat lebih banyak'),
                ),
            ],
          ),
        ),
      );
    }

    return AppScaffold(title: 'Saldo Blukios', body: body);
  }
}

class _HistoryRow extends StatelessWidget {
  final BuyerBalanceHistory row;
  final Color muted;

  const _HistoryRow({required this.row, required this.muted});

  @override
  Widget build(BuildContext context) {
    final date = DateFormatter.format(row.createdAt);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingSM),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(row.typeLabel, style: AppTheme.titleSm),
                Text(
                  row.referenceCode != null ? '$date · ${row.referenceCode}' : date,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.labelSm.copyWith(color: muted),
                ),
              ],
            ),
          ),
          Text(
            row.signedAmount,
            style: AppTheme.titleSm.copyWith(
              color: row.amount > 0 ? const Color(0xFF16A34A) : null,
            ),
          ),
        ],
      ),
    );
  }
}
