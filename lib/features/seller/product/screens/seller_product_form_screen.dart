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
      ref.read(sellerProductFormProvider.notifier).init();
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

    setState(() => _errorMessage = null);

    final formState = ref.read(sellerProductFormProvider);
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
                Row(
                  children: [
                    Expanded(
                      child: RadioListTile<String>(
                        value: 'new',
                        groupValue: _condition,
                        onChanged: (v) => setState(() => _condition = v ?? 'new'),
                        title: const Text('Baru', style: TextStyle(fontSize: 13)),
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                      ),
                    ),
                    Expanded(
                      child: RadioListTile<String>(
                        value: 'second',
                        groupValue: _condition,
                        onChanged: (v) => setState(() => _condition = v ?? 'new'),
                        title: const Text('Bekas', style: TextStyle(fontSize: 13)),
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppTheme.spacingSM),

                TextFormField(
                  controller: _priceController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Harga (Rp)'),
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
                  decoration: const InputDecoration(labelText: 'Stok'),
                  validator: (v) {
                    final n = int.tryParse((v ?? '').trim());
                    if (n == null || n < 0) return 'Stok tidak valid';
                    return null;
                  },
                ),
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
