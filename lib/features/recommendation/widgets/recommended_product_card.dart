import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:blukios_marketplace/config/app_theme.dart';
import 'package:blukios_marketplace/core/utils/currency_formatter.dart';
import 'package:blukios_marketplace/features/recommendation/models/recommended_product_model.dart';
import 'package:blukios_marketplace/shared/widgets/app_icon.dart';

/// Card for the leaner [RecommendedProductModel] payload returned by the
/// recommendation service. Deliberately not [ProductCard] — that widget
/// requires a full [ProductModel] (wishlist state, `store`, `condition`
/// styling) this response doesn't carry.
class RecommendedProductCard extends StatelessWidget {
  final RecommendedProductModel product;
  final VoidCallback? onTap;

  const RecommendedProductCard({super.key, required this.product, this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary;
    final placeholder = isDark ? AppTheme.darkMuted : const Color(0xFFF3F4F6);

    return GestureDetector(
      onTap: onTap,
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
                  if (product.stock <= 0)
                    Positioned.fill(
                      child: Container(
                        color: Colors.black.withValues(alpha: 0.5),
                        child: Center(
                          child: Text(
                            'Stok Habis',
                            style: AppTheme.labelMd.copyWith(color: Colors.white),
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
                    Text(
                      '${product.totalSold} terjual',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.labelSm.copyWith(color: muted),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
