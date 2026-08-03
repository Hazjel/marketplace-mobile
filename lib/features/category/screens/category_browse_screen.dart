import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:blukios_marketplace/config/app_theme.dart';
import 'package:blukios_marketplace/config/routes.dart';
import 'package:blukios_marketplace/features/category/models/category_detail_model.dart';
import 'package:blukios_marketplace/features/category/viewmodels/category_viewmodel.dart';
import 'package:blukios_marketplace/shared/widgets/app_icon.dart';
import 'package:blukios_marketplace/shared/widgets/app_scaffold.dart';
import 'package:blukios_marketplace/shared/widgets/state_views.dart';

class CategoryBrowseScreen extends ConsumerStatefulWidget {
  const CategoryBrowseScreen({super.key});

  @override
  ConsumerState<CategoryBrowseScreen> createState() =>
      _CategoryBrowseScreenState();
}

class _CategoryBrowseScreenState extends ConsumerState<CategoryBrowseScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(categoryListProvider.notifier).loadCategories();
    });
  }

  void _openCategory(CategoryDetailModel category) {
    context.push(
      AppRoutes.search,
      extra: {'categoryId': category.id, 'categoryName': category.name},
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(categoryListProvider);

    return AppScaffold(
      title: 'Kategori',
      isTabRoot: true,
      body: _buildBody(state),
    );
  }

  Widget _buildBody(CategoryListData state) {
    final reload = ref.read(categoryListProvider.notifier).loadCategories;

    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.error != null && state.categories.isEmpty) {
      return ErrorState(message: state.error!, onRetry: reload);
    }

    if (state.categories.isEmpty) {
      return const EmptyState(
        icon: AppIcons.layers,
        title: 'Belum ada kategori',
        message: 'Kategori produk akan muncul di sini',
      );
    }

    return RefreshIndicator(
      onRefresh: reload,
      child: GridView.builder(
        padding: const EdgeInsets.all(AppTheme.spacingLG),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          childAspectRatio: 0.82,
          crossAxisSpacing: AppTheme.spacingMD,
          mainAxisSpacing: AppTheme.spacingLG,
        ),
        itemCount: state.categories.length,
        itemBuilder: (context, index) {
          final category = state.categories[index];
          return _CategoryTile(
            category: category,
            onTap: () => _openCategory(category),
          );
        },
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  final CategoryDetailModel category;
  final VoidCallback onTap;

  const _CategoryTile({required this.category, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusXLCard),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: isDark
                  ? AppTheme.darkIconBackground
                  : AppTheme.iconBackground,
              borderRadius: BorderRadius.circular(AppTheme.radius2XL),
            ),
            clipBehavior: Clip.antiAlias,
            child: category.image != null
                ? CachedNetworkImage(
                    imageUrl: category.image!,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => const _TileFallback(),
                  )
                : const _TileFallback(),
          ),
          const SizedBox(height: AppTheme.spacingSM),
          Flexible(
            child: Text(
              category.name,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTheme.titleSm,
            ),
          ),
          if (category.productCount > 0)
            Text(
              '${category.productCount} produk',
              style: AppTheme.labelSm.copyWith(color: muted),
            ),
        ],
      ),
    );
  }
}

class _TileFallback extends StatelessWidget {
  const _TileFallback();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: AppIcon(
        AppIcons.layers,
        size: AppIconSize.lg,
        color: isDark ? AppTheme.darkPrimary : AppTheme.primary,
      ),
    );
  }
}
