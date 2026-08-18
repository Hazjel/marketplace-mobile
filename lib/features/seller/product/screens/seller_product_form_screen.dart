import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:blukios_marketplace/config/app_theme.dart';
import 'package:blukios_marketplace/features/seller/product/models/seller_product_form_models.dart';
import 'package:blukios_marketplace/features/seller/product/models/seller_product_model.dart';
import 'package:blukios_marketplace/features/seller/product/viewmodels/seller_product_form_viewmodel.dart';
import 'package:blukios_marketplace/shared/widgets/app_icon.dart';
import 'package:blukios_marketplace/shared/widgets/app_scaffold.dart';

/// Create + edit product, in one screen — [existing] null means create.
///
/// Note on images: the API (`ProductUpdateRequest`) only accepts *new*
/// images on update — there is no field to delete or re-flag an existing
/// image's thumbnail, so in edit mode existing images are shown read-only
/// and newly added ones are appended alongside them.
///
/// Note on variants: when `hasVariants` is on, the API recomputes the
/// top-level price (minimum variant price) and stock (sum of variant
/// stocks) from the variant list — see `ProductRepository::create`/`update`
/// on the Laravel side. The top-level Harga/Stok fields below stay
/// required (the API still validates them unconditionally) but effectively
/// become informational once variants exist.
class SellerProductFormScreen extends ConsumerStatefulWidget {
  final SellerProductModel? existing;

  const SellerProductFormScreen({super.key, this.existing});

  @override
  ConsumerState<SellerProductFormScreen> createState() =>
      _SellerProductFormScreenState();
}

class _SellerProductFormScreenState
    extends ConsumerState<SellerProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController = TextEditingController(text: widget.existing?.name);
  late final _descriptionController =
      TextEditingController(text: widget.existing?.description);
  late final _priceController = TextEditingController(
    text: widget.existing != null
        ? _trimDecimal(widget.existing!.price)
        : null,
  );
  late final _weightController = TextEditingController(
    text: widget.existing != null
        ? _trimDecimal(widget.existing!.weight)
        : null,
  );
  late final _stockController =
      TextEditingController(text: widget.existing?.stock.toString());

  late String _condition = widget.existing?.condition ?? 'new';
  String? _categoryId;
  final List<SellerProductNewImage> _newImages = [];
  String? _errorMessage;

  /// Stable identities for the variant rows in the provider's list, so each
  /// `_VariantRowEditor`'s own `TextEditingController`s survive provider
  /// rebuilds (a new list instance on every keystroke) instead of getting
  /// recreated and losing focus/cursor position.
  final List<int> _variantRowKeys = [];
  int _variantKeyCounter = 0;
  int _nextVariantKey() => _variantKeyCounter++;

  bool get _isEditing => widget.existing != null;
  bool get _hasExistingImages =>
      _isEditing && widget.existing!.images.isNotEmpty;

  static String _trimDecimal(double value) {
    return value == value.roundToDouble()
        ? value.toStringAsFixed(0)
        : value.toString();
  }

  @override
  void initState() {
    super.initState();
    _categoryId = widget.existing?.categoryId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final notifier = ref.read(sellerProductFormProvider.notifier);
      notifier.init();
      notifier.loadExistingVariants(widget.existing);
      final seededCount = ref.read(sellerProductFormProvider).variants.length;
      if (seededCount > 0) {
        setState(() {
          _variantRowKeys.addAll(
            List.generate(seededCount, (_) => _nextVariantKey()),
          );
        });
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _weightController.dispose();
    _stockController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final picker = ImagePicker();
    List<XFile> picked;
    try {
      picked = await picker.pickMultiImage(imageQuality: 85);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal membuka galeri')),
      );
      return;
    }
    if (picked.isEmpty) return;

    setState(() {
      final alreadyHasThumbnail =
          _hasExistingImages || _newImages.any((i) => i.isThumbnail);
      for (var i = 0; i < picked.length; i++) {
        _newImages.add(
          SellerProductNewImage(
            localPath: picked[i].path,
            isThumbnail: !alreadyHasThumbnail && i == 0,
          ),
        );
      }
    });
  }

  void _setThumbnail(int index) {
    setState(() {
      for (var i = 0; i < _newImages.length; i++) {
        _newImages[i] = _newImages[i].copyWith(isThumbnail: i == index);
      }
    });
  }

  void _removeNewImage(int index) {
    setState(() {
      final wasThumbnail = _newImages[index].isThumbnail;
      _newImages.removeAt(index);
      if (wasThumbnail && !_hasExistingImages && _newImages.isNotEmpty) {
        _newImages[0] = _newImages[0].copyWith(isThumbnail: true);
      }
    });
  }

  void _setHasVariants(bool value) {
    ref.read(sellerProductFormProvider.notifier).setHasVariants(value);
    if (!value) {
      setState(() => _variantRowKeys.clear());
    }
  }

  void _addVariant() {
    ref.read(sellerProductFormProvider.notifier).addVariant();
    setState(() => _variantRowKeys.add(_nextVariantKey()));
  }

  void _removeVariant(int index) {
    ref.read(sellerProductFormProvider.notifier).removeVariant(index);
    setState(() => _variantRowKeys.removeAt(index));
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_categoryId == null) {
      setState(() => _errorMessage = 'Pilih kategori produk');
      return;
    }
    if (!_hasExistingImages && _newImages.isEmpty) {
      setState(() => _errorMessage = 'Tambahkan minimal satu gambar produk');
      return;
    }

    final formState = ref.read(sellerProductFormProvider);
    if (formState.hasVariants && formState.variants.isEmpty) {
      setState(() => _errorMessage = 'Tambahkan minimal satu varian');
      return;
    }

    setState(() => _errorMessage = null);

    final storeId = formState.store?.id;
    if (storeId == null) {
      setState(() => _errorMessage = 'Data toko belum siap, coba lagi');
      return;
    }

    final payload = SellerProductPayload(
      storeId: storeId,
      categoryId: _categoryId!,
      name: _nameController.text.trim(),
      description: _descriptionController.text.trim(),
      condition: _condition,
      price: double.tryParse(_priceController.text.trim()) ?? 0,
      weight: double.tryParse(_weightController.text.trim()) ?? 0,
      stock: int.tryParse(_stockController.text.trim()) ?? 0,
      newImages: _newImages,
      hasVariants: formState.hasVariants,
      variants: formState.variants,
    );

    final notifier = ref.read(sellerProductFormProvider.notifier);
    final result = _isEditing
        ? await notifier.submitUpdate(widget.existing!.id, payload)
        : await notifier.submitCreate(payload);

    if (!mounted) return;
    if (result != null) {
      Navigator.of(context).pop();
    } else {
      final refreshed = ref.read(sellerProductFormProvider);
      setState(
        () => _errorMessage = refreshed.errorMessage ?? 'Gagal menyimpan produk',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final formState = ref.watch(sellerProductFormProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary;

    return AppScaffold(
      title: _isEditing ? 'Edit Produk' : 'Tambah Produk',
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
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Nama Produk'),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Nama produk wajib diisi' : null,
                ),
                const SizedBox(height: AppTheme.spacingMD),

                TextFormField(
                  controller: _descriptionController,
                  maxLines: 4,
                  decoration: const InputDecoration(labelText: 'Deskripsi'),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Deskripsi wajib diisi' : null,
                ),
                const SizedBox(height: AppTheme.spacingMD),

                Text('Kategori', style: AppTheme.labelMd.copyWith(color: muted)),
                const SizedBox(height: 6),
                formState.isLoadingCategories
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: LinearProgressIndicator(),
                      )
                    : DropdownButtonFormField<String>(
                        initialValue: formState.categories
                                .any((c) => c.id == _categoryId)
                            ? _categoryId
                            : null,
                        decoration: const InputDecoration(hintText: 'Pilih kategori'),
                        items: formState.categories
                            .map(
                              (c) => DropdownMenuItem(value: c.id, child: Text(c.name)),
                            )
                            .toList(),
                        onChanged: (v) => setState(() => _categoryId = v),
                      ),
                const SizedBox(height: AppTheme.spacingMD),

                Text('Kondisi', style: AppTheme.labelMd.copyWith(color: muted)),
                const SizedBox(height: 6),
                RadioGroup<String>(
                  groupValue: _condition,
                  onChanged: (v) => setState(() => _condition = v ?? 'new'),
                  child: const Row(
                    children: [
                      Expanded(
                        child: RadioListTile<String>(
                          value: 'new',
                          title: Text('Baru', style: TextStyle(fontSize: 13)),
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                        ),
                      ),
                      Expanded(
                        child: RadioListTile<String>(
                          value: 'second',
                          title: Text('Bekas', style: TextStyle(fontSize: 13)),
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppTheme.spacingSM),

                TextFormField(
                  controller: _priceController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Harga (Rp)',
                    helperText: formState.hasVariants
                        ? 'Akan diganti otomatis dengan harga terendah dari varian'
                        : null,
                    helperMaxLines: 2,
                  ),
                  validator: (v) {
                    final n = double.tryParse((v ?? '').trim());
                    if (n == null || n < 0) return 'Harga tidak valid';
                    return null;
                  },
                ),
                const SizedBox(height: AppTheme.spacingMD),

                TextFormField(
                  controller: _weightController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Berat (gram)'),
                  validator: (v) {
                    final n = double.tryParse((v ?? '').trim());
                    if (n == null || n < 0) return 'Berat tidak valid';
                    return null;
                  },
                ),
                const SizedBox(height: AppTheme.spacingMD),

                TextFormField(
                  controller: _stockController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Stok',
                    helperText: formState.hasVariants
                        ? 'Akan diganti otomatis dengan total stok varian'
                        : null,
                    helperMaxLines: 2,
                  ),
                  validator: (v) {
                    final n = int.tryParse((v ?? '').trim());
                    if (n == null || n < 0) return 'Stok tidak valid';
                    return null;
                  },
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
                    value: formState.hasVariants,
                    onChanged: _setHasVariants,
                    title: const Text(
                      'Produk ini punya varian?',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      'Aktifkan jika produk dijual dalam beberapa pilihan, mis. warna atau ukuran.',
                      style: AppTheme.bodySm.copyWith(color: muted),
                    ),
                  ),
                ),

                if (formState.hasVariants) ...[
                  const SizedBox(height: AppTheme.spacingMD),
                  for (var i = 0; i < formState.variants.length; i++)
                    _VariantRowEditor(
                      key: ValueKey(_variantRowKeys[i]),
                      index: i,
                      variant: formState.variants[i],
                      isDark: isDark,
                      onChanged: (updated) => ref
                          .read(sellerProductFormProvider.notifier)
                          .updateVariant(i, updated),
                      onRemove: () => _removeVariant(i),
                    ),
                  OutlinedButton.icon(
                    onPressed: _addVariant,
                    icon: const AppIcon(AppIcons.plus, size: AppIconSize.md),
                    label: const Text('Tambah Varian'),
                  ),
                ],
                const SizedBox(height: AppTheme.spacingLG),

                Text('Gambar Produk', style: AppTheme.labelMd.copyWith(color: muted)),
                const SizedBox(height: 6),
                if (_hasExistingImages) ...[
                  Text(
                    'Gambar tersimpan tidak bisa dihapus atau diganti utamanya dari sini — hanya bisa ditambah.',
                    style: AppTheme.bodySm.copyWith(color: muted),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 84,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: widget.existing!.images.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final image = widget.existing!.images[index];
                        return _ImageTile(
                          isDark: isDark,
                          isThumbnail: image.isThumbnail,
                          child: CachedNetworkImage(
                            imageUrl: image.url,
                            fit: BoxFit.cover,
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                if (_newImages.isNotEmpty)
                  SizedBox(
                    height: 84,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _newImages.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final image = _newImages[index];
                        return GestureDetector(
                          onTap: () => _setThumbnail(index),
                          child: Stack(
                            children: [
                              _ImageTile(
                                isDark: isDark,
                                isThumbnail: image.isThumbnail,
                                child: Image.file(
                                  File(image.localPath),
                                  fit: BoxFit.cover,
                                ),
                              ),
                              Positioned(
                                top: -6,
                                right: -6,
                                child: IconButton(
                                  onPressed: () => _removeNewImage(index),
                                  icon: const AppIcon(
                                    AppIcons.close,
                                    size: AppIconSize.sm,
                                    color: AppTheme.error,
                                    semanticsLabel: 'Hapus gambar',
                                  ),
                                  style: IconButton.styleFrom(
                                    backgroundColor:
                                        isDark ? AppTheme.darkCard : AppTheme.cardWhite,
                                    minimumSize: const Size(28, 28),
                                    padding: EdgeInsets.zero,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _pickImages,
                  icon: const AppIcon(AppIcons.image, size: AppIconSize.md),
                  label: Text(_newImages.isEmpty ? 'Tambah Gambar' : 'Tambah Gambar Lagi'),
                ),
                if (_newImages.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      'Ketuk gambar untuk menjadikannya gambar utama',
                      style: AppTheme.bodySm.copyWith(color: muted),
                    ),
                  ),
                const SizedBox(height: AppTheme.spacingXL),

                SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: formState.isSaving ? null : _submit,
                    child: formState.isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(_isEditing ? 'Simpan Perubahan' : 'Tambah Produk'),
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

class _ImageTile extends StatelessWidget {
  final bool isDark;
  final bool isThumbnail;
  final Widget child;

  const _ImageTile({
    required this.isDark,
    required this.isThumbnail,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 84,
      height: 84,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.radiusXLCard),
        border: Border.all(
          color: isThumbnail
              ? (isDark ? AppTheme.darkPrimary : AppTheme.primary)
              : (isDark ? AppTheme.darkBorder : AppTheme.border),
          width: isThumbnail ? 2 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          child,
          if (isThumbnail)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                color: (isDark ? AppTheme.darkPrimary : AppTheme.primary)
                    .withValues(alpha: 0.85),
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: const Text(
                  'Utama',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// One editable key/value pair inside a variant's attribute list, e.g.
/// {"Warna": "Merah"}. Owns its own controllers so [_VariantRowEditor] can
/// keep a stable list across rebuilds.
class _AttributeRow {
  final TextEditingController key;
  final TextEditingController value;

  _AttributeRow({String key = '', String value = ''})
      : key = TextEditingController(text: key),
        value = TextEditingController(text: value);

  void dispose() {
    key.dispose();
    value.dispose();
  }
}

/// A single variant's editable fields (name/price/stock/sku + a repeatable
/// attribute key-value editor). Owns its own [TextEditingController]s,
/// seeded once from [variant] and never overwritten by later rebuilds —
/// only [onChanged] pushes edits back out, to [SellerProductFormNotifier]
/// via the parent screen. Give this a stable [Key] per row (not an index
/// key) so reordering/removal doesn't scramble which controllers belong to
/// which row.
class _VariantRowEditor extends StatefulWidget {
  final int index;
  final SellerProductVariantModel variant;
  final bool isDark;
  final ValueChanged<SellerProductVariantModel> onChanged;
  final VoidCallback onRemove;

  const _VariantRowEditor({
    super.key,
    required this.index,
    required this.variant,
    required this.isDark,
    required this.onChanged,
    required this.onRemove,
  });

  @override
  State<_VariantRowEditor> createState() => _VariantRowEditorState();
}

class _VariantRowEditorState extends State<_VariantRowEditor> {
  late final _nameController = TextEditingController(text: widget.variant.name);
  late final _priceController = TextEditingController(
    text: widget.variant.price == 0
        ? ''
        : _SellerProductFormScreenState._trimDecimal(widget.variant.price),
  );
  late final _stockController = TextEditingController(
    text: widget.variant.stock == 0 ? '' : widget.variant.stock.toString(),
  );
  late final _skuController = TextEditingController(text: widget.variant.sku);
  late final List<_AttributeRow> _attributes = widget.variant.variantAttributes
      .entries
      .map((e) => _AttributeRow(key: e.key, value: e.value))
      .toList();

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _stockController.dispose();
    _skuController.dispose();
    for (final attr in _attributes) {
      attr.dispose();
    }
    super.dispose();
  }

  void _emitChange() {
    final attrs = <String, String>{};
    for (final attr in _attributes) {
      final key = attr.key.text.trim();
      if (key.isNotEmpty) attrs[key] = attr.value.text.trim();
    }
    widget.onChanged(
      widget.variant.copyWith(
        name: _nameController.text.trim(),
        price: double.tryParse(_priceController.text.trim()) ?? 0,
        stock: int.tryParse(_stockController.text.trim()) ?? 0,
        sku: _skuController.text.trim().isEmpty ? null : _skuController.text.trim(),
        variantAttributes: attrs,
      ),
    );
  }

  void _addAttribute() {
    setState(() => _attributes.add(_AttributeRow()));
  }

  void _removeAttribute(int index) {
    setState(() {
      _attributes[index].dispose();
      _attributes.removeAt(index);
    });
    _emitChange();
  }

  @override
  Widget build(BuildContext context) {
    final muted =
        widget.isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary;

    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spacingMD),
      padding: const EdgeInsets.all(AppTheme.spacingMD),
      decoration: BoxDecoration(
        color: widget.isDark ? AppTheme.darkCard : AppTheme.cardWhite,
        borderRadius: BorderRadius.circular(AppTheme.radiusXLCard),
        border: Border.all(
          color: widget.isDark ? AppTheme.darkBorder : AppTheme.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Varian ${widget.index + 1}',
                  style: AppTheme.labelMd.copyWith(color: muted),
                ),
              ),
              IconButton(
                onPressed: widget.onRemove,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: const AppIcon(
                  AppIcons.trash,
                  size: AppIconSize.sm,
                  color: AppTheme.error,
                  semanticsLabel: 'Hapus varian',
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingSM),
          TextFormField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: 'Nama Varian'),
            onChanged: (_) => _emitChange(),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Nama varian wajib diisi' : null,
          ),
          const SizedBox(height: AppTheme.spacingSM),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextFormField(
                  controller: _priceController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Harga (Rp)'),
                  onChanged: (_) => _emitChange(),
                  validator: (v) {
                    final n = double.tryParse((v ?? '').trim());
                    if (n == null || n < 0) return 'Tidak valid';
                    return null;
                  },
                ),
              ),
              const SizedBox(width: AppTheme.spacingSM),
              Expanded(
                child: TextFormField(
                  controller: _stockController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Stok'),
                  onChanged: (_) => _emitChange(),
                  validator: (v) {
                    final n = int.tryParse((v ?? '').trim());
                    if (n == null || n < 0) return 'Tidak valid';
                    return null;
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingSM),
          TextFormField(
            controller: _skuController,
            decoration: const InputDecoration(labelText: 'SKU (opsional)'),
            onChanged: (_) => _emitChange(),
          ),
          const SizedBox(height: AppTheme.spacingSM),
          Text('Atribut Varian', style: AppTheme.bodySm.copyWith(color: muted)),
          const SizedBox(height: 6),
          for (var i = 0; i < _attributes.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _attributes[i].key,
                      decoration: const InputDecoration(
                        hintText: 'Nama (mis. Warna)',
                        isDense: true,
                      ),
                      onChanged: (_) => _emitChange(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _attributes[i].value,
                      decoration: const InputDecoration(
                        hintText: 'Nilai (mis. Merah)',
                        isDense: true,
                      ),
                      onChanged: (_) => _emitChange(),
                    ),
                  ),
                  IconButton(
                    onPressed: () => _removeAttribute(i),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: const AppIcon(
                      AppIcons.close,
                      size: AppIconSize.sm,
                      color: AppTheme.error,
                      semanticsLabel: 'Hapus atribut',
                    ),
                  ),
                ],
              ),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _addAttribute,
              icon: const AppIcon(AppIcons.plus, size: AppIconSize.sm),
              label: const Text('Tambah Atribut'),
            ),
          ),
        ],
      ),
    );
  }
}
