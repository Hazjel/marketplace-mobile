import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:blukios_marketplace/config/app_theme.dart';
import 'package:blukios_marketplace/config/routes.dart';
import 'package:blukios_marketplace/core/utils/currency_formatter.dart';
import 'package:blukios_marketplace/features/seller/wallet/models/seller_wallet_model.dart';
import 'package:blukios_marketplace/features/seller/wallet/viewmodels/seller_wallet_viewmodel.dart';
import 'package:blukios_marketplace/shared/widgets/app_icon.dart';
import 'package:blukios_marketplace/shared/widgets/app_scaffold.dart';
import 'package:blukios_marketplace/shared/widgets/state_views.dart';

const _bankLabels = <String, String>{
  'bca': 'BCA',
  'mandiri': 'Mandiri',
  'bni': 'BNI',
  'bri': 'BRI',
};

const _historyTypeLabels = <String, String>{
  'income': 'Pemasukan',
  'withdraw': 'Penarikan',
  'initial': 'Saldo Awal',
};

const _withdrawalStatusLabels = <String, String>{
  'pending': 'Menunggu',
  'completed': 'Selesai',
  'rejected': 'Ditolak',
};

class SellerWalletScreen extends ConsumerStatefulWidget {
  const SellerWalletScreen({super.key});

  @override
  ConsumerState<SellerWalletScreen> createState() =>
      _SellerWalletScreenState();
}

class _SellerWalletScreenState extends ConsumerState<SellerWalletScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(sellerWalletProvider.notifier).loadAll();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(sellerWalletProvider);
    final notifier = ref.read(sellerWalletProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final loading = state.isLoadingBalance &&
        state.balance == null &&
        state.balanceError == null;

    return AppScaffold(
      title: 'Dompet Toko',
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : state.balanceError != null && state.balance == null
              ? ErrorState(
                  message: state.balanceError!,
                  onRetry: notifier.loadAll,
                )
              : RefreshIndicator(
                  onRefresh: notifier.loadAll,
                  child: ListView(
                    padding: const EdgeInsets.all(AppTheme.spacingLG),
                    children: [
                      _BalanceCard(balance: state.balance),
                      const SizedBox(height: AppTheme.spacingMD),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: state.balance == null
                              ? null
                              : () => context.push(
                                    AppRoutes.sellerWalletWithdraw,
                                    extra: state.balance,
                                  ),
                          icon: const AppIcon(
                            AppIcons.plus,
                            size: AppIconSize.md,
                            color: Colors.white,
                          ),
                          label: const Text('Ajukan Penarikan'),
                        ),
                      ),
                      const SizedBox(height: AppTheme.spacingLG),
                      Text('Riwayat Penarikan', style: AppTheme.titleMd),
                      const SizedBox(height: AppTheme.spacingSM),
                      _WithdrawalList(
                        isLoading: state.isLoadingWithdrawals,
                        error: state.withdrawalsError,
                        withdrawals: state.withdrawals,
                        isDark: isDark,
                        onRetry: notifier.loadWithdrawals,
                      ),
                      const SizedBox(height: AppTheme.spacingLG),
                      Text('Riwayat Saldo', style: AppTheme.titleMd),
                      const SizedBox(height: AppTheme.spacingSM),
                      _HistoryList(
                        isLoading: state.isLoadingHistory,
                        error: state.historyError,
                        history: state.history,
                        isDark: isDark,
                        onRetry: notifier.loadHistory,
                      ),
                    ],
                  ),
                ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  final StoreBalanceModel? balance;

  const _BalanceCard({required this.balance});

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
                      'Saldo Tersedia',
                      style: AppTheme.labelMd.copyWith(color: Colors.white70),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      CurrencyFormatter.formatRupiah(balance?.balance ?? 0),
                      style: AppTheme.priceLg.copyWith(color: Colors.white),
                    ),
                  ],
                ),
              ),
              const AppIcon(AppIcons.wallet, size: 44, color: Colors.white24),
            ],
          ),
          if ((balance?.pendingBalance ?? 0) > 0) ...[
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
                      '${CurrencyFormatter.formatRupiah(balance!.pendingBalance)} ditahan (escrow) — belum bisa ditarik',
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

class _WithdrawalList extends StatelessWidget {
  final bool isLoading;
  final String? error;
  final List<WithdrawalModel> withdrawals;
  final bool isDark;
  final VoidCallback onRetry;

  const _WithdrawalList({
    required this.isLoading,
    required this.error,
    required this.withdrawals,
    required this.isDark,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final muted = isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary;

    if (isLoading && withdrawals.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(AppTheme.spacingLG),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (error != null && withdrawals.isEmpty) {
      return ErrorState(message: error!, onRetry: onRetry);
    }
    if (withdrawals.isEmpty) {
      return _EmptyCard(
        isDark: isDark,
        message: 'Belum ada penarikan diajukan',
      );
    }

    return Column(
      children: [
        for (final w in withdrawals)
          Container(
            margin: const EdgeInsets.only(bottom: AppTheme.spacingSM),
            padding: const EdgeInsets.all(AppTheme.spacingMD),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkCard : AppTheme.cardWhite,
              borderRadius: BorderRadius.circular(AppTheme.radius2XL),
              border: Border.all(
                color: isDark ? AppTheme.darkBorder : AppTheme.border,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        CurrencyFormatter.formatRupiah(w.amount),
                        style: AppTheme.titleSm,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${_bankLabels[w.bankName] ?? w.bankName} • ${w.bankAccountNumber}',
                        style: AppTheme.labelSm.copyWith(color: muted),
                      ),
                    ],
                  ),
                ),
                _StatusChip(status: w.status),
              ],
            ),
          ),
      ],
    );
  }
}

class _HistoryList extends StatelessWidget {
  final bool isLoading;
  final String? error;
  final List<StoreBalanceHistoryModel> history;
  final bool isDark;
  final VoidCallback onRetry;

  const _HistoryList({
    required this.isLoading,
    required this.error,
    required this.history,
    required this.isDark,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final muted = isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary;

    if (isLoading && history.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(AppTheme.spacingLG),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (error != null && history.isEmpty) {
      return ErrorState(message: error!, onRetry: onRetry);
    }
    if (history.isEmpty) {
      return _EmptyCard(isDark: isDark, message: 'Belum ada riwayat saldo');
    }

    return Column(
      children: [
        for (final h in history)
          Container(
            margin: const EdgeInsets.only(bottom: AppTheme.spacingSM),
            padding: const EdgeInsets.all(AppTheme.spacingMD),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkCard : AppTheme.cardWhite,
              borderRadius: BorderRadius.circular(AppTheme.radius2XL),
              border: Border.all(
                color: isDark ? AppTheme.darkBorder : AppTheme.border,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _historyTypeLabels[h.type] ?? h.type,
                        style: AppTheme.bodyMd,
                      ),
                      if (h.remarks != null && h.remarks!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          h.remarks!,
                          style: AppTheme.labelSm.copyWith(color: muted),
                        ),
                      ],
                    ],
                  ),
                ),
                Text(
                  '${h.isCredit ? '+' : '-'}${CurrencyFormatter.formatRupiah(h.amount)}',
                  style: AppTheme.titleSm.copyWith(
                    color: h.isCredit ? AppTheme.success : AppTheme.error,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;

  const _StatusChip({required this.status});

  Color _color() {
    switch (status) {
      case 'completed':
        return AppTheme.success;
      case 'rejected':
        return AppTheme.error;
      default:
        return AppTheme.warning;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _color();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppTheme.radiusFull),
      ),
      child: Text(
        _withdrawalStatusLabels[status] ?? status,
        style: AppTheme.labelSm.copyWith(color: color),
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  final bool isDark;
  final String message;

  const _EmptyCard({required this.isDark, required this.message});

  @override
  Widget build(BuildContext context) {
    final muted = isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTheme.spacingLG),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : AppTheme.cardWhite,
        borderRadius: BorderRadius.circular(AppTheme.radius2XL),
        border: Border.all(
          color: isDark ? AppTheme.darkBorder : AppTheme.border,
        ),
      ),
      child: Center(
        child: Text(message, style: AppTheme.bodySm.copyWith(color: muted)),
      ),
    );
  }
}
