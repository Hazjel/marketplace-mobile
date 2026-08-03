import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:blukios_marketplace/config/app_theme.dart';
import 'package:blukios_marketplace/config/routes.dart';
import 'package:blukios_marketplace/features/wishlist/viewmodels/wishlist_viewmodel.dart';
import 'package:blukios_marketplace/shared/widgets/app_icon.dart';
import 'package:blukios_marketplace/shared/widgets/app_scaffold.dart';
import 'package:blukios_marketplace/shared/widgets/product_card.dart';
import 'package:blukios_marketplace/shared/widgets/skeletons.dart';
import 'package:blukios_marketplace/shared/widgets/state_views.dart';

class WishlistScreen extends ConsumerStatefulWidget {
  const WishlistScreen({super.key});

  @override
  ConsumerState<WishlistScreen> createState() => _WishlistScreenState();
}

class _WishlistScreenState extends ConsumerState<WishlistScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(wishlistProvider.notifier).loadWishlist();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(wishlistProvider);
    final reload = ref.read(wishlistProvider.notifier).loadWishlist;

    return AppScaffold(
      title: 'Wishlist',
      isTabRoot: true,
      body: state.isLoading
          ? const ProductGridSkeleton()
          : state.error != null && state.products.isEmpty
              ? ErrorState(message: state.error!, onRetry: reload)
              : state.products.isEmpty
                  ? EmptyState(
                      icon: AppIcons.heart,
                      title: 'Wishlist kosong',
                      message: 'Simpan produk favoritmu di sini',
                      actionLabel: 'Mulai Belanja',
                      onAction: () => context.go(AppRoutes.home),
                    )
                  : RefreshIndicator(
                      onRefresh: reload,
                      child: GridView.builder(
                        padding: const EdgeInsets.all(AppTheme.spacingMD),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.62,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                        ),
                        itemCount: state.products.length,
                        itemBuilder: (context, index) {
                          final product = state.products[index];
                          return ProductCard(
                            product: product,
                            onTap: () => context.push(
                              AppRoutes.productDetailPath(product.slug),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}
