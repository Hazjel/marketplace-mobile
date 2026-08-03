import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:blukios_marketplace/config/app_theme.dart';
import 'package:blukios_marketplace/core/utils/currency_formatter.dart';
import 'package:blukios_marketplace/features/home/models/product_model.dart';
import 'package:blukios_marketplace/features/wishlist/viewmodels/wishlist_viewmodel.dart';
import 'package:blukios_marketplace/shared/widgets/app_icon.dart';

class ProductCard extends ConsumerStatefulWidget {
  final ProductModel product;
  final VoidCallback? onTap;

  const ProductCard({super.key, required this.product, this.onTap});

  @override
  ConsumerState<ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends ConsumerState<ProductCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final wishlist = ref.watch(wishlistProvider);
    final isWishlisted = wishlist.productIds.contains(product.id);
    final isPending = wishlist.pendingIds.contains(product.id);

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary;
    final placeholder = isDark ? AppTheme.darkMuted : const Color(0xFFF3F4F6);

    return GestureDetector(
      onTap: widget.onTap,
      // Scale-only press feedback: it never changes layout bounds, so
      // neighbouring cards don't shift.
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkCard : AppTheme.cardWhite,
            borderRadius: BorderRadius.circular(AppTheme.radius2XL),
            border: Border.all(
              color: isDark ? AppTheme.darkBorder : AppTheme.border,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (product.thumbnail != null)
                      CachedNetworkImage(
                        imageUrl: product.thumbnail!,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(color: placeholder),
                        errorWidget: (_, __, ___) => Container(
                          color: placeholder,
                          child: Center(
                            child: AppIcon(AppIcons.imageOff,
                                size: AppIconSize.lg, color: muted),
                          ),
                        ),
                      )
                    else
                      Container(
                        color: placeholder,
                        child: Center(
                          child: AppIcon(AppIcons.image,
                              size: AppIconSize.xl, color: muted),
                        ),
                      ),

                    // Wishlist toggle. 32px visual + 6px inset keeps the
                    // effective tap area comfortable without covering the image.
                    Positioned(
                      top: 6,
                      right: 6,
                      child: GestureDetector(
                        onTap: isPending
                            ? null
                            : () =>
                                ref.read(wishlistProvider.notifier).toggle(product),
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: (isDark ? Colors.black : Colors.white)
                                .withValues(alpha: 0.85),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: AppIcon(
                              isWishlisted ? AppIcons.heartFilled : AppIcons.heart,
                              size: AppIconSize.sm,
                              color: isWishlisted ? AppTheme.error : muted,
                              semanticsLabel: isWishlisted
                                  ? 'Hapus dari wishlist'
                                  : 'Tambah ke wishlist',
                            ),
                          ),
                        ),
                      ),
                    ),

                    if (product.stock <= 0)
                      Positioned.fill(
                        child: Container(
                          color: Colors.black.withValues(alpha: 0.5),
                          child: Center(
                            child: Text(
                              'Stok Habis',
                              style: AppTheme.labelMd
                                  .copyWith(color: Colors.white),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              Expanded(
                flex: 2,
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Flexible(
                        child: Text(
                          product.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTheme.bodySm,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        CurrencyFormatter.formatRupiah(product.price),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTheme.priceMd.copyWith(
                          color: isDark ? AppTheme.darkPrimary : AppTheme.primary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          if (product.store != null) ...[
                            AppIcon(AppIcons.store, size: 11, color: muted),
                            const SizedBox(width: 3),
                            Flexible(
                              child: Text(
                                product.store!.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTheme.labelSm.copyWith(color: muted),
                              ),
                            ),
                            const SizedBox(width: 6),
                          ],
                          Text(
                            '${product.totalSold} terjual',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTheme.labelSm.copyWith(color: muted),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
