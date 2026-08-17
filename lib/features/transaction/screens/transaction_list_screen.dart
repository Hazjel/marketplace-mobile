import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:blukios_marketplace/config/app_theme.dart';
import 'package:blukios_marketplace/config/routes.dart';
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

  Future<void> _reviewItem(TransactionModel trx, TransactionDetailModel item) async {
    final submitted = await context.push<bool>(
      AppRoutes.reviewFormPath(trx.id, item.productId),
      extra: {
        'productName': item.productName ?? 'Produk',
        'productThumbnail': item.productThumbnail,
      },
    );
    if (submitted == true) {
      ref.read(transactionProvider.notifier).markReviewed(trx.id, item.productId);
    }
  }

  Future<void> _completeOrder(TransactionModel trx) async {
    final picker = ImagePicker();
    final photo = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (photo == null) return;
    if (!mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Konfirmasi Pesanan Diterima'),
        content: const Text(
          'Pastikan barang sudah diterima dalam kondisi baik. Dana akan diteruskan ke penjual setelah ini.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Konfirmasi')),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!mounted) return;

    final error =
        await ref.read(transactionProvider.notifier).completeOrder(trx.id, photo.path);
    if (!mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: AppTheme.error),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pesanan selesai — dana diteruskan ke penjual')),
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
                          onReview: (item) => _reviewItem(viewModel.transactions[index], item),
                          onCompleteOrder: () => _completeOrder(viewModel.transactions[index]),
                        ),
                      ),
                    ),
    );
  }
}

class _TransactionCard extends StatelessWidget {
  final TransactionModel trx;
  final Future<void> Function(TransactionModel) onCheckStatus;
  final Future<void> Function(TransactionDetailModel) onReview;
  final VoidCallback onCompleteOrder;

  const _TransactionCard({
    required this.trx,
    required this.onCheckStatus,
    required this.onReview,
    required this.onCompleteOrder,
  });

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
              if (trx.paymentStatus == 'paid') ...[
                const SizedBox(width: 6),
                _StatusBadge(
                  status: trx.deliveryStatus,
                  label: trx.deliveryStatusLabel,
                ),
              ],
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
          if (trx.deliveryStatus == 'delivering') ...[
            const SizedBox(height: AppTheme.spacingMD),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onCompleteOrder,
                icon: const AppIcon(AppIcons.check, size: AppIconSize.sm, color: Colors.white),
                label: const Text('Konfirmasi Pesanan Diterima'),
              ),
            ),
          ],
          if (trx.deliveryStatus == 'completed') ...[
            for (final item in trx.transactionDetails)
              if (!trx.reviewedProductIds.contains(item.productId)) ...[
                const SizedBox(height: AppTheme.spacingSM),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => onReview(item),
                    child: Text(
                      'Beri Ulasan: ${item.productName ?? 'Produk'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
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
      'paid' || 'completed' => (const Color(0xFFDCFCE7), const Color(0xFF16A34A)),
      'failed' || 'cancelled' || 'expired' => (
          const Color(0xFFFEE2E2),
          const Color(0xFFDC2626),
        ),
      'delivering' || 'processing' => (
          const Color(0xFFDBEAFE),
          const Color(0xFF2563EB),
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
