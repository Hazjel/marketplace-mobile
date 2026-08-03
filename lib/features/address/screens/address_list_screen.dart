import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:blukios_marketplace/config/app_theme.dart';
import 'package:blukios_marketplace/config/routes.dart';
import 'package:blukios_marketplace/features/address/models/address_model.dart';
import 'package:blukios_marketplace/features/address/viewmodels/address_viewmodel.dart';
import 'package:blukios_marketplace/shared/widgets/app_icon.dart';
import 'package:blukios_marketplace/shared/widgets/app_scaffold.dart';
import 'package:blukios_marketplace/shared/widgets/skeletons.dart';
import 'package:blukios_marketplace/shared/widgets/state_views.dart';

class AddressListScreen extends ConsumerStatefulWidget {
  const AddressListScreen({super.key});

  @override
  ConsumerState<AddressListScreen> createState() => _AddressListScreenState();
}

class _AddressListScreenState extends ConsumerState<AddressListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(addressProvider.notifier).loadAddresses();
    });
  }

  Future<void> _delete(AddressModel address) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Alamat'),
        content: Text('Hapus alamat "${address.label}"?'),
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
        await ref.read(addressProvider.notifier).deleteAddress(address.id);
    if (!mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: AppTheme.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = ref.watch(addressProvider);
    final notifier = ref.read(addressProvider.notifier);

    return AppScaffold(
      title: 'Alamat Saya',
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push(AppRoutes.addressForm),
        child: const AppIcon(
          AppIcons.plus,
          size: AppIconSize.lg,
          color: Colors.white,
          semanticsLabel: 'Tambah alamat',
        ),
      ),
      body: viewModel.isLoading
          ? const ListSkeleton()
          : viewModel.error != null
              ? ErrorState(
                  message: viewModel.error!,
                  onRetry: notifier.loadAddresses,
                )
              : viewModel.addresses.isEmpty
                  ? EmptyState(
                      icon: AppIcons.mapPinOff,
                      title: 'Belum ada alamat',
                      message: 'Tambahkan alamat untuk mempercepat checkout',
                      actionLabel: 'Tambah Alamat',
                      onAction: () => context.push(AppRoutes.addressForm),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(
                        AppTheme.spacingLG,
                        AppTheme.spacingLG,
                        AppTheme.spacingLG,
                        88, // clears the FAB
                      ),
                      itemCount: viewModel.addresses.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: AppTheme.spacingMD),
                      itemBuilder: (context, index) => _AddressCard(
                        address: viewModel.addresses[index],
                        onDelete: _delete,
                      ),
                    ),
    );
  }
}

class _AddressCard extends StatelessWidget {
  final AddressModel address;
  final Future<void> Function(AddressModel) onDelete;

  const _AddressCard({required this.address, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary;

    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingLG),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : AppTheme.cardWhite,
        borderRadius: BorderRadius.circular(AppTheme.radius2XL),
        border: Border.all(
          color: address.isPrimary
              ? (isDark ? AppTheme.darkPrimary : AppTheme.primary)
              : (isDark ? AppTheme.darkBorder : AppTheme.border),
          width: address.isPrimary ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppIcon(AppIcons.mapPin, size: AppIconSize.sm, color: muted),
              const SizedBox(width: 6),
              Text(address.label, style: AppTheme.titleSm),
              if (address.isPrimary) ...[
                const SizedBox(width: AppTheme.spacingSM),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppTheme.darkIconBackground
                        : AppTheme.iconBackground,
                    borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                  ),
                  child: Text(
                    'UTAMA',
                    style: AppTheme.labelSm.copyWith(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: isDark ? AppTheme.darkPrimary : AppTheme.primary,
                    ),
                  ),
                ),
              ],
              const Spacer(),
              PopupMenuButton<String>(
                icon: AppIcon(
                  AppIcons.settings,
                  size: AppIconSize.md,
                  color: muted,
                  semanticsLabel: 'Opsi alamat',
                ),
                onSelected: (value) {
                  if (value == 'edit') {
                    context.push(AppRoutes.addressForm, extra: address);
                  } else if (value == 'delete') {
                    onDelete(address);
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
          const SizedBox(height: AppTheme.spacingSM),
          Text(
            '${address.recipientName} · ${address.phone}',
            style: AppTheme.bodyMd,
          ),
          const SizedBox(height: 4),
          Text(
            '${address.address}, ${address.city} ${address.postalCode}',
            style: AppTheme.bodySm.copyWith(color: muted),
          ),
        ],
      ),
    );
  }
}
