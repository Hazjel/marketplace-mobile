import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:blukios_marketplace/config/app_theme.dart';
import 'package:blukios_marketplace/config/routes.dart';
import 'package:blukios_marketplace/core/utils/currency_formatter.dart';
import 'package:blukios_marketplace/core/utils/date_formatter.dart';
import 'package:blukios_marketplace/features/seller/orders/viewmodels/seller_order_list_viewmodel.dart';
import 'package:blukios_marketplace/features/transaction/models/transaction_model.dart';
import 'package:blukios_marketplace/shared/widgets/app_icon.dart';
import 'package:blukios_marketplace/shared/widgets/app_scaffold.dart';
import 'package:blukios_marketplace/shared/widgets/skeletons.dart';
import 'package:blukios_marketplace/shared/widgets/state_views.dart';

/// Lists orders placed on the seller's own store. Pushed as a standalone
/// route today (`/seller/orders`) — wiring it into the bottom-nav shell for
/// seller-mode users is handled by a later pass, once every seller feature
/// has landed.
class SellerOrderListScreen extends ConsumerStatefulWidget {
  const SellerOrderListScreen({super.key});

  @override
  ConsumerState<SellerOrderListScreen> createState() =>
      _SellerOrderListScreenState();
}

class _SellerOrderListScreenState extends ConsumerState<SellerOrderListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(sellerOrderListProvider.notifier).loadOrders();
    });
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(sellerOrderListProvider);
    final notifier = ref.read(sellerOrderListProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AppScaffold(
      title: 'Pesanan Masuk',
      body: Column(
        children: [
          Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingLG),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkCard : AppTheme.cardWhite,
              border: Border(
                bottom: BorderSide(
                  color: isDark ? AppTheme.darkBorder : AppTheme.border,
                ),
              ),
            ),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: SellerOrderFilter.values.length,
              separatorBuilder: (_, __) => const SizedBox(width: AppTheme.spacingSM),
              itemBuilder: (context, index) {
                final filter = SellerOrderFilter.values[index];
                final selected = filter == data.filter;
                return Center(
                  child: ChoiceChip(
                    label: Text(filter.label),
                    selected: selected,
                    onSelected: (_) => notifier.setFilter(filter),
                  ),
                );
              },
            ),
          ),
          Expanded(
            child: data.isLoading
                ? const ListSkeleton()
                : data.error != null
                    ? ErrorState(message: data.error!, onRetry: notifier.loadOrders)
                    : data.visibleOrders.isEmpty
                        ? const EmptyState(
                            icon: AppIcons.inbox,
                            title: 'Belum ada pesanan',
                            message: 'Pesanan yang masuk ke toko kamu akan muncul di sini',
                          )
                        : RefreshIndicator(
                            onRefresh: notifier.loadOrders,
                            child: ListView.separated(
                              padding: const EdgeInsets.all(AppTheme.spacingLG),
                              itemCount: data.visibleOrders.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: AppTheme.spacingMD),
                              itemBuilder: (context, index) => _OrderCard(
                                order: data.visibleOrders[index],
                                onTap: () async {
                                  final order = data.visibleOrders[index];
                                  final updated = await context
                                      .push<TransactionModel>(
                                    AppRoutes.sellerOrderDetailPath(order.id),
                                  );
                                  if (updated != null) {
                                    notifier.replaceOrder(updated);
                                  }
                                },
                              ),
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final TransactionModel order;
  final VoidCallback onTap;

  const _OrderCard({required this.order, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radius2XL),
      child: Container(
        padding: const EdgeInsets.all(AppTheme.spacingLG),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkCard : AppTheme.cardWhite,
          borderRadius: BorderRadius.circular(AppTheme.radius2XL),
          border: Border.all(color: isDark ? AppTheme.darkBorder : AppTheme.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    order.code,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.titleSm,
                  ),
                ),
                const SizedBox(width: AppTheme.spacingSM),
                _StatusBadge(
                  status: order.deliveryStatus,
                  label: order.deliveryStatusLabel,
                ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              DateFormatter.format(order.createdAt),
              style: AppTheme.labelSm.copyWith(color: muted),
            ),
            const SizedBox(height: AppTheme.spacingMD),
            Divider(height: 1, color: isDark ? AppTheme.darkBorder : AppTheme.border),
            const SizedBox(height: AppTheme.spacingMD),
            for (final item in order.transactionDetails.take(2))
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '${item.qty}x ${item.productName ?? 'Produk'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.bodySm.copyWith(color: muted),
                ),
              ),
            if (order.transactionDetails.length > 2)
              Text(
                '+${order.transactionDetails.length - 2} produk lainnya',
                style: AppTheme.labelSm.copyWith(color: muted),
              ),
            const SizedBox(height: AppTheme.spacingSM),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Total Pesanan', style: AppTheme.bodyMd.copyWith(color: muted)),
                Text(
                  CurrencyFormatter.formatRupiah(order.grandTotal),
                  style: AppTheme.priceSm.copyWith(
                    color: isDark ? AppTheme.darkPrimary : AppTheme.primary,
                  ),
                ),
              ],
            ),
          ],
        ),
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
      'completed' => (const Color(0xFFDCFCE7), const Color(0xFF16A34A)),
      'delivering' => (const Color(0xFFDBEAFE), const Color(0xFF2563EB)),
      'processing' => (const Color(0xFFFEF9C3), const Color(0xFFCA8A04)),
      _ => (const Color(0xFFF3F4F6), const Color(0xFF6B7280)),
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
