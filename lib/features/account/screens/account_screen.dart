import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:blukios_marketplace/config/app_theme.dart';
import 'package:blukios_marketplace/config/routes.dart';
import 'package:blukios_marketplace/features/account/viewmodels/account_viewmodel.dart';
import 'package:blukios_marketplace/features/auth/viewmodels/auth_viewmodel.dart';
import 'package:blukios_marketplace/shared/widgets/app_icon.dart';
import 'package:blukios_marketplace/shared/widgets/app_scaffold.dart';

class AccountScreen extends ConsumerStatefulWidget {
  const AccountScreen({super.key});

  @override
  ConsumerState<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends ConsumerState<AccountScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(accountProvider.notifier).loadProfile();
    });
  }

  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Keluar dari akun?'),
        content: const Text('Kamu perlu masuk lagi untuk berbelanja.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppTheme.error),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    await ref.read(authProvider.notifier).logout();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(accountProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted =
        isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary;

    return AppScaffold(
      title: 'Akun',
      isTabRoot: true,
      body: ListView(
        padding: const EdgeInsets.only(bottom: AppTheme.spacingXL),
        children: [
          _ProfileCard(state: state, muted: muted),
          const SizedBox(height: AppTheme.spacingSM),

          _MenuSection(
            title: 'Belanja',
            children: [
              _MenuTile(
                icon: AppIcons.transaction,
                label: 'Transaksi Saya',
                onTap: () => context.go(AppRoutes.transactions),
              ),
              _MenuTile(
                icon: AppIcons.heart,
                label: 'Wishlist',
                onTap: () => context.go(AppRoutes.wishlist),
              ),
              _MenuTile(
                icon: AppIcons.cart,
                label: 'Keranjang',
                onTap: () => context.push(AppRoutes.cart),
              ),
            ],
          ),

          _MenuSection(
            title: 'Pengaturan',
            children: [
              _MenuTile(
                icon: AppIcons.mapPin,
                label: 'Alamat Saya',
                onTap: () => context.push(AppRoutes.addresses),
              ),
              _MenuTile(
                icon: AppIcons.bell,
                label: 'Notifikasi',
                onTap: () => context.push(AppRoutes.notificationSettings),
              ),
              _MenuTile(
                icon: AppIcons.shield,
                label: 'Privasi',
                onTap: () => context.push(AppRoutes.privacySettings),
              ),
            ],
          ),

          // Logout sits in its own group, visually separated from ordinary
          // navigation — a destructive action shouldn't sit in the same
          // list as "Wishlist".
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.spacingLG,
              AppTheme.spacingLG,
              AppTheme.spacingLG,
              0,
            ),
            child: OutlinedButton.icon(
              onPressed: _confirmLogout,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.error,
                side: const BorderSide(color: AppTheme.error),
                minimumSize: const Size.fromHeight(48),
              ),
              icon: const AppIcon(
                AppIcons.logout,
                size: AppIconSize.md,
                color: AppTheme.error,
              ),
              label: const Text('Keluar'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  final AccountData state;
  final Color muted;

  const _ProfileCard({required this.state, required this.muted});

  @override
  Widget build(BuildContext context) {
    final user = state.user;
    final initial =
        (user?.name.isNotEmpty ?? false) ? user!.name[0].toUpperCase() : '?';

    return Container(
      margin: const EdgeInsets.all(AppTheme.spacingLG),
      padding: const EdgeInsets.all(AppTheme.spacingLG),
      decoration: BoxDecoration(
        gradient: AppTheme.blukiosGradient,
        borderRadius: BorderRadius.circular(AppTheme.radius2XL),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(
              color: Colors.white24,
              shape: BoxShape.circle,
            ),
            clipBehavior: Clip.antiAlias,
            child: user?.profilePicture != null
                ? CachedNetworkImage(
                    imageUrl: user!.profilePicture!,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => _InitialAvatar(initial),
                  )
                : _InitialAvatar(initial),
          ),
          const SizedBox(width: AppTheme.spacingMD),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  user?.name ?? 'Memuat…',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.titleLg.copyWith(color: Colors.white),
                ),
                const SizedBox(height: 2),
                Text(
                  user?.email ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.bodySm.copyWith(color: Colors.white70),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => context.push(AppRoutes.editProfile),
            icon: const AppIcon(
              AppIcons.settings,
              size: AppIconSize.md,
              color: Colors.white,
              semanticsLabel: 'Ubah profil',
            ),
          ),
        ],
      ),
    );
  }
}

class _InitialAvatar extends StatelessWidget {
  final String initial;

  const _InitialAvatar(this.initial);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        initial,
        style: AppTheme.displayMd.copyWith(color: Colors.white),
      ),
    );
  }
}

class _MenuSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _MenuSection({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppTheme.spacingLG,
            AppTheme.spacingMD,
            AppTheme.spacingLG,
            AppTheme.spacingSM,
          ),
          child: Text(
            title,
            style: AppTheme.labelMd.copyWith(
              color:
                  isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
            ),
          ),
        ),
        Container(
          margin:
              const EdgeInsets.symmetric(horizontal: AppTheme.spacingLG),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkCard : AppTheme.cardWhite,
            borderRadius: BorderRadius.circular(AppTheme.radius2XL),
            border: Border.all(
              color: isDark ? AppTheme.darkBorder : AppTheme.border,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(children: children),
        ),
      ],
    );
  }
}

class _MenuTile extends StatelessWidget {
  final String icon;
  final String label;
  final VoidCallback onTap;

  const _MenuTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted =
        isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary;

    return InkWell(
      onTap: onTap,
      child: Padding(
        // 14px vertical + 20px icon clears the 44pt minimum touch target.
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacingLG,
          vertical: 14,
        ),
        child: Row(
          children: [
            AppIcon(icon, size: AppIconSize.md, color: muted),
            const SizedBox(width: AppTheme.spacingMD),
            Expanded(child: Text(label, style: AppTheme.titleMd)),
            AppIcon(AppIcons.chevronRight, size: AppIconSize.md, color: muted),
          ],
        ),
      ),
    );
  }
}
