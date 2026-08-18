import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:blukios_marketplace/config/app_theme.dart';
import 'package:blukios_marketplace/config/routes.dart';
import 'package:blukios_marketplace/core/utils/currency_formatter.dart';
import 'package:blukios_marketplace/core/utils/date_formatter.dart';
import 'package:blukios_marketplace/features/seller/voucher/models/seller_voucher_model.dart';
import 'package:blukios_marketplace/features/seller/voucher/viewmodels/seller_voucher_viewmodel.dart';
import 'package:blukios_marketplace/shared/widgets/app_icon.dart';
import 'package:blukios_marketplace/shared/widgets/app_scaffold.dart';
import 'package:blukios_marketplace/shared/widgets/skeletons.dart';
import 'package:blukios_marketplace/shared/widgets/state_views.dart';

/// Seller Centre "Voucher Toko" — lists this seller's own discount codes,
/// with create/edit/delete entry points. Mirrors
/// `SellerProductListScreen`'s structure.
class SellerVoucherListScreen extends ConsumerStatefulWidget {
  const SellerVoucherListScreen({super.key});

  @override
  ConsumerState<SellerVoucherListScreen> createState() =>
      _SellerVoucherListScreenState();
}

class _SellerVoucherListScreenState
    extends ConsumerState<SellerVoucherListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(sellerVoucherProvider.notifier).loadVouchers();
    });
  }

  Future<void> _delete(SellerVoucherModel voucher) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Voucher'),
        content: Text('Hapus voucher "${voucher.code}"?'),
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
        await ref.read(sellerVoucherProvider.notifier).deleteVoucher(voucher.id);
    if (!mounted) return;
    if (error != null) {
      // Covers both a generic failure and the backend's specific
      // "sudah pernah dipakai, nonaktifkan saja" message when the voucher
      // has redemption history — shown as-is, it's already a complete
      // user-facing sentence.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: AppTheme.error),
      );
    }
  }

  Future<void> _toggleActive(SellerVoucherModel voucher) async {
    final error = await ref.read(sellerVoucherProvider.notifier).updateVoucher(
          voucher.id,
          code: voucher.code,
          type: voucher.type,
          value: voucher.value,
          minPurchase: voucher.minPurchase,
          maxDiscount: voucher.maxDiscount,
          usageLimit: voucher.usageLimit,
          usageLimitPerBuyer: voucher.usageLimitPerBuyer,
          startsAt: voucher.startsAt,
          expiresAt: voucher.expiresAt,
          isActive: !voucher.isActive,
        );
    if (!mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: AppTheme.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(sellerVoucherProvider);
    final notifier = ref.read(sellerVoucherProvider.notifier);

    return AppScaffold(
      title: 'Voucher Toko',
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await context.push(AppRoutes.sellerVoucherForm);
          if (context.mounted) notifier.loadVouchers();
        },
        child: const AppIcon(
          AppIcons.plus,
          size: AppIconSize.lg,
          color: Colors.white,
          semanticsLabel: 'Tambah voucher',
        ),
      ),
      body: state.isLoading && state.vouchers.isEmpty
          ? const ListSkeleton()
          : state.error != null && state.vouchers.isEmpty
              ? ErrorState(message: state.error!, onRetry: notifier.loadVouchers)
              : state.vouchers.isEmpty
                  ? EmptyState(
                      icon: AppIcons.tag,
                      title: 'Belum ada voucher',
                      message: 'Buat voucher pertama untuk menarik pembeli',
                      actionLabel: 'Tambah Voucher',
                      onAction: () async {
                        await context.push(AppRoutes.sellerVoucherForm);
                        if (context.mounted) notifier.loadVouchers();
                      },
                    )
                  : RefreshIndicator(
                      onRefresh: notifier.loadVouchers,
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(
                          AppTheme.spacingLG,
                          AppTheme.spacingLG,
                          AppTheme.spacingLG,
                          88, // clears the FAB
                        ),
                        itemCount: state.vouchers.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: AppTheme.spacingMD),
                        itemBuilder: (context, index) {
                          final voucher = state.vouchers[index];
                          return _VoucherCard(
                            voucher: voucher,
                            isDeleting: state.deletingId == voucher.id,
                            onDelete: () => _delete(voucher),
                            onToggleActive: () => _toggleActive(voucher),
                            onEdit: () async {
                              await context.push(
                                AppRoutes.sellerVoucherForm,
                                extra: voucher,
                              );
                              if (context.mounted) notifier.loadVouchers();
                            },
                          );
                        },
                      ),
                    ),
    );
  }
}

String _formatValue(SellerVoucherModel voucher) {
  if (voucher.isPercentage) {
    final value = voucher.value;
    final trimmed =
        value == value.roundToDouble() ? value.toStringAsFixed(0) : value.toString();
    return '$trimmed%';
  }
  return CurrencyFormatter.formatRupiah(voucher.value);
}

class _VoucherCard extends StatelessWidget {
  final SellerVoucherModel voucher;
  final bool isDeleting;
  final VoidCallback onDelete;
  final VoidCallback onToggleActive;
  final VoidCallback onEdit;

  const _VoucherCard({
    required this.voucher,
    required this.isDeleting,
    required this.onDelete,
    required this.onToggleActive,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary;

    return Opacity(
      opacity: isDeleting ? 0.5 : 1,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radius2XL),
        onTap: isDeleting ? null : onEdit,
        child: Container(
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spacingMD,
                      vertical: AppTheme.spacingSM,
                    ),
                    decoration: BoxDecoration(
                      color: (isDark ? AppTheme.darkPrimary : AppTheme.primary)
                          .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppTheme.radiusLG),
                    ),
                    child: AppIcon(
                      AppIcons.tag,
                      size: AppIconSize.md,
                      color: isDark ? AppTheme.darkPrimary : AppTheme.primary,
                    ),
                  ),
                  const SizedBox(width: AppTheme.spacingMD),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(voucher.code, style: AppTheme.titleSm),
                        const SizedBox(height: 2),
                        Text(
                          '${voucher.isPercentage ? 'Diskon' : 'Potongan'} ${_formatValue(voucher)}',
                          style: AppTheme.priceSm.copyWith(
                            color: isDark ? AppTheme.darkPrimary : AppTheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: voucher.isActive,
                    onChanged: isDeleting ? null : (_) => onToggleActive(),
                  ),
                  IconButton(
                    onPressed: isDeleting ? null : onDelete,
                    icon: const AppIcon(
                      AppIcons.trash,
                      size: AppIconSize.md,
                      color: AppTheme.error,
                      semanticsLabel: 'Hapus voucher',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.spacingSM),
              Wrap(
                spacing: AppTheme.spacingMD,
                runSpacing: 4,
                children: [
                  if (voucher.minPurchase != null)
                    Text(
                      'Min. belanja ${CurrencyFormatter.formatRupiah(voucher.minPurchase)}',
                      style: AppTheme.labelSm.copyWith(color: muted),
                    ),
                  if (voucher.isPercentage && voucher.maxDiscount != null)
                    Text(
                      'Maks. diskon ${CurrencyFormatter.formatRupiah(voucher.maxDiscount)}',
                      style: AppTheme.labelSm.copyWith(color: muted),
                    ),
                  Text(
                    'Terpakai ${voucher.redeemedCount}${voucher.usageLimit != null ? '/${voucher.usageLimit}' : ''}',
                    style: AppTheme.labelSm.copyWith(color: muted),
                  ),
                  if (voucher.expiresAt != null)
                    Text(
                      'Berlaku hingga ${DateFormatter.format(voucher.expiresAt!.toIso8601String())}',
                      style: AppTheme.labelSm.copyWith(
                        color: voucher.isExpired ? AppTheme.error : muted,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
