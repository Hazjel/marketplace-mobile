import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:blukios_marketplace/config/app_theme.dart';
import 'package:blukios_marketplace/core/utils/currency_formatter.dart';
import 'package:blukios_marketplace/core/utils/date_formatter.dart';
import 'package:blukios_marketplace/features/seller/orders/viewmodels/seller_order_detail_viewmodel.dart';
import 'package:blukios_marketplace/shared/widgets/app_icon.dart';
import 'package:blukios_marketplace/shared/widgets/app_scaffold.dart';
import 'package:blukios_marketplace/shared/widgets/skeletons.dart';
import 'package:blukios_marketplace/shared/widgets/state_views.dart';

/// Order detail for the seller: view items/buyer shipping info, and update
/// tracking number + delivery status.
///
/// Deliberately offers only `processing` and `delivering` as target
/// statuses — see the comment on
/// `TransactionRepository.updateDeliveryStatus` for why `completed` is
/// reserved for the buyer's own confirm-receipt action.
class SellerOrderDetailScreen extends ConsumerStatefulWidget {
  final String orderId;

  const SellerOrderDetailScreen({super.key, required this.orderId});

  @override
  ConsumerState<SellerOrderDetailScreen> createState() =>
      _SellerOrderDetailScreenState();
}

class _SellerOrderDetailScreenState
    extends ConsumerState<SellerOrderDetailScreen> {
  final _trackingController = TextEditingController();
  bool _trackingSynced = false;
  XFile? _pickedProof;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(sellerOrderDetailProvider(widget.orderId).notifier).load();
    });
  }

  @override
  void dispose() {
    _trackingController.dispose();
    super.dispose();
  }

  Future<void> _pickProof() async {
    final photo = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (photo == null) return;
    setState(() => _pickedProof = photo);
  }

  Future<void> _updateStatus(String deliveryStatus) async {
    final notifier =
        ref.read(sellerOrderDetailProvider(widget.orderId).notifier);
    final success = await notifier.updateStatus(
      deliveryStatus: deliveryStatus,
      trackingNumber: _trackingController.text.trim().isEmpty
          ? null
          : _trackingController.text.trim(),
      deliveryProofPath: _pickedProof?.path,
    );
    if (!mounted) return;

    if (success) {
      setState(() => _pickedProof = null);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Status pesanan berhasil diperbarui')),
      );
    } else {
      final error = ref.read(sellerOrderDetailProvider(widget.orderId)).updateError;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error ?? 'Gagal memperbarui status pesanan'),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }

  /// Asks for the reason the buyer will see, then rejects the order. The
  /// API refunds the buyer in full, so the dialog says so up front.
  Future<void> _rejectOrder() async {
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => const _RejectOrderDialog(),
    );
    if (reason == null || !mounted) return;

    final success = await ref
        .read(sellerOrderDetailProvider(widget.orderId).notifier)
        .cancel(reason: reason);
    if (!mounted) return;

    final error = ref.read(sellerOrderDetailProvider(widget.orderId)).updateError;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success
            ? 'Pesanan ditolak, dana pembeli sedang dikembalikan'
            : error ?? 'Gagal menolak pesanan'),
        backgroundColor: success ? null : AppTheme.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(sellerOrderDetailProvider(widget.orderId));
    final notifier = ref.read(sellerOrderDetailProvider(widget.orderId).notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary;

    final order = data.order;
    if (order != null && !_trackingSynced) {
      _trackingController.text = order.trackingNumber ?? '';
      _trackingSynced = true;
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        context.pop(order);
      },
      child: AppScaffold(
        title: 'Detail Pesanan',
        body: data.isLoading
            ? const DetailSkeleton()
            : data.error != null
                ? ErrorState(message: data.error!, onRetry: notifier.load)
                : order == null
                    ? const ErrorState(message: 'Pesanan tidak ditemukan')
                    : SingleChildScrollView(
                        padding: const EdgeInsets.all(AppTheme.spacingLG),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _SectionCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(order.code, style: AppTheme.titleMd),
                                      _StatusBadge(
                                        status: order.deliveryStatus,
                                        label: order.deliveryStatusLabel,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    DateFormatter.format(order.createdAt),
                                    style: AppTheme.labelSm.copyWith(color: muted),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: AppTheme.spacingMD),
                            _SectionCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Alamat Pengiriman', style: AppTheme.titleSm),
                                  const SizedBox(height: AppTheme.spacingSM),
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      AppIcon(AppIcons.mapPin, size: 16, color: muted),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          [
                                            if (order.address != null) order.address,
                                            if (order.city != null) order.city,
                                            if (order.postalCode != null) order.postalCode,
                                          ].whereType<String>().join(', '),
                                          style: AppTheme.bodyMd.copyWith(color: muted),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (order.shipping != null) ...[
                                    const SizedBox(height: AppTheme.spacingSM),
                                    Row(
                                      children: [
                                        AppIcon(AppIcons.truck, size: 16, color: muted),
                                        const SizedBox(width: 6),
                                        Text(
                                          '${order.shipping}${order.shippingType != null ? ' (${order.shippingType})' : ''}',
                                          style: AppTheme.bodyMd.copyWith(color: muted),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(height: AppTheme.spacingMD),
                            _SectionCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Produk', style: AppTheme.titleSm),
                                  const SizedBox(height: AppTheme.spacingSM),
                                  for (final item in order.transactionDetails)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              '${item.qty}x ${item.productName ?? 'Produk'}',
                                              style: AppTheme.bodyMd,
                                            ),
                                          ),
                                          Text(
                                            CurrencyFormatter.formatRupiah(item.subtotal),
                                            style: AppTheme.bodyMd.copyWith(
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  Divider(
                                    height: AppTheme.spacingLG,
                                    color: isDark ? AppTheme.darkBorder : AppTheme.border,
                                  ),
                                  _SummaryRow(
                                    label: 'Ongkos Kirim',
                                    value: CurrencyFormatter.formatRupiah(order.shippingCost),
                                  ),
                                  // Orders since 2026-10-02 carry no tax; only older ones show it.
                                  if (order.tax > 0)
                                    _SummaryRow(
                                      label: 'PPN 11%',
                                      value: CurrencyFormatter.formatRupiah(order.tax),
                                    ),
                                  if (order.discountAmount > 0)
                                    _SummaryRow(
                                      label: 'Diskon Voucher',
                                      value: '-${CurrencyFormatter.formatRupiah(order.discountAmount)}',
                                    ),
                                  if (order.serviceFee > 0)
                                    _SummaryRow(
                                      label: 'Biaya Layanan',
                                      value: CurrencyFormatter.formatRupiah(order.serviceFee),
                                    ),
                                  const SizedBox(height: 4),
                                  _SummaryRow(
                                    label: 'Total Pesanan',
                                    value: CurrencyFormatter.formatRupiah(order.grandTotal),
                                    emphasize: true,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: AppTheme.spacingMD),
                            if (order.deliveryStatus == 'completed') ...[
                              _SectionCard(
                                child: Row(
                                  children: [
                                    const AppIcon(AppIcons.check, color: AppTheme.success),
                                    const SizedBox(width: AppTheme.spacingSM),
                                    Expanded(
                                      child: Text(
                                        'Pesanan ini sudah diselesaikan oleh pembeli.',
                                        style: AppTheme.bodyMd.copyWith(color: muted),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ] else if (order.deliveryStatus == 'cancelled') ...[
                              _SectionCard(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const AppIcon(AppIcons.close, color: AppTheme.error),
                                        const SizedBox(width: AppTheme.spacingSM),
                                        Expanded(
                                          child: Text('Pesanan dibatalkan', style: AppTheme.titleSm),
                                        ),
                                        if (order.refundStatus case final refund?)
                                          _StatusBadge(
                                            status: refund,
                                            label: order.refundStatusLabel ?? refund,
                                          ),
                                      ],
                                    ),
                                    if (order.refundReason != null) ...[
                                      const SizedBox(height: AppTheme.spacingSM),
                                      Text(
                                        'Alasan: ${order.refundReason}',
                                        style: AppTheme.bodySm.copyWith(color: muted),
                                      ),
                                    ],
                                    if (order.refundStatus != null) ...[
                                      const SizedBox(height: AppTheme.spacingSM),
                                      Text(
                                        'Stok sudah dikembalikan dan dana pesanan ditarik dari saldo tertahan. '
                                        'Pengembalian dana ke pembeli diurus Blukios.',
                                        style: AppTheme.bodySm.copyWith(color: muted),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ] else ...[
                              _SectionCard(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Perbarui Pengiriman', style: AppTheme.titleSm),
                                    const SizedBox(height: AppTheme.spacingSM),
                                    TextField(
                                      controller: _trackingController,
                                      decoration: const InputDecoration(
                                        labelText: 'Nomor Resi',
                                        hintText: 'Masukkan nomor resi pengiriman',
                                      ),
                                    ),
                                    // Proof photo is only offered while `processing` — it's
                                    // attached when marking the order as shipped, mirroring
                                    // the web seller centre's flow.
                                    if (order.deliveryStatus == 'processing') ...[
                                      const SizedBox(height: AppTheme.spacingMD),
                                      Text('Bukti Pengiriman (opsional)', style: AppTheme.labelMd),
                                      const SizedBox(height: AppTheme.spacingSM),
                                      GestureDetector(
                                        onTap: _pickProof,
                                        child: Container(
                                          height: 120,
                                          width: 120,
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(AppTheme.radiusLG),
                                            border: Border.all(
                                              color: isDark ? AppTheme.darkBorder : AppTheme.border,
                                            ),
                                          ),
                                          clipBehavior: Clip.antiAlias,
                                          child: _pickedProof != null
                                              ? Stack(
                                                  fit: StackFit.expand,
                                                  children: [
                                                    Image.file(File(_pickedProof!.path), fit: BoxFit.cover),
                                                    Positioned(
                                                      top: 4,
                                                      right: 4,
                                                      child: GestureDetector(
                                                        onTap: () => setState(() => _pickedProof = null),
                                                        child: Container(
                                                          padding: const EdgeInsets.all(2),
                                                          decoration: const BoxDecoration(
                                                            color: Colors.black54,
                                                            shape: BoxShape.circle,
                                                          ),
                                                          child: const AppIcon(
                                                            AppIcons.close,
                                                            size: AppIconSize.sm,
                                                            color: Colors.white,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                )
                                              : order.deliveryProof != null
                                                  ? CachedNetworkImage(
                                                      imageUrl: order.deliveryProof!,
                                                      fit: BoxFit.cover,
                                                      errorWidget: (_, __, ___) =>
                                                          _ProofPlaceholder(muted: muted),
                                                    )
                                                  : _ProofPlaceholder(muted: muted),
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: AppTheme.spacingMD),
                                    // Only `processing` and `delivering` are offered — see
                                    // the class doc comment for why `completed` is excluded.
                                    Row(
                                      children: [
                                        Expanded(
                                          child: OutlinedButton(
                                            onPressed: data.isUpdating ||
                                                    order.deliveryStatus == 'processing'
                                                ? null
                                                : () => _updateStatus('processing'),
                                            child: const Text('Tandai Diproses'),
                                          ),
                                        ),
                                        const SizedBox(width: AppTheme.spacingSM),
                                        Expanded(
                                          child: ElevatedButton(
                                            onPressed: data.isUpdating ||
                                                    order.deliveryStatus == 'delivering'
                                                ? null
                                                : () => _updateStatus('delivering'),
                                            child: data.isUpdating
                                                ? const SizedBox(
                                                    width: 18,
                                                    height: 18,
                                                    child: CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                      color: Colors.white,
                                                    ),
                                                  )
                                                : const Text('Tandai Dikirim'),
                                          ),
                                        ),
                                      ],
                                    ),
                                    // Same rule as the API: paid and not shipped yet.
                                    if (order.paymentStatus == 'paid' &&
                                        const ['pending', 'processing']
                                            .contains(order.deliveryStatus)) ...[
                                      const SizedBox(height: AppTheme.spacingSM),
                                      SizedBox(
                                        width: double.infinity,
                                        child: TextButton(
                                          onPressed: data.isUpdating ? null : _rejectOrder,
                                          style: TextButton.styleFrom(
                                            foregroundColor: AppTheme.error,
                                          ),
                                          child: const Text('Tolak Pesanan'),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
      ),
    );
  }
}

class _RejectOrderDialog extends StatefulWidget {
  const _RejectOrderDialog();

  @override
  State<_RejectOrderDialog> createState() => _RejectOrderDialogState();
}

class _RejectOrderDialogState extends State<_RejectOrderDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // The API accepts 5-255 characters.
  bool get _valid => _controller.text.trim().length >= 5;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Tolak Pesanan?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Stok dikembalikan dan pembeli mendapat refund penuh.'),
          const SizedBox(height: AppTheme.spacingMD),
          TextField(
            controller: _controller,
            maxLength: 255,
            maxLines: 3,
            minLines: 1,
            autofocus: true,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Alasan (dilihat pembeli)',
              hintText: 'Contoh: stok habis',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Batal'),
        ),
        TextButton(
          onPressed: _valid ? () => Navigator.of(context).pop(_controller.text.trim()) : null,
          style: TextButton.styleFrom(foregroundColor: AppTheme.error),
          child: const Text('Tolak'),
        ),
      ],
    );
  }
}

class _ProofPlaceholder extends StatelessWidget {
  final Color muted;

  const _ProofPlaceholder({required this.muted});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppIcon(AppIcons.image, size: AppIconSize.lg, color: muted),
          const SizedBox(height: 4),
          Text('Tambah Foto', style: AppTheme.labelSm.copyWith(color: muted)),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final Widget child;

  const _SectionCard({required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTheme.spacingLG),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : AppTheme.cardWhite,
        borderRadius: BorderRadius.circular(AppTheme.radius2XL),
        border: Border.all(color: isDark ? AppTheme.darkBorder : AppTheme.border),
      ),
      child: child,
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final bool emphasize;

  const _SummaryRow({required this.label, required this.value, this.emphasize = false});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: emphasize
                ? AppTheme.bodyMd.copyWith(fontWeight: FontWeight.w600)
                : AppTheme.bodySm.copyWith(color: muted),
          ),
          Text(
            value,
            style: emphasize
                ? AppTheme.priceSm.copyWith(
                    color: isDark ? AppTheme.darkPrimary : AppTheme.primary,
                  )
                : AppTheme.bodySm.copyWith(color: muted),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  final String label;

  const _StatusBadge({required this.status, required this.label});

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (status) {
      'completed' => (const Color(0xFFDCFCE7), const Color(0xFF16A34A)),
      'delivering' => (const Color(0xFFDBEAFE), const Color(0xFF2563EB)),
      'processing' => (const Color(0xFFFEF9C3), const Color(0xFFCA8A04)),
      'cancelled' => (const Color(0xFFFEE2E2), const Color(0xFFDC2626)),
      'refunded' => (const Color(0xFFDCFCE7), const Color(0xFF16A34A)),
      'manual_required' => (const Color(0xFFFEF3C7), const Color(0xFFB45309)),
      _ => (const Color(0xFFF3F4F6), const Color(0xFF6B7280)),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppTheme.radiusFull),
      ),
      child: Text(
        label,
        style: AppTheme.labelSm.copyWith(color: fg, fontWeight: FontWeight.w600),
      ),
    );
  }
}
