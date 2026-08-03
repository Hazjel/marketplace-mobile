import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:blukios_marketplace/config/app_theme.dart';
import 'package:blukios_marketplace/config/routes.dart';
import 'package:blukios_marketplace/features/review/models/review_model.dart';
import 'package:blukios_marketplace/features/store/models/store_model.dart';
import 'package:blukios_marketplace/features/store/viewmodels/store_viewmodel.dart';
import 'package:blukios_marketplace/shared/widgets/app_icon.dart';
import 'package:blukios_marketplace/shared/widgets/app_scaffold.dart';
import 'package:blukios_marketplace/shared/widgets/product_card.dart';
import 'package:blukios_marketplace/shared/widgets/skeletons.dart';
import 'package:blukios_marketplace/shared/widgets/state_views.dart';

class StoreDetailScreen extends ConsumerStatefulWidget {
  final String username;

  const StoreDetailScreen({super.key, required this.username});

  @override
  ConsumerState<StoreDetailScreen> createState() => _StoreDetailScreenState();
}

class _StoreDetailScreenState extends ConsumerState<StoreDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(storeProvider(widget.username).notifier).load();
    });
  }

  Future<void> _toggleFollow() async {
    final error =
        await ref.read(storeProvider(widget.username).notifier).toggleFollow();
    if (!mounted || error == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error), backgroundColor: AppTheme.error),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(storeProvider(widget.username));
    final notifier = ref.read(storeProvider(widget.username).notifier);

    if (state.isLoading) {
      return const AppScaffold(title: 'Toko', body: DetailSkeleton());
    }

    if (state.notFound) {
      return const AppScaffold(
        title: 'Toko',
        body: EmptyState(
          icon: AppIcons.store,
          title: 'Toko tidak ditemukan',
          message: 'Toko ini mungkin sudah tidak aktif',
        ),
      );
    }

    if (state.error != null || state.store == null) {
      return AppScaffold(
        title: 'Toko',
        body: ErrorState(
          message: state.error ?? 'Gagal memuat toko',
          onRetry: notifier.load,
        ),
      );
    }

    final store = state.store!;

    return AppScaffold(
      title: store.name,
      body: RefreshIndicator(
        onRefresh: notifier.load,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: _StoreHeader(
                store: store,
                isFollowing: state.isFollowing,
                isToggling: state.isTogglingFollow,
                onToggleFollow: _toggleFollow,
              ),
            ),
            if (state.reviews.isNotEmpty)
              SliverToBoxAdapter(child: _ReviewStrip(reviews: state.reviews)),
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  AppTheme.spacingLG,
                  AppTheme.spacingLG,
                  AppTheme.spacingLG,
                  AppTheme.spacingSM,
                ),
                child: Text('Produk Toko', style: TextStyle(fontSize: 18)),
              ),
            ),
            if (state.products.isEmpty)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: EmptyState(
                    icon: AppIcons.package,
                    title: 'Belum ada produk',
                    message: 'Toko ini belum menjual produk',
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  AppTheme.spacingMD,
                  0,
                  AppTheme.spacingMD,
                  AppTheme.spacingXL,
                ),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.62,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final product = state.products[index];
                      return ProductCard(
                        product: product,
                        onTap: () => context
                            .push(AppRoutes.productDetailPath(product.slug)),
                      );
                    },
                    childCount: state.products.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _StoreHeader extends StatelessWidget {
  final StoreModel store;
  final bool isFollowing;
  final bool isToggling;
  final VoidCallback onToggleFollow;

  const _StoreHeader({
    required this.store,
    required this.isFollowing,
    required this.isToggling,
    required this.onToggleFollow,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary;

    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingLG),
      color: isDark ? AppTheme.darkCard : AppTheme.cardWhite,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 60,
                height: 60,
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
                        errorWidget: (_, __, ___) => _StoreInitial(store.name),
                      )
                    : _StoreInitial(store.name),
              ),
              const SizedBox(width: AppTheme.spacingMD),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            store.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTheme.titleLg,
                          ),
                        ),
                        if (store.isVerified) ...[
                          const SizedBox(width: 5),
                          const AppIcon(
                            AppIcons.check,
                            size: AppIconSize.sm,
                            color: AppTheme.primary,
                            semanticsLabel: 'Toko terverifikasi',
                          ),
                        ],
                      ],
                    ),
                    Text(
                      '@${store.username}',
                      style: AppTheme.bodySm.copyWith(color: muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingMD),
          Row(
            children: [
              _Stat(label: 'Produk', value: '${store.productCount}'),
              const SizedBox(width: AppTheme.spacingXL),
              _Stat(label: 'Transaksi', value: '${store.transactionCount}'),
              if (store.city != null) ...[
                const SizedBox(width: AppTheme.spacingXL),
                Flexible(child: _Stat(label: 'Kota', value: store.city!)),
              ],
            ],
          ),
          if (store.about != null && store.about!.isNotEmpty) ...[
            const SizedBox(height: AppTheme.spacingMD),
            Text(
              store.about!,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: AppTheme.bodySm.copyWith(color: muted),
            ),
          ],
          const SizedBox(height: AppTheme.spacingLG),
          SizedBox(
            width: double.infinity,
            height: 42,
            child: isFollowing
                ? OutlinedButton.icon(
                    onPressed: isToggling ? null : onToggleFollow,
                    icon: const AppIcon(AppIcons.check, size: AppIconSize.sm),
                    label: const Text('Mengikuti'),
                  )
                : FilledButton.icon(
                    onPressed: isToggling ? null : onToggleFollow,
                    icon: const AppIcon(AppIcons.plus, size: AppIconSize.sm),
                    label: const Text('Ikuti Toko'),
                  ),
          ),
        ],
      ),
    );
  }
}

class _StoreInitial extends StatelessWidget {
  final String name;

  const _StoreInitial(this.name);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : 'S',
        style: AppTheme.displayMd.copyWith(
          color: isDark ? AppTheme.darkPrimary : AppTheme.primary,
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;

  const _Stat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTheme.titleMd,
        ),
        Text(label, style: AppTheme.labelSm.copyWith(color: muted)),
      ],
    );
  }
}

class _ReviewStrip extends StatelessWidget {
  final List<ReviewModel> reviews;

  const _ReviewStrip({required this.reviews});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppTheme.spacingLG,
            AppTheme.spacingLG,
            AppTheme.spacingLG,
            AppTheme.spacingSM,
          ),
          child: Text('Ulasan Pembeli', style: AppTheme.titleLg),
        ),
        SizedBox(
          height: 116,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding:
                const EdgeInsets.symmetric(horizontal: AppTheme.spacingLG),
            itemCount: reviews.length,
            separatorBuilder: (_, __) =>
                const SizedBox(width: AppTheme.spacingMD),
            itemBuilder: (context, index) {
              final review = reviews[index];
              return Container(
                width: 240,
                padding: const EdgeInsets.all(AppTheme.spacingMD),
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
                      children: List.generate(
                        5,
                        (i) => AppIcon(
                          i < review.rating
                              ? AppIcons.starFilled
                              : AppIcons.star,
                          size: 13,
                          color: i < review.rating
                              ? AppTheme.warning
                              : muted,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Expanded(
                      child: Text(
                        review.review?.isNotEmpty == true
                            ? review.review!
                            : 'Tanpa komentar',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTheme.bodySm,
                      ),
                    ),
                    Text(
                      review.userName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.labelSm.copyWith(color: muted),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
