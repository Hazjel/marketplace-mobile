import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:blukios_marketplace/config/app_theme.dart';
import 'package:blukios_marketplace/core/utils/currency_formatter.dart';
import 'package:blukios_marketplace/core/utils/date_formatter.dart';
import 'package:blukios_marketplace/features/transaction/models/transaction_model.dart';
import 'package:blukios_marketplace/features/transaction/viewmodels/transaction_viewmodel.dart';
import 'package:blukios_marketplace/shared/widgets/app_icon.dart';
import 'package:blukios_marketplace/shared/widgets/app_scaffold.dart';
import 'package:blukios_marketplace/shared/widgets/skeletons.dart';
import 'package:blukios_marketplace/shared/widgets/state_views.dart';

class TransactionListScreen extends ConsumerStatefulWidget {
  const TransactionListScreen({super.key});

  @override
  ConsumerState<TransactionListScreen> createState() =>
      _TransactionListScreenState();
}

class _TransactionListScreenState extends ConsumerState<TransactionListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(transactionProvider.notifier).loadTransactions();
    });
  }

  Future<void> _refreshStatus(TransactionModel trx) async {
    final error =
        await ref.read(transactionProvider.notifier).refreshStatus(trx.id);
    if (!mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: AppTheme.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = ref.watch(transactionProvider);
    final notifier = ref.read(transactionProvider.notifier);

    return AppScaffold(
      title: 'Transaksi',
      isTabRoot: true,
      body: viewModel.isLoading
          ? const ListSkeleton()
          : viewModel.error != null
              ? ErrorState(
                  message: viewModel.error!,
                  onRetry: notifier.loadTransactions,
                )
              : viewModel.transactions.isEmpty
                  ? const EmptyState(
                      icon: AppIcons.inbox,
                      title: 'Belum ada transaksi',
                      message: 'Transaksi kamu akan muncul di sini',
                    )
                  : RefreshIndicator(
                      onRefresh: notifier.loadTransactions,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(AppTheme.spacingLG),
                        itemCount: viewModel.transactions.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: AppTheme.spacingMD),
                        itemBuilder: (context, index) => _TransactionCard(
                          trx: viewModel.transactions[index],
                          onCheckStatus: _refreshStatus,
                        ),
                      ),
                    ),
    );
  }
}

class _TransactionCard extends StatelessWidget {
  final TransactionModel trx;
  final Future<void> Function(TransactionModel) onCheckStatus;

  const _TransactionCard({required this.trx, required this.onCheckStatus});

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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  trx.code,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.titleSm,
                ),
              ),
              const SizedBox(width: AppTheme.spacingSM),
              _StatusBadge(
                status: trx.paymentStatus,
                label: trx.paymentStatusLabel,
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingSM),
          if (trx.storeName != null)
            Row(
              children: [
                AppIcon(AppIcons.store, size: 13, color: muted),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    trx.storeName!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.bodySm.copyWith(color: muted),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 3),
          Text(
            DateFormatter.format(trx.createdAt),
            style: AppTheme.labelSm.copyWith(color: muted),
          ),
          const SizedBox(height: AppTheme.spacingMD),
          Divider(
            height: 1,
            color: isDark ? AppTheme.darkBorder : AppTheme.border,
          ),
          const SizedBox(height: AppTheme.spacingMD),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total Pembayaran',
                style: AppTheme.bodyMd.copyWith(color: muted),
              ),
              Text(
                CurrencyFormatter.formatRupiah(trx.grandTotal),
                style: AppTheme.priceSm.copyWith(
                  color: isDark ? AppTheme.darkPrimary : AppTheme.primary,
                ),
              ),
            ],
          ),
          if (trx.paymentStatus == 'pending') ...[
            const SizedBox(height: AppTheme.spacingMD),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => onCheckStatus(trx),
                icon: const AppIcon(AppIcons.refresh, size: AppIconSize.sm),
                label: const Text('Cek Status Pembayaran'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  final String label;

  const _StatusBadge({required this.status, required this.label});

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (status) {
      'paid' => (const Color(0xFFDCFCE7), const Color(0xFF16A34A)),
      'failed' || 'cancelled' || 'expired' => (
          const Color(0xFFFEE2E2),
          const Color(0xFFDC2626),
        ),
      _ => (const Color(0xFFFEF9C3), const Color(0xFFCA8A04)),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppTheme.radiusFull),
      ),
      child: Text(
        label,
        style: AppTheme.labelSm.copyWith(color: fg, fontWeight: FontWeight.w600),
      ),
    );
  }
}
