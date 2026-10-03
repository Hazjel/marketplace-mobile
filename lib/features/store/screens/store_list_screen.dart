import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:blukios_marketplace/config/app_theme.dart';
import 'package:blukios_marketplace/config/routes.dart';
import 'package:blukios_marketplace/features/store/models/store_model.dart';
import 'package:blukios_marketplace/features/store/viewmodels/store_viewmodel.dart';
import 'package:blukios_marketplace/shared/widgets/app_icon.dart';
import 'package:blukios_marketplace/shared/widgets/app_scaffold.dart';
import 'package:blukios_marketplace/shared/widgets/state_views.dart';

/// Stores whose name, city or address contains [query], like the web's filter.
List<StoreModel> filterStores(List<StoreModel> stores, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return stores;
  return stores
      .where((s) =>
          s.name.toLowerCase().contains(q) ||
          (s.city ?? '').toLowerCase().contains(q) ||
          (s.address ?? '').toLowerCase().contains(q))
      .toList();
}

/// "Semua Toko", the mobile counterpart of the web's AllStores page.
class StoreListScreen extends ConsumerStatefulWidget {
  const StoreListScreen({super.key});

  @override
  ConsumerState<StoreListScreen> createState() => _StoreListScreenState();
}

class _StoreListScreenState extends ConsumerState<StoreListScreen> {
  String _query = '';

  Future<void> _reload() => ref.refresh(allStoresProvider.future);

  @override
  Widget build(BuildContext context) {
    final stores = ref.watch(allStoresProvider);

    return AppScaffold(
      title: 'Semua Toko',
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppTheme.spacingLG),
            child: TextField(
              onChanged: (value) => setState(() => _query = value),
              decoration: const InputDecoration(
                hintText: 'Cari nama toko atau kota',
                prefixIcon: Padding(
                  padding: EdgeInsets.all(12),
                  child: AppIcon(AppIcons.search, size: AppIconSize.sm),
                ),
              ),
            ),
          ),
          Expanded(
            child: stores.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) =>
                  ErrorState(message: error.toString(), onRetry: _reload),
              data: (all) {
                final shown = filterStores(all, _query);
                if (shown.isEmpty) {
                  return EmptyState(
                    icon: all.isEmpty ? AppIcons.store : AppIcons.searchEmpty,
                    title: all.isEmpty ? 'Belum ada toko' : 'Toko tidak ditemukan',
                    message: all.isEmpty ? null : 'Coba kata kunci lain',
                  );
                }
                return RefreshIndicator(
                  onRefresh: _reload,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(AppTheme.spacingLG, 0,
                        AppTheme.spacingLG, AppTheme.spacingLG),
                    itemCount: shown.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: AppTheme.spacingSM),
                    itemBuilder: (context, i) => _StoreTile(store: shown[i]),
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

class _StoreTile extends StatelessWidget {
  final StoreModel store;

  const _StoreTile({required this.store});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary;
    final fallback = Center(
      child: AppIcon(AppIcons.store,
          color: isDark ? AppTheme.darkPrimary : AppTheme.primary),
    );

    return ListTile(
      onTap: () => context.push(AppRoutes.storeDetailPath(store.username)),
      contentPadding: EdgeInsets.zero,
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.radius2XL),
        child: SizedBox(
          width: 48,
          height: 48,
          child: store.logo != null
              ? CachedNetworkImage(
                  imageUrl: store.logo!,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => fallback,
                )
              : fallback,
        ),
      ),
      title: Row(
        children: [
          Flexible(
            child: Text(store.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTheme.titleSm),
          ),
          if (store.isVerified) ...[
            const SizedBox(width: 4),
            const AppIcon(AppIcons.check,
                size: AppIconSize.sm,
                color: AppTheme.primary,
                semanticsLabel: 'Toko terverifikasi'),
          ],
        ],
      ),
      subtitle: Text(
        [
          if (store.city != null) store.city!,
          '${store.productCount} produk',
        ].join(' · '),
        style: AppTheme.labelSm.copyWith(color: muted),
      ),
      trailing: const AppIcon(AppIcons.chevronRight, size: AppIconSize.sm),
    );
  }
}
