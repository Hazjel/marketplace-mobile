import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:blukios_marketplace/config/app_theme.dart';
import 'package:blukios_marketplace/config/routes.dart';
import 'package:blukios_marketplace/core/utils/currency_formatter.dart';
import 'package:blukios_marketplace/features/seller/product/models/seller_product_model.dart';
import 'package:blukios_marketplace/features/seller/product/viewmodels/seller_product_list_viewmodel.dart';
import 'package:blukios_marketplace/shared/widgets/app_icon.dart';
import 'package:blukios_marketplace/shared/widgets/app_scaffold.dart';
import 'package:blukios_marketplace/shared/widgets/skeletons.dart';
import 'package:blukios_marketplace/shared/widgets/state_views.dart';

/// Seller Centre "Produk Saya" — lists this seller's own store products,
/// with create/edit/delete entry points. Mirrors fe-blue's product
/// management table, scoped down to a single-column mobile list.
class SellerProductListScreen extends ConsumerStatefulWidget {
  const SellerProductListScreen({super.key});

  @override
  ConsumerState<SellerProductListScreen> createState() =>
      _SellerProductListScreenState();
}

class _SellerProductListScreenState
    extends ConsumerState<SellerProductListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(sellerProductListProvider.notifier).loadProducts();
    });
  }

  Future<void> _delete(SellerProductModel product) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Produk'),
        content: Text('Hapus produk "${product.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppTheme.error),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final error =
        await ref.read(sellerProductListProvider.notifier).deleteProduct(product.id);
    if (!mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: AppTheme.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = ref.watch(sellerProductListProvider);
    final notifier = ref.read(sellerProductListProvider.notifier);

    return AppScaffold(
      title: 'Produk Saya',
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await context.push(AppRoutes.sellerProductForm);
          if (context.mounted) notifier.loadProducts();
        },
        child: const AppIcon(
          AppIcons.plus,
          size: AppIconSize.lg,
          color: Colors.white,
          semanticsLabel: 'Tambah produk',
        ),
      ),
      body: viewModel.isLoading
          ? const ListSkeleton()
          : viewModel.error != null
              ? ErrorState(message: viewModel.error!, onRetry: notifier.loadProducts)
              : viewModel.products.isEmpty
                  ? EmptyState(
                      icon: AppIcons.package,
                      title: 'Belum ada produk',
                      message: 'Tambahkan produk pertama toko Anda',
                      actionLabel: 'Tambah Produk',
                      onAction: () async {
                        await context.push(AppRoutes.sellerProductForm);
                        if (context.mounted) notifier.loadProducts();
                      },
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(
                        AppTheme.spacingLG,
                        AppTheme.spacingLG,
                        AppTheme.spacingLG,
                        88, // clears the FAB
                      ),
                      itemCount: viewModel.products.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: AppTheme.spacingMD),
                      itemBuilder: (context, index) {
                        final product = viewModel.products[index];
                        return _ProductCard(
                          product: product,
                          isDeleting: viewModel.deletingId == product.id,
                          onDelete: () => _delete(product),
                          onEdit: () async {
                            await context.push(
                              AppRoutes.sellerProductForm,
                              extra: product,
                            );
                            if (context.mounted) notifier.loadProducts();
                          },
                        );
                      },
                    ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final SellerProductModel product;
  final bool isDeleting;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  const _ProductCard({
    required this.product,
    required this.isDeleting,
    required this.onDelete,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary;

    return Opacity(
      opacity: isDeleting ? 0.5 : 1,
      child: Container(
        padding: const EdgeInsets.all(AppTheme.spacingMD),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkCard : AppTheme.cardWhite,
          borderRadius: BorderRadius.circular(AppTheme.radius2XL),
          border: Border.all(
            color: isDark ? AppTheme.darkBorder : AppTheme.border,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppTheme.radiusXLCard),
              child: SizedBox(
                width: 64,
                height: 64,
                child: product.thumbnailUrl != null
                    ? CachedNetworkImage(
                        imageUrl: product.thumbnailUrl!,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => Container(
                          color:
                              isDark ? AppTheme.darkMuted : AppTheme.primaryLight,
                          child: AppIcon(AppIcons.imageOff, color: muted),
                        ),
                      )
                    : Container(
                        color: isDark ? AppTheme.darkMuted : AppTheme.primaryLight,
                        child: Center(
                          child: AppIcon(AppIcons.image, color: muted),
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
                    product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.titleSm,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    CurrencyFormatter.formatRupiah(product.price),
                    style: AppTheme.priceSm.copyWith(
                      color: isDark ? AppTheme.darkPrimary : AppTheme.primary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Stok: ${product.stock} · Terjual: ${product.totalSold}',
                    style: AppTheme.bodySm.copyWith(color: muted),
                  ),
                  if (product.categoryName != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      product.categoryName!,
                      style: AppTheme.labelSm.copyWith(color: muted),
                    ),
                  ],
                ],
              ),
            ),
            PopupMenuButton<String>(
              icon: AppIcon(
                AppIcons.settings,
                size: AppIconSize.md,
                color: muted,
                semanticsLabel: 'Opsi produk',
              ),
              enabled: !isDeleting,
              onSelected: (value) {
                if (value == 'edit') {
                  onEdit();
                } else if (value == 'delete') {
                  onDelete();
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('Edit')),
                PopupMenuItem(
                  value: 'delete',
                  child: Text('Hapus', style: TextStyle(color: AppTheme.error)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
