import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:blukios_marketplace/config/app_theme.dart';
import 'package:blukios_marketplace/config/routes.dart';
import 'package:blukios_marketplace/core/utils/currency_formatter.dart';
import 'package:blukios_marketplace/features/cart/models/cart_model.dart';
import 'package:blukios_marketplace/features/cart/viewmodels/cart_viewmodel.dart';
import 'package:blukios_marketplace/shared/widgets/app_icon.dart';
import 'package:blukios_marketplace/shared/widgets/app_scaffold.dart';
import 'package:blukios_marketplace/shared/widgets/skeletons.dart';
import 'package:blukios_marketplace/shared/widgets/state_views.dart';

class CartScreen extends ConsumerStatefulWidget {
  const CartScreen({super.key});

  @override
  ConsumerState<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends ConsumerState<CartScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(cartProvider.notifier).loadCart();
    });
  }

  Future<void> _removeItem(CartItemModel item) async {
    final error = await ref
        .read(cartProvider.notifier)
        .removeItem(item.productId, variantId: item.variantId);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error ?? 'Produk dihapus dari keranjang'),
        backgroundColor: error == null ? null : AppTheme.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = ref.watch(cartProvider);
    final notifier = ref.read(cartProvider.notifier);

    return AppScaffold(
      title: 'Keranjang',
      body: viewModel.isLoading
          ? const ListSkeleton()
          : viewModel.error != null
              ? ErrorState(
                  message: viewModel.error!,
                  onRetry: notifier.loadCart,
                )
              : viewModel.groups.isEmpty
                  ? EmptyState(
                      icon: AppIcons.cart,
                      title: 'Keranjang kosong',
                      message: 'Yuk mulai belanja!',
                      actionLabel: 'Lihat Produk',
                      onAction: () => context.go(AppRoutes.home),
                    )
                  : RefreshIndicator(
                      onRefresh: notifier.loadCart,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(AppTheme.spacingLG),
                        itemCount: viewModel.groups.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: AppTheme.spacingLG),
                        itemBuilder: (context, index) => _StoreGroup(
                          group: viewModel.groups[index],
                          onRemoveItem: _removeItem,
                        ),
                      ),
                    ),
    );
  }
}

class _StoreGroup extends StatelessWidget {
  final CartGroupModel group;
  final Future<void> Function(CartItemModel) onRemoveItem;

  const _StoreGroup({required this.group, required this.onRemoveItem});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary;
    final borderColor = isDark ? AppTheme.darkBorder : AppTheme.border;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : AppTheme.cardWhite,
        borderRadius: BorderRadius.circular(AppTheme.radius2XL),
        border: Border.all(color: borderColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(AppTheme.spacingMD),
            color: isDark ? AppTheme.darkMuted : AppTheme.surface,
            child: Row(
              children: [
                AppIcon(AppIcons.store, size: AppIconSize.sm, color: muted),
                const SizedBox(width: AppTheme.spacingSM),
                Expanded(
                  child: Text(
                    group.storeName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.titleSm,
                  ),
                ),
              ],
            ),
          ),
          ...group.items.map(
            (item) => Padding(
              padding: const EdgeInsets.all(AppTheme.spacingMD),
              child: _CartItem(item: item, onRemove: () => onRemoveItem(item)),
            ),
          ),
          Divider(height: 1, color: borderColor),
          Padding(
            padding: const EdgeInsets.all(AppTheme.spacingMD),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Subtotal',
                      style: AppTheme.labelSm.copyWith(color: muted),
                    ),
                    Text(
                      CurrencyFormatter.formatRupiah(group.subtotal),
                      style: AppTheme.priceSm.copyWith(
                        color: isDark ? AppTheme.darkPrimary : AppTheme.primary,
                      ),
                    ),
                  ],
                ),
                FilledButton(
                  onPressed: () =>
                      context.push(AppRoutes.checkout, extra: group),
                  child: const Text('Checkout'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CartItem extends StatelessWidget {
  final CartItemModel item;
  final VoidCallback onRemove;

  const _CartItem({required this.item, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary;
    final placeholder = isDark ? AppTheme.darkMuted : const Color(0xFFF3F4F6);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppTheme.radiusLG),
          child: SizedBox(
            width: 64,
            height: 64,
            child: item.productThumbnail != null
                ? CachedNetworkImage(
                    imageUrl: item.productThumbnail!,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => Container(
                      color: placeholder,
                      child: Center(
                        child: AppIcon(AppIcons.imageOff,
                            size: AppIconSize.md, color: muted),
                      ),
                    ),
                  )
                : Container(
                    color: placeholder,
                    child: Center(
                      child: AppIcon(AppIcons.image,
                          size: AppIconSize.md, color: muted),
                    ),
                  ),
          ),
        ),
        const SizedBox(width: AppTheme.spacingMD),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.productName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTheme.bodyMd,
              ),
              const SizedBox(height: 4),
              Text(
                CurrencyFormatter.formatRupiah(item.price),
                style: AppTheme.priceSm.copyWith(
                  color: isDark ? AppTheme.darkPrimary : AppTheme.primary,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(
                    'Qty: ${item.quantity}',
                    style: AppTheme.labelSm.copyWith(color: muted),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: onRemove,
                    visualDensity: VisualDensity.compact,
                    icon: const AppIcon(
                      AppIcons.trash,
                      size: AppIconSize.md,
                      color: AppTheme.error,
                      semanticsLabel: 'Hapus dari keranjang',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
