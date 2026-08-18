import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:blukios_marketplace/config/app_theme.dart';
import 'package:blukios_marketplace/core/utils/date_formatter.dart';
import 'package:blukios_marketplace/features/seller/voucher/models/seller_voucher_model.dart';
import 'package:blukios_marketplace/features/seller/voucher/viewmodels/seller_voucher_viewmodel.dart';
import 'package:blukios_marketplace/shared/widgets/app_icon.dart';
import 'package:blukios_marketplace/shared/widgets/app_scaffold.dart';

/// Uppercases voucher codes as the seller types — purely cosmetic, the
/// backend normalizes `code` to uppercase itself either way.
class _UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}

/// Create + edit voucher, in one screen — [existing] null means create.
class SellerVoucherFormScreen extends ConsumerStatefulWidget {
  final SellerVoucherModel? existing;

  const SellerVoucherFormScreen({super.key, this.existing});

  @override
  ConsumerState<SellerVoucherFormScreen> createState() =>
      _SellerVoucherFormScreenState();
}

class _SellerVoucherFormScreenState
    extends ConsumerState<SellerVoucherFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late final _codeController =
      TextEditingController(text: widget.existing?.code);
  late final _valueController = TextEditingController(
    text: widget.existing != null ? _trimDecimal(widget.existing!.value) : null,
  );
  late final _minPurchaseController = TextEditingController(
    text: widget.existing?.minPurchase != null
        ? _trimDecimal(widget.existing!.minPurchase!)
        : null,
  );
  late final _maxDiscountController = TextEditingController(
    text: widget.existing?.maxDiscount != null
        ? _trimDecimal(widget.existing!.maxDiscount!)
        : null,
  );
  late final _usageLimitController =
      TextEditingController(text: widget.existing?.usageLimit?.toString());
  late final _usageLimitPerBuyerController = TextEditingController(
    text: widget.existing?.usageLimitPerBuyer?.toString(),
  );

  late String _type = widget.existing?.type ?? 'fixed';
  late DateTime? _startsAt = widget.existing?.startsAt;
  late DateTime? _expiresAt = widget.existing?.expiresAt;
  late bool _isActive = widget.existing?.isActive ?? true;

  bool _isSaving = false;
  String? _errorMessage;

  bool get _isEditing => widget.existing != null;

  static String _trimDecimal(double value) {
    return value == value.roundToDouble()
        ? value.toStringAsFixed(0)
        : value.toString();
  }

  @override
  void dispose() {
    _codeController.dispose();
    _valueController.dispose();
    _minPurchaseController.dispose();
    _maxDiscountController.dispose();
    _usageLimitController.dispose();
    _usageLimitPerBuyerController.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isStart}) async {
    final now = DateTime.now();
    final initial = (isStart ? _startsAt : _expiresAt) ?? now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _startsAt = picked;
      } else {
        _expiresAt = picked;
      }
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    final notifier = ref.read(sellerVoucherProvider.notifier);
    final code = _codeController.text.trim().toUpperCase();
    final value = double.tryParse(_valueController.text.trim()) ?? 0;
    final minPurchase = _minPurchaseController.text.trim().isEmpty
        ? null
        : double.tryParse(_minPurchaseController.text.trim());
    final maxDiscount = _type != 'percentage' || _maxDiscountController.text.trim().isEmpty
        ? null
        : double.tryParse(_maxDiscountController.text.trim());
    final usageLimit = _usageLimitController.text.trim().isEmpty
        ? null
        : int.tryParse(_usageLimitController.text.trim());
    final usageLimitPerBuyer = _usageLimitPerBuyerController.text.trim().isEmpty
        ? null
        : int.tryParse(_usageLimitPerBuyerController.text.trim());

    final error = _isEditing
        ? await notifier.updateVoucher(
            widget.existing!.id,
            code: code,
            type: _type,
            value: value,
            minPurchase: minPurchase,
            maxDiscount: maxDiscount,
            usageLimit: usageLimit,
            usageLimitPerBuyer: usageLimitPerBuyer,
            startsAt: _startsAt,
            expiresAt: _expiresAt,
            isActive: _isActive,
          )
        : await notifier.createVoucher(
            code: code,
            type: _type,
            value: value,
            minPurchase: minPurchase,
            maxDiscount: maxDiscount,
            usageLimit: usageLimit,
            usageLimitPerBuyer: usageLimitPerBuyer,
            startsAt: _startsAt,
            expiresAt: _expiresAt,
            isActive: _isActive,
          );

    if (!mounted) return;
    if (error == null) {
      Navigator.of(context).pop();
    } else {
      setState(() {
        _isSaving = false;
        _errorMessage = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary;

    return AppScaffold(
      title: _isEditing ? 'Edit Voucher' : 'Tambah Voucher',
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppTheme.spacingLG),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(AppTheme.spacingMD),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(AppTheme.radiusXLCard),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: Color(0xFFDC2626), fontSize: 13),
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingLG),
                ],

                TextFormField(
                  controller: _codeController,
                  textCapitalization: TextCapitalization.characters,
                  inputFormatters: [_UpperCaseTextFormatter()],
                  decoration: const InputDecoration(labelText: 'Kode Voucher'),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Kode voucher wajib diisi' : null,
                ),
                const SizedBox(height: AppTheme.spacingMD),

                Text('Tipe Diskon', style: AppTheme.labelMd.copyWith(color: muted)),
                const SizedBox(height: 6),
                RadioGroup<String>(
                  groupValue: _type,
                  onChanged: (v) => setState(() => _type = v ?? 'fixed'),
                  child: const Row(
                    children: [
                      Expanded(
                        child: RadioListTile<String>(
                          value: 'fixed',
                          title: Text('Potongan (Rp)', style: TextStyle(fontSize: 13)),
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                        ),
                      ),
                      Expanded(
                        child: RadioListTile<String>(
                          value: 'percentage',
                          title: Text('Persentase (%)', style: TextStyle(fontSize: 13)),
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppTheme.spacingSM),

                TextFormField(
                  controller: _valueController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: _type == 'percentage' ? 'Nilai Diskon (%)' : 'Nilai Diskon (Rp)',
                  ),
                  validator: (v) {
                    final n = double.tryParse((v ?? '').trim());
                    if (n == null || n <= 0) return 'Nilai diskon tidak valid';
                    if (_type == 'percentage' && n > 100) {
                      return 'Persentase maksimal 100';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppTheme.spacingMD),

                TextFormField(
                  controller: _minPurchaseController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Minimal Belanja (Rp) — opsional',
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return null;
                    final n = double.tryParse(v.trim());
                    if (n == null || n < 0) return 'Tidak valid';
                    return null;
                  },
                ),
                const SizedBox(height: AppTheme.spacingMD),

                if (_type == 'percentage') ...[
                  TextFormField(
                    controller: _maxDiscountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Maksimal Diskon (Rp) — opsional',
                      helperText: 'Batas atas potongan agar diskon persentase tidak berlebihan',
                      helperMaxLines: 2,
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return null;
                      final n = double.tryParse(v.trim());
                      if (n == null || n < 0) return 'Tidak valid';
                      return null;
                    },
                  ),
                  const SizedBox(height: AppTheme.spacingMD),
                ],

                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _usageLimitController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: const InputDecoration(
                          labelText: 'Batas Pemakaian — opsional',
                          helperText: 'Kosongkan untuk tanpa batas',
                          helperMaxLines: 2,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppTheme.spacingSM),
                    Expanded(
                      child: TextFormField(
                        controller: _usageLimitPerBuyerController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: const InputDecoration(
                          labelText: 'Batas per Pembeli',
                          hintText: '1',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppTheme.spacingMD),

                Row(
                  children: [
                    Expanded(
                      child: _DatePickerField(
                        label: 'Mulai Berlaku — opsional',
                        value: _startsAt,
                        onTap: () => _pickDate(isStart: true),
                        onClear: _startsAt == null
                            ? null
                            : () => setState(() => _startsAt = null),
                      ),
                    ),
                    const SizedBox(width: AppTheme.spacingSM),
                    Expanded(
                      child: _DatePickerField(
                        label: 'Berakhir — opsional',
                        value: _expiresAt,
                        onTap: () => _pickDate(isStart: false),
                        onClear: _expiresAt == null
                            ? null
                            : () => setState(() => _expiresAt = null),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppTheme.spacingLG),

                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spacingMD,
                  ),
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.darkCard : AppTheme.cardWhite,
                    borderRadius: BorderRadius.circular(AppTheme.radiusXLCard),
                    border: Border.all(
                      color: isDark ? AppTheme.darkBorder : AppTheme.border,
                    ),
                  ),
                  child: SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _isActive,
                    onChanged: (v) => setState(() => _isActive = v),
                    title: const Text(
                      'Aktifkan voucher',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      'Voucher nonaktif tidak bisa dipakai pembeli, tapi riwayatnya tetap tersimpan.',
                      style: AppTheme.bodySm.copyWith(color: muted),
                    ),
                  ),
                ),
                const SizedBox(height: AppTheme.spacingXL),

                SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _submit,
                    child: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(_isEditing ? 'Simpan Perubahan' : 'Tambah Voucher'),
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

class _DatePickerField extends StatelessWidget {
  final String label;
  final DateTime? value;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  const _DatePickerField({
    required this.label,
    required this.value,
    required this.onTap,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: onClear == null
              ? null
              : IconButton(
                  icon: const AppIcon(
                    AppIcons.close,
                    size: AppIconSize.sm,
                    semanticsLabel: 'Hapus tanggal',
                  ),
                  onPressed: onClear,
                ),
        ),
        child: Text(
          value == null ? '-' : DateFormatter.format(value!.toIso8601String()),
        ),
      ),
    );
  }
}
