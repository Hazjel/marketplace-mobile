import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:blukios_marketplace/config/app_theme.dart';
import 'package:blukios_marketplace/core/utils/currency_formatter.dart';
import 'package:blukios_marketplace/features/seller/wallet/models/seller_wallet_model.dart';
import 'package:blukios_marketplace/features/seller/wallet/viewmodels/seller_wallet_viewmodel.dart';
import 'package:blukios_marketplace/shared/widgets/app_scaffold.dart';

const _bankOptions = <(String, String)>[
  ('bca', 'BCA'),
  ('mandiri', 'Mandiri'),
  ('bni', 'BNI'),
  ('bri', 'BRI'),
];

/// Push with `extra: StoreBalanceModel` (the caller's already-loaded
/// balance) so the store balance id is available without a refetch.
class WithdrawalFormScreen extends ConsumerStatefulWidget {
  final StoreBalanceModel balance;

  const WithdrawalFormScreen({super.key, required this.balance});

  @override
  ConsumerState<WithdrawalFormScreen> createState() =>
      _WithdrawalFormScreenState();
}

class _WithdrawalFormScreenState extends ConsumerState<WithdrawalFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _bankAccountNameController = TextEditingController();
  final _bankAccountNumberController = TextEditingController();
  String? _bankName;

  @override
  void dispose() {
    _amountController.dispose();
    _bankAccountNameController.dispose();
    _bankAccountNumberController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_bankName == null) return;

    final amount = double.tryParse(_amountController.text.trim()) ?? 0;
    final notifier = ref.read(withdrawalFormProvider.notifier);
    final result = await notifier.submit(
      storeBalanceId: widget.balance.id,
      amount: amount,
      bankAccountName: _bankAccountNameController.text.trim(),
      bankAccountNumber: _bankAccountNumberController.text.trim(),
      bankName: _bankName!,
    );

    if (!mounted) return;
    if (result != null) {
      // Refresh the wallet screen's data so the new request appears without
      // the user needing to pull-to-refresh manually.
      ref.read(sellerWalletProvider.notifier).loadAll();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Permintaan penarikan berhasil diajukan')),
      );
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final formState = ref.watch(withdrawalFormProvider);

    return AppScaffold(
      title: 'Ajukan Penarikan',
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppTheme.spacingLG),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(AppTheme.spacingLG),
                  decoration: BoxDecoration(
                    gradient: AppTheme.blukiosGradient,
                    borderRadius: BorderRadius.circular(AppTheme.radius2XL),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Saldo Tersedia',
                        style: AppTheme.labelMd.copyWith(color: Colors.white70),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        CurrencyFormatter.formatRupiah(widget.balance.balance),
                        style: AppTheme.priceLg.copyWith(color: Colors.white),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppTheme.spacingLG),

                if (formState.error != null) ...[
                  Container(
                    padding: const EdgeInsets.all(AppTheme.spacingMD),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(AppTheme.radiusXLCard),
                    ),
                    child: Text(
                      formState.error!,
                      style: const TextStyle(color: Color(0xFFDC2626), fontSize: 13),
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingLG),
                ],

                TextFormField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: false),
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(labelText: 'Jumlah Penarikan (Rp)'),
                  validator: (v) {
                    final value = double.tryParse((v ?? '').trim());
                    if (value == null || value <= 0) {
                      return 'Jumlah penarikan wajib diisi';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppTheme.spacingMD),

                DropdownButtonFormField<String>(
                  initialValue: _bankName,
                  decoration: const InputDecoration(labelText: 'Nama Bank'),
                  items: [
                    for (final (value, label) in _bankOptions)
                      DropdownMenuItem(value: value, child: Text(label)),
                  ],
                  onChanged: (value) => setState(() => _bankName = value),
                  validator: (v) => v == null ? 'Pilih bank tujuan' : null,
                ),
                const SizedBox(height: AppTheme.spacingMD),

                TextFormField(
                  controller: _bankAccountNameController,
                  decoration: const InputDecoration(labelText: 'Nama Pemilik Rekening'),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Nama pemilik rekening wajib diisi' : null,
                ),
                const SizedBox(height: AppTheme.spacingMD),

                TextFormField(
                  controller: _bankAccountNumberController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(labelText: 'Nomor Rekening'),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Nomor rekening wajib diisi' : null,
                ),
                const SizedBox(height: AppTheme.spacingXL),

                SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: formState.isSubmitting ? null : _submit,
                    child: formState.isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Ajukan Sekarang'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
