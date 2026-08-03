import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:blukios_marketplace/config/app_theme.dart';
import 'package:blukios_marketplace/config/routes.dart';
import 'package:blukios_marketplace/core/utils/responsive.dart';
import 'package:blukios_marketplace/features/cart/viewmodels/cart_viewmodel.dart';
import 'package:blukios_marketplace/features/home/models/category_model.dart';
import 'package:blukios_marketplace/features/home/viewmodels/home_viewmodel.dart';
import 'package:blukios_marketplace/shared/widgets/app_icon.dart';
import 'package:blukios_marketplace/shared/widgets/product_card.dart';
import 'package:blukios_marketplace/shared/widgets/skeletons.dart';
import 'package:blukios_marketplace/shared/widgets/state_views.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(homeProvider.notifier).loadData();
      // Cart drives the header badge, so it needs loading here too.
      ref.read(cartProvider.notifier).loadCart();
    });
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = ref.watch(homeProvider);
    final notifier = ref.read(homeProvider.notifier);
    final cartCount = ref.watch(
      cartProvider.select(
        (s) => s.groups.fold<int>(0, (sum, g) => sum + g.itemCount),
      ),
    );

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: notifier.loadData,
        child: CustomScrollView(
          slivers: [
            _HomeHeader(cartCount: cartCount),
            if (viewModel.isLoading)
              const SliverToBoxAdapter(child: ProductGridSkeleton())
            else if (viewModel.error != null)
              SliverFillRemaining(
                hasScrollBody: false,
                child: ErrorState(
                  message: viewModel.error!,
                  onRetry: notifier.loadData,
                ),
              )
            else ...[
              const SliverToBoxAdapter(child: _PromoBanner()),
              if (viewModel.categories.isNotEmpty)
                SliverToBoxAdapter(
                  child: _CategoryStrip(categories: viewModel.categories),
                ),
              const SliverToBoxAdapter(
                child: _SectionHeader(title: 'Produk Terbaru'),
              ),
              if (viewModel.products.isEmpty)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 48),
                    child: EmptyState(
                      icon: AppIcons.package,
                      title: 'Belum ada produk',
                      message: 'Produk akan muncul di sini',
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: Responsive.getScreenPadding(context)
                      .copyWith(bottom: AppTheme.spacingXL),
                  sliver: SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: Responsive.getGridCrossAxisCount(context),
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 0.62,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final product = viewModel.products[index];
                        return ProductCard(
                          product: product,
                          onTap: () => context
                              .push(AppRoutes.productDetailPath(product.slug)),
                        );
                      },
                      childCount: viewModel.products.length,
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Pinned search + cart header. Stays on screen while the feed scrolls,
/// so both are always one tap away.
class _HomeHeader extends StatelessWidget {
  final int cartCount;

  const _HomeHeader({required this.cartCount});

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      pinned: true,
      elevation: 0,
      toolbarHeight: 64,
      automaticallyImplyLeading: false,
      titleSpacing: AppTheme.spacingLG,
      title: Row(
        children: [
          const Expanded(child: _SearchField()),
          const SizedBox(width: AppTheme.spacingSM),
          _CartButton(count: cartCount),
        ],
      ),
    );
  }
}

/// Read-only field that routes to the search screen. Typing happens
/// there — a live search box inside a pinned header fights the scroll.
class _SearchField extends StatelessWidget {
  const _SearchField();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary;

    return GestureDetector(
      onTap: () => context.push(AppRoutes.search),
      child: Container(
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingMD),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkMuted : const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(AppTheme.radiusXL),
        ),
        child: Row(
          children: [
            AppIcon(AppIcons.search, size: AppIconSize.md, color: muted),
            const SizedBox(width: AppTheme.spacingSM),
            Text(
              'Cari produk di Blukios',
              style: AppTheme.bodyMd.copyWith(color: muted),
            ),
          ],
        ),
      ),
    );
  }
}

class _CartButton extends StatelessWidget {
  final int count;

  const _CartButton({required this.count});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push(AppRoutes.cart),
      child: SizedBox(
        width: 44,
        height: 44,
        child: Stack(
          alignment: Alignment.center,
          children: [
            const AppIcon(
              AppIcons.cart,
              size: AppIconSize.lg,
              semanticsLabel: 'Keranjang',
            ),
            if (count > 0)
              Positioned(
                top: 4,
                right: 2,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  constraints: const BoxConstraints(minWidth: 17),
                  decoration: BoxDecoration(
                    color: AppTheme.error,
                    borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                  ),
                  child: Text(
                    count > 99 ? '99+' : '$count',
                    textAlign: TextAlign.center,
                    style: AppTheme.labelSm.copyWith(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PromoBanner extends StatelessWidget {
  const _PromoBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 132,
      margin: const EdgeInsets.fromLTRB(
        AppTheme.spacingLG,
        AppTheme.spacingSM,
        AppTheme.spacingLG,
        0,
      ),
      padding: const EdgeInsets.all(AppTheme.spacingLG),
      decoration: BoxDecoration(
        gradient: AppTheme.blukiosGradient,
        borderRadius: BorderRadius.circular(AppTheme.radius2XL),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Belanja Gadget\nTanpa Ribet',
                  style: AppTheme.displayMd.copyWith(color: Colors.white),
                ),
                const SizedBox(height: AppTheme.spacingXS),
                Text(
                  'Ribuan produk dari toko terpercaya',
                  style: AppTheme.bodySm.copyWith(color: Colors.white70),
                ),
              ],
            ),
          ),
          const AppIcon(AppIcons.package, size: 56, color: Colors.white24),
        ],
      ),
    );
  }
}

class _CategoryStrip extends StatelessWidget {
  final List<CategoryModel> categories;

  const _CategoryStrip({required this.categories});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _SectionHeader(
          title: 'Kategori',
          actionLabel: 'Lihat Semua',
          // go() not push() — Kategori is a sibling tab, so this switches
          // branches instead of stacking a second copy on top of Home.
          onAction: () => context.go(AppRoutes.categories),
        ),
        SizedBox(
          height: 96,
          child: ListView.builder(
            padding:
                const EdgeInsets.symmetric(horizontal: AppTheme.spacingMD),
            scrollDirection: Axis.horizontal,
            itemCount: categories.length,
            itemBuilder: (context, index) =>
                _CategoryChip(category: categories[index]),
          ),
        ),
      ],
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final CategoryModel category;

  const _CategoryChip({required this.category});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () => context.push(
        AppRoutes.search,
        extra: {'categoryId': category.id, 'categoryName': category.name},
      ),
      child: SizedBox(
        width: 76,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: isDark
                    ? AppTheme.darkIconBackground
                    : AppTheme.iconBackground,
                borderRadius: BorderRadius.circular(AppTheme.radiusXLCard),
              ),
              clipBehavior: Clip.antiAlias,
              child: category.image != null
                  ? CachedNetworkImage(
                      imageUrl: category.image!,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => const _CategoryFallback(),
                    )
                  : const _CategoryFallback(),
            ),
            const SizedBox(height: 6),
            Flexible(
              child: Text(
                category.name,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTheme.labelSm,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryFallback extends StatelessWidget {
  const _CategoryFallback();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: AppIcon(
        AppIcons.layers,
        size: AppIconSize.md,
        color: isDark ? AppTheme.darkPrimary : AppTheme.primary,
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _SectionHeader({
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.spacingLG,
        AppTheme.spacingLG,
        AppTheme.spacingSM,
        AppTheme.spacingSM,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: AppTheme.titleLg),
          if (actionLabel != null && onAction != null)
            TextButton(
              onPressed: onAction,
              child: Text(actionLabel!, style: AppTheme.labelMd),
            ),
        ],
      ),
    );
  }
}
