import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:blukios_marketplace/config/app_theme.dart';
import 'package:blukios_marketplace/config/routes.dart';
import 'package:blukios_marketplace/core/utils/currency_formatter.dart';
import 'package:blukios_marketplace/features/home/models/product_model.dart';
import 'package:blukios_marketplace/features/recommendation/viewmodels/recommendation_viewmodel.dart';
import 'package:blukios_marketplace/features/recommendation/widgets/recommended_product_card.dart';
import 'package:blukios_marketplace/features/review/models/review_model.dart';
import 'package:blukios_marketplace/features/product/viewmodels/product_detail_viewmodel.dart';
import 'package:blukios_marketplace/features/wishlist/viewmodels/wishlist_viewmodel.dart';
import 'package:blukios_marketplace/shared/widgets/app_icon.dart';
import 'package:blukios_marketplace/shared/widgets/app_scaffold.dart';
import 'package:blukios_marketplace/shared/widgets/skeletons.dart';
import 'package:blukios_marketplace/shared/widgets/state_views.dart';

class ProductDetailScreen extends ConsumerStatefulWidget {
  final String slug;

  const ProductDetailScreen({super.key, required this.slug});

  @override
  ConsumerState<ProductDetailScreen> createState() =>
      _ProductDetailScreenState();
}

class _ProductDetailScreenState extends ConsumerState<ProductDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(productDetailProvider(widget.slug).notifier).loadProduct();
    });
  }

  Future<void> _addToCart() async {
    final error =
        await ref.read(productDetailProvider(widget.slug).notifier).addToCart();
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error ?? 'Produk ditambahkan ke keranjang'),
        backgroundColor: error == null ? AppTheme.success : AppTheme.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final slug = widget.slug;
    final viewModel = ref.watch(productDetailProvider(slug));
    final notifier = ref.read(productDetailProvider(slug).notifier);

    if (viewModel.isLoading) {
      return const AppScaffold(title: 'Detail Produk', body: DetailSkeleton());
    }

    if (viewModel.error != null || viewModel.product == null) {
      return AppScaffold(
        title: 'Detail Produk',
        body: ErrorState(
          message: viewModel.error ?? 'Produk tidak ditemukan',
          onRetry: notifier.loadProduct,
        ),
      );
    }

    final product = viewModel.product!;
    final wishlist = ref.watch(wishlistProvider);
    final isWishlisted = wishlist.productIds.contains(product.id);
    final isToggling = wishlist.pendingIds.contains(product.id);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AppScaffold(
      title: 'Detail Produk',
      actions: [
        IconButton(
          onPressed: isToggling
              ? null
              : () => ref.read(wishlistProvider.notifier).toggle(product),
          icon: AppIcon(
            isWishlisted ? AppIcons.heartFilled : AppIcons.heart,
            size: AppIconSize.lg,
            color: isWishlisted ? AppTheme.error : null,
            semanticsLabel:
                isWishlisted ? 'Hapus dari wishlist' : 'Tambah ke wishlist',
          ),
        ),
        const SizedBox(width: AppTheme.spacingXS),
      ],
      bottomBar: _AddToCartBar(
        isAdding: viewModel.addingToCart,
        isOutOfStock: product.stock <= 0,
        onAdd: _addToCart,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ProductImage(thumbnail: product.thumbnail),
            Padding(
              padding: const EdgeInsets.all(AppTheme.spacingLG),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    CurrencyFormatter.formatRupiah(product.price),
                    style: AppTheme.priceLg.copyWith(
                      color:
                          isDark ? AppTheme.darkPrimary : AppTheme.primary,
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingSM),
                  Text(product.name, style: AppTheme.titleLg),
                  const SizedBox(height: AppTheme.spacingMD),
                  _StatsRow(product: product),
                  const SizedBox(height: AppTheme.spacingLG),
                  const Divider(height: 1),
                  if (product.store != null) ...[
                    _StoreRow(store: product.store!),
                    const Divider(height: 1),
                  ],
                  const SizedBox(height: AppTheme.spacingLG),
                  Text('Deskripsi', style: AppTheme.titleMd),
                  const SizedBox(height: AppTheme.spacingSM),
                  Text(
                    product.description ?? 'Tidak ada deskripsi',
                    style: AppTheme.bodyLg,
                  ),
                  if (product.reviews.isNotEmpty) ...[
                    const SizedBox(height: AppTheme.spacingXL),
                    const Divider(height: 1),
                    const SizedBox(height: AppTheme.spacingLG),
                    _ReviewSection(product: product),
                  ],
                  const SizedBox(height: AppTheme.spacingXL),
                ],
              ),
            ),
            _SimilarProductsSection(productId: product.id),
          ],
        ),
      ),
    );
  }
}

/// "Produk Serupa" — content-based recommendations for this product.
/// Hidden entirely while loading or when the response comes back empty,
/// matching web's `v-if="similarProducts.length"`.
class _SimilarProductsSection extends ConsumerWidget {
  final String productId;

  const _SimilarProductsSection({required this.productId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final similar = ref.watch(similarProductsProvider(productId));
    if (similar.products.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacingXL),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.spacingLG,
              0,
              AppTheme.spacingLG,
              AppTheme.spacingSM,
            ),
            child: Text('Produk Serupa', style: AppTheme.titleLg),
          ),
          SizedBox(
            height: 232,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingLG),
              itemCount: similar.products.length,
              separatorBuilder: (_, __) => const SizedBox(width: AppTheme.spacingSM),
              itemBuilder: (context, index) {
                final product = similar.products[index];
                return SizedBox(
                  width: 148,
                  child: RecommendedProductCard(
                    product: product,
                    onTap: () =>
                        context.push(AppRoutes.productDetailPath(product.slug)),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductImage extends StatelessWidget {
  final String? thumbnail;

  const _ProductImage({required this.thumbnail});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final placeholder = isDark ? AppTheme.darkMuted : const Color(0xFFF3F4F6);
    final muted = isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary;

    return AspectRatio(
      aspectRatio: 1,
      child: thumbnail != null
          ? CachedNetworkImage(
              imageUrl: thumbnail!,
              fit: BoxFit.cover,
              placeholder: (_, __) => Container(color: placeholder),
              errorWidget: (_, __, ___) => Container(
                color: placeholder,
                child: Center(
                  child: AppIcon(AppIcons.imageOff, size: 48, color: muted),
                ),
              ),
            )
          : Container(
              color: placeholder,
              child: Center(
                child: AppIcon(AppIcons.image, size: 56, color: muted),
              ),
            ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  final ProductModel product;

  const _StatsRow({required this.product});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary;

    return Wrap(
      spacing: AppTheme.spacingLG,
      runSpacing: AppTheme.spacingSM,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _Stat(
          icon: AppIcons.tag,
          label: 'Terjual ${product.totalSold}',
          color: muted,
        ),
        _Stat(
          icon: AppIcons.package,
          label: 'Stok ${product.stock}',
          color: product.stock <= 0 ? AppTheme.error : muted,
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
            color:
                isDark ? AppTheme.darkIconBackground : AppTheme.iconBackground,
            borderRadius: BorderRadius.circular(AppTheme.radiusFull),
          ),
          child: Text(
            product.condition.toLowerCase() == 'new' ? 'Baru' : 'Bekas',
            style: AppTheme.labelSm.copyWith(
              color: isDark ? AppTheme.darkPrimary : AppTheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  final String icon;
  final String label;
  final Color color;

  const _Stat({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppIcon(icon, size: 14, color: color),
        const SizedBox(width: 5),
        Text(label, style: AppTheme.bodySm.copyWith(color: color)),
      ],
    );
  }
}

class _StoreRow extends StatelessWidget {
  final StoreMini store;

  const _StoreRow({required this.store});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary;

    return InkWell(
      // Only navigable when the API included the username — older list
      // payloads omit it.
      onTap: store.username == null
          ? null
          : () => context.push(AppRoutes.storeDetailPath(store.username!)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingLG),
        child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isDark
                  ? AppTheme.darkIconBackground
                  : AppTheme.iconBackground,
              shape: BoxShape.circle,
            ),
            clipBehavior: Clip.antiAlias,
            child: store.logo != null
                ? CachedNetworkImage(
                    imageUrl: store.logo!,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) =>
                        _StoreInitial(name: store.name),
                  )
                : _StoreInitial(name: store.name),
          ),
          const SizedBox(width: AppTheme.spacingMD),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  store.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.titleMd,
                ),
                Text(
                  store.username == null ? 'Penjual' : 'Lihat Toko',
                  style: AppTheme.labelSm.copyWith(
                    color: store.username == null ? muted : AppTheme.primary,
                  ),
                ),
              ],
            ),
          ),
          if (store.username != null)
            AppIcon(AppIcons.chevronRight,
                size: AppIconSize.md, color: muted),
        ],
        ),
      ),
    );
  }
}

class _ReviewSection extends StatelessWidget {
  final ProductModel product;

  const _ReviewSection({required this.product});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary;
    final average = product.averageRating;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Ulasan', style: AppTheme.titleMd),
            const SizedBox(width: AppTheme.spacingSM),
            if (average != null) ...[
              const AppIcon(
                AppIcons.starFilled,
                size: AppIconSize.sm,
                color: AppTheme.warning,
              ),
              const SizedBox(width: 3),
              Text(average.toStringAsFixed(1), style: AppTheme.titleSm),
            ],
            const Spacer(),
            Text(
              '${product.reviews.length} ulasan',
              style: AppTheme.labelSm.copyWith(color: muted),
            ),
          ],
        ),
        const SizedBox(height: AppTheme.spacingMD),
        // Only the first few — the full list lives on its own screen once
        // there are enough reviews to warrant one.
        ...product.reviews.take(3).map(
              (review) => Padding(
                padding: const EdgeInsets.only(bottom: AppTheme.spacingMD),
                child: _ReviewTile(review: review),
              ),
            ),
      ],
    );
  }
}

class _ReviewTile extends StatelessWidget {
  final ReviewModel review;

  const _ReviewTile({required this.review});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Row(
              children: List.generate(
                5,
                (i) => AppIcon(
                  i < review.rating ? AppIcons.starFilled : AppIcons.star,
                  size: 12,
                  color: i < review.rating ? AppTheme.warning : muted,
                ),
              ),
            ),
            const SizedBox(width: AppTheme.spacingSM),
            Flexible(
              child: Text(
                review.userName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTheme.labelSm.copyWith(color: muted),
              ),
            ),
          ],
        ),
        if (review.review?.isNotEmpty == true) ...[
          const SizedBox(height: 4),
          Text(review.review!, style: AppTheme.bodySm),
        ],
        if (review.attachments.isNotEmpty) ...[
          const SizedBox(height: AppTheme.spacingSM),
          SizedBox(
            height: 56,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: review.attachments.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (context, index) {
                final attachment = review.attachments[index];
                return ClipRRect(
                  borderRadius: BorderRadius.circular(AppTheme.radiusLG),
                  child: SizedBox(
                    width: 56,
                    height: 56,
                    child: attachment.isVideo
                        ? Container(
                            color: isDark
                                ? AppTheme.darkMuted
                                : const Color(0xFFF3F4F6),
                            child: Center(
                              child: AppIcon(AppIcons.image,
                                  size: AppIconSize.md, color: muted),
                            ),
                          )
                        : CachedNetworkImage(
                            imageUrl: attachment.filePath,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => Container(
                              color: isDark
                                  ? AppTheme.darkMuted
                                  : const Color(0xFFF3F4F6),
                            ),
                          ),
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }
}

class _StoreInitial extends StatelessWidget {
  final String name;

  const _StoreInitial({required this.name});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : 'S',
        style: AppTheme.titleMd.copyWith(
          color: isDark ? AppTheme.darkPrimary : AppTheme.primary,
        ),
      ),
    );
  }
}

class _AddToCartBar extends StatelessWidget {
  final bool isAdding;
  final bool isOutOfStock;
  final VoidCallback onAdd;

  const _AddToCartBar({
    required this.isAdding,
    required this.isOutOfStock,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingLG),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : AppTheme.cardWhite,
        border: Border(
          top: BorderSide(
            color: isDark ? AppTheme.darkBorder : AppTheme.border,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 48,
          child: FilledButton.icon(
            onPressed: (isAdding || isOutOfStock) ? null : onAdd,
            icon: isAdding
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const AppIcon(AppIcons.cart, size: AppIconSize.md),
            label: Text(isOutOfStock ? 'Stok Habis' : 'Tambah ke Keranjang'),
          ),
        ),
      ),
    );
  }
}
