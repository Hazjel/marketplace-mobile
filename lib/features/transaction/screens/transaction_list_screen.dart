import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:blukios_marketplace/config/app_theme.dart';
import 'package:blukios_marketplace/config/routes.dart';
import 'package:blukios_marketplace/core/utils/currency_formatter.dart';
import 'package:blukios_marketplace/core/utils/date_formatter.dart';
import 'package:blukios_marketplace/features/transaction/models/transaction_model.dart';
import 'package:blukios_marketplace/features/transaction/viewmodels/transaction_viewmodel.dart';
import 'package:blukios_marketplace/shared/widgets/app_icon.dart';
import 'package:blukios_marketplace/shared/widgets/app_scaffold.dart';
import 'package:blukios_marketplace/shared/widgets/skeletons.dart';
import 'package:blukios_marketplace/shared/widgets/state_views.dart';

class TransactionListScreen extends ConsumerStatefulWidget {
  const TransactionListScreen({super.key});

  @override
  ConsumerState<TransactionListScreen> createState() =>
      _TransactionListScreenState();
}

class _TransactionListScreenState extends ConsumerState<TransactionListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(transactionProvider.notifier).loadTransactions();
    });
  }

  Future<void> _refreshStatus(TransactionModel trx) async {
    final error =
        await ref.read(transactionProvider.notifier).refreshStatus(trx.id);
    if (!mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: AppTheme.error),
      );
    }
  }

  Future<void> _reviewItem(TransactionModel trx, TransactionDetailModel item) async {
    final submitted = await context.push<bool>(
      AppRoutes.reviewFormPath(trx.id, item.productId),
      extra: {
        'productName': item.productName ?? 'Produk',
        'productThumbnail': item.productThumbnail,
      },
    );
    if (submitted == true) {
      ref.read(transactionProvider.notifier).markReviewed(trx.id, item.productId);
    }
  }

  Future<void> _completeOrder(TransactionModel trx) async {
    final picker = ImagePicker();
    final photo = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (photo == null) return;
    if (!mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Konfirmasi Pesanan Diterima'),
        content: const Text(
          'Pastikan barang sudah diterima dalam kondisi baik. Dana akan diteruskan ke penjual setelah ini.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Konfirmasi')),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!mounted) return;

    final error =
        await ref.read(transactionProvider.notifier).completeOrder(trx.id, photo.path);
    if (!mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: AppTheme.error),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pesanan selesai — dana diteruskan ke penjual')),
      );
    }
  }

  Future<void> _submitRefundAccount(TransactionModel trx) async {
    final account = await showModalBottomSheet<RefundAccount>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _RefundAccountSheet(initial: trx.refundAccount),
    );
    if (account == null || !mounted) return;

    final error = await ref.read(transactionProvider.notifier).submitRefundAccount(
          trx.id,
          bankName: account.bankName,
          accountNumber: account.accountNumber,
          accountName: account.accountName,
        );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error ?? 'Rekening refund tersimpan'),
        backgroundColor: error != null ? AppTheme.error : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = ref.watch(transactionProvider);
    final notifier = ref.read(transactionProvider.notifier);

    return AppScaffold(
      title: 'Transaksi',
      isTabRoot: true,
      body: viewModel.isLoading
          ? const ListSkeleton()
          : viewModel.error != null
              ? ErrorState(
                  message: viewModel.error!,
                  onRetry: notifier.loadTransactions,
                )
              : viewModel.transactions.isEmpty
                  ? const EmptyState(
                      icon: AppIcons.inbox,
                      title: 'Belum ada transaksi',
                      message: 'Transaksi kamu akan muncul di sini',
                    )
                  : RefreshIndicator(
                      onRefresh: notifier.loadTransactions,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(AppTheme.spacingLG),
                        itemCount: viewModel.transactions.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: AppTheme.spacingMD),
                        itemBuilder: (context, index) => _TransactionCard(
                          trx: viewModel.transactions[index],
                          onCheckStatus: _refreshStatus,
                          onReview: (item) => _reviewItem(viewModel.transactions[index], item),
                          onCompleteOrder: () => _completeOrder(viewModel.transactions[index]),
                          onRefundAccount: () =>
                              _submitRefundAccount(viewModel.transactions[index]),
                        ),
                      ),
                    ),
    );
  }
}

class _TransactionCard extends StatelessWidget {
  final TransactionModel trx;
  final Future<void> Function(TransactionModel) onCheckStatus;
  final Future<void> Function(TransactionDetailModel) onReview;
  final VoidCallback onCompleteOrder;
  final VoidCallback onRefundAccount;

  const _TransactionCard({
    required this.trx,
    required this.onCheckStatus,
    required this.onReview,
    required this.onCompleteOrder,
    required this.onRefundAccount,
  });

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
          color: isDark ? AppTheme.darkBorder : AppTheme.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  trx.code,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.titleSm,
                ),
              ),
              const SizedBox(width: AppTheme.spacingSM),
              // Cancelled after payment: payment_status turns 'failed', but
              // what the buyer cares about is the refund, not "Gagal".
              if (trx.refundStatus case final refund?)
                _StatusBadge(status: refund, label: trx.refundStatusLabel ?? refund)
              else
                _StatusBadge(
                  status: trx.paymentStatus,
                  label: trx.paymentStatusLabel,
                ),
              if (trx.paymentStatus == 'paid') ...[
                const SizedBox(width: 6),
                _StatusBadge(
                  status: trx.deliveryStatus,
                  label: trx.deliveryStatusLabel,
                ),
              ],
            ],
          ),
          const SizedBox(height: AppTheme.spacingSM),
          if (trx.storeName != null)
            Row(
              children: [
                AppIcon(AppIcons.store, size: 13, color: muted),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    trx.storeName!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.bodySm.copyWith(color: muted),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 3),
          Text(
            DateFormatter.format(trx.createdAt),
            style: AppTheme.labelSm.copyWith(color: muted),
          ),
          if (trx.paymentStatus == 'paid') ...[
            const SizedBox(height: AppTheme.spacingMD),
            _DeliveryStepper(status: trx.deliveryStatus),
          ],
          const SizedBox(height: AppTheme.spacingMD),
          Divider(
            height: 1,
            color: isDark ? AppTheme.darkBorder : AppTheme.border,
          ),
          if (trx.discountAmount > 0) ...[
            const SizedBox(height: AppTheme.spacingSM),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Diskon Voucher${trx.voucherCode != null ? ' (${trx.voucherCode})' : ''}',
                  style: AppTheme.labelSm.copyWith(color: muted),
                ),
                Text(
                  '-${CurrencyFormatter.formatRupiah(trx.discountAmount)}',
                  style: AppTheme.labelSm.copyWith(color: const Color(0xFF16A34A)),
                ),
              ],
            ),
          ],
          const SizedBox(height: AppTheme.spacingMD),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total Pembayaran',
                style: AppTheme.bodyMd.copyWith(color: muted),
              ),
              Text(
                CurrencyFormatter.formatRupiah(trx.grandTotal),
                style: AppTheme.priceSm.copyWith(
                  color: isDark ? AppTheme.darkPrimary : AppTheme.primary,
                ),
              ),
            ],
          ),
          if (trx.refundStatus != null) ...[
            const SizedBox(height: AppTheme.spacingMD),
            _RefundInfo(trx: trx, onRefundAccount: onRefundAccount),
          ],
          if (trx.paymentStatus == 'pending') ...[
            const SizedBox(height: AppTheme.spacingMD),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => onCheckStatus(trx),
                icon: const AppIcon(AppIcons.refresh, size: AppIconSize.sm),
                label: const Text('Cek Status Pembayaran'),
              ),
            ),
          ],
          if (trx.deliveryStatus == 'delivering') ...[
            const SizedBox(height: AppTheme.spacingMD),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onCompleteOrder,
                icon: const AppIcon(AppIcons.check, size: AppIconSize.sm, color: Colors.white),
                label: const Text('Konfirmasi Pesanan Diterima'),
              ),
            ),
          ],
          if (trx.deliveryStatus == 'completed') ...[
            for (final item in trx.transactionDetails)
              if (!trx.reviewedProductIds.contains(item.productId)) ...[
                const SizedBox(height: AppTheme.spacingSM),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => onReview(item),
                    child: Text(
                      'Beri Ulasan: ${item.productName ?? 'Produk'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
          ],
        ],
      ),
    );
  }
}

/// Refund for an order the seller rejected after payment. A bank VA payment
/// cannot be refunded automatically, so the buyer gives an account here.
class _RefundInfo extends StatelessWidget {
  final TransactionModel trx;
  final VoidCallback onRefundAccount;

  const _RefundInfo({required this.trx, required this.onRefundAccount});

  String get _description {
    switch (trx.refundStatus) {
      case 'processing':
        return 'Dana sedang dikembalikan ke metode pembayaranmu.';
      case 'manual_required':
        return trx.refundAccount == null
            ? 'Metode pembayaran ini tidak bisa direfund otomatis. Isi rekening tujuan, dana akan ditransfer oleh tim Blukios.'
            : 'Dana akan ditransfer oleh tim Blukios ke rekening di bawah.';
      case 'refunded':
        return trx.refundMethod == 'manual'
            ? 'Dana sudah ditransfer ke rekeningmu.'
            : 'Dana sudah dikembalikan. QRIS dan e-wallet bisa butuh beberapa hari sampai masuk.';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary;
    final account = trx.refundAccount;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTheme.spacingMD),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkBorder.withValues(alpha: 0.3) : const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(AppTheme.radiusLG),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Pengembalian Dana', style: AppTheme.labelMd),
              if (trx.refundAmount case final amount?)
                Text(
                  CurrencyFormatter.formatRupiah(amount),
                  style: AppTheme.labelMd,
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(_description, style: AppTheme.bodySm.copyWith(color: muted)),
          if (trx.refundReason != null) ...[
            const SizedBox(height: 4),
            Text(
              'Alasan penjual: ${trx.refundReason}',
              style: AppTheme.bodySm.copyWith(color: muted),
            ),
          ],
          if (account != null) ...[
            const SizedBox(height: AppTheme.spacingSM),
            Text(
              '${account.bankName} · ${account.accountNumber}\na.n. ${account.accountName}',
              style: AppTheme.bodySm,
            ),
          ],
          if (trx.awaitsManualRefund) ...[
            const SizedBox(height: AppTheme.spacingSM),
            SizedBox(
              width: double.infinity,
              child: account == null
                  ? ElevatedButton(
                      onPressed: onRefundAccount,
                      child: const Text('Isi Rekening Refund'),
                    )
                  : OutlinedButton(
                      onPressed: onRefundAccount,
                      child: const Text('Ubah Rekening'),
                    ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RefundAccountSheet extends StatefulWidget {
  final RefundAccount? initial;

  const _RefundAccountSheet({this.initial});

  @override
  State<_RefundAccountSheet> createState() => _RefundAccountSheetState();
}

class _RefundAccountSheetState extends State<_RefundAccountSheet> {
  // Same rule as the API: digits only, 5-30 long.
  static final _accountNumberPattern = RegExp(r'^[0-9]{5,30}$');

  final _formKey = GlobalKey<FormState>();
  late final _bank = TextEditingController(text: widget.initial?.bankName);
  late final _number = TextEditingController(text: widget.initial?.accountNumber);
  late final _name = TextEditingController(text: widget.initial?.accountName);

  @override
  void dispose() {
    _bank.dispose();
    _number.dispose();
    _name.dispose();
    super.dispose();
  }

  String? _required(String? value) =>
      (value == null || value.trim().isEmpty) ? 'Wajib diisi' : null;

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(RefundAccount(
      bankName: _bank.text.trim(),
      accountNumber: _number.text.trim(),
      accountName: _name.text.trim(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppTheme.spacingLG,
        AppTheme.spacingLG,
        AppTheme.spacingLG,
        MediaQuery.viewInsetsOf(context).bottom + AppTheme.spacingLG,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Rekening Tujuan Refund', style: AppTheme.titleSm),
            const SizedBox(height: AppTheme.spacingMD),
            TextFormField(
              controller: _bank,
              maxLength: 100,
              decoration: const InputDecoration(labelText: 'Nama Bank', hintText: 'Contoh: BCA'),
              validator: _required,
            ),
            TextFormField(
              controller: _number,
              maxLength: 30,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Nomor Rekening'),
              validator: (value) => _accountNumberPattern.hasMatch(value?.trim() ?? '')
                  ? null
                  : 'Hanya angka, 5-30 digit',
            ),
            TextFormField(
              controller: _name,
              maxLength: 100,
              decoration: const InputDecoration(labelText: 'Nama Pemilik Rekening'),
              validator: _required,
            ),
            const SizedBox(height: AppTheme.spacingSM),
            ElevatedButton(onPressed: _submit, child: const Text('Simpan Rekening')),
          ],
        ),
      ),
    );
  }
}

/// Horizontal pending → processing → delivering → completed timeline.
/// Reflects live updates arriving over Reverb without the user having to
/// pull to refresh — the current step just moves when a new event lands.
class _DeliveryStepper extends StatelessWidget {
  static const _steps = ['pending', 'processing', 'delivering', 'completed'];
  static const _labels = ['Menunggu', 'Diproses', 'Dikirim', 'Selesai'];

  final String status;

  const _DeliveryStepper({required this.status});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentIndex = _steps.indexOf(status);
    final activeColor = isDark ? AppTheme.darkPrimary : AppTheme.primary;
    final inactiveColor = isDark ? AppTheme.darkBorder : AppTheme.border;
    final mutedText = isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary;

    return Row(
      children: [
        for (var i = 0; i < _steps.length; i++) ...[
          if (i > 0)
            Expanded(
              child: Container(
                height: 2,
                color: i <= currentIndex ? activeColor : inactiveColor,
              ),
            ),
          Column(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i <= currentIndex ? activeColor : inactiveColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _labels[i],
                style: AppTheme.labelSm.copyWith(
                  color: i <= currentIndex ? activeColor : mutedText,
                  fontWeight: i == currentIndex ? FontWeight.w700 : FontWeight.normal,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ],
      ],
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
      'paid' || 'completed' || 'refunded' => (const Color(0xFFDCFCE7), const Color(0xFF16A34A)),
      'failed' || 'cancelled' || 'expired' => (
          const Color(0xFFFEE2E2),
          const Color(0xFFDC2626),
        ),
      'delivering' || 'processing' => (
          const Color(0xFFDBEAFE),
          const Color(0xFF2563EB),
        ),
      _ => (const Color(0xFFFEF9C3), const Color(0xFFCA8A04)),
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
