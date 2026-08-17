import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:blukios_marketplace/config/app_theme.dart';
import 'package:blukios_marketplace/config/routes.dart';
import 'package:blukios_marketplace/features/seller/store/models/seller_store_model.dart';
import 'package:blukios_marketplace/features/seller/store/viewmodels/seller_store_viewmodel.dart';
import 'package:blukios_marketplace/features/seller/store/widgets/destination_search_field.dart';
import 'package:blukios_marketplace/features/shipment/models/shipment_destination_model.dart';
import 'package:blukios_marketplace/shared/widgets/app_icon.dart';
import 'package:blukios_marketplace/shared/widgets/app_scaffold.dart';

/// View/edit screen for the authenticated seller's own store
/// (`GET /my-store`, `PUT /store/{id}`).
class SellerStoreProfileScreen extends ConsumerStatefulWidget {
  const SellerStoreProfileScreen({super.key});

  @override
  ConsumerState<SellerStoreProfileScreen> createState() =>
      _SellerStoreProfileScreenState();
}

class _SellerStoreProfileScreenState extends ConsumerState<SellerStoreProfileScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(sellerStoreProvider.notifier).loadMyStore();
    });
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = ref.watch(sellerStoreProvider);

    return AppScaffold(
      title: 'Toko Saya',
      body: SafeArea(
        child: viewModel.isLoading
            ? const Center(child: CircularProgressIndicator())
            : viewModel.hasStore
                ? _StoreEditForm(store: viewModel.store!)
                : const _NoStoreView(),
      ),
    );
  }
}

class _NoStoreView extends StatelessWidget {
  const _NoStoreView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AppIcon(AppIcons.store, size: AppIconSize.xl),
            const SizedBox(height: 16),
            Text(
              'Anda belum memiliki toko',
              style: AppTheme.titleLg,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Daftarkan toko Anda untuk mulai berjualan di Blukios.',
              style: AppTheme.bodySm.copyWith(color: AppTheme.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () => context.push(AppRoutes.sellerOnboarding),
                child: const Text('Daftarkan Toko'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StoreEditForm extends ConsumerStatefulWidget {
  final SellerStoreModel store;

  const _StoreEditForm({required this.store});

  @override
  ConsumerState<_StoreEditForm> createState() => _StoreEditFormState();
}

class _StoreEditFormState extends ConsumerState<_StoreEditForm> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController = TextEditingController(text: widget.store.name);
  late final _aboutController = TextEditingController(text: widget.store.about);
  late final _phoneController = TextEditingController(text: widget.store.phone);
  late final _addressController = TextEditingController(text: widget.store.address);
  late final _destinationSearchController = TextEditingController(text: widget.store.city);

  late String? _addressId = widget.store.addressId;
  late String? _city = widget.store.city;
  late String? _postalCode = widget.store.postalCode;
  late final double? _latitude = widget.store.latitude;
  late final double? _longitude = widget.store.longitude;
  late bool _aiAssistantEnabled = widget.store.aiAssistantEnabled;

  XFile? _pickedLogo;
  String? _errorMessage;

  static final _phoneRegex = RegExp(r'^08[0-9]{8,13}$');

  @override
  void dispose() {
    _nameController.dispose();
    _aboutController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _destinationSearchController.dispose();
    super.dispose();
  }

  void _selectDestination(ShipmentDestinationModel destination) {
    setState(() {
      _addressId = destination.id;
      _city = destination.cityName;
      _postalCode = destination.zipCode;
    });
  }

  Future<void> _pickLogo() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (picked != null) {
      setState(() => _pickedLogo = picked);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_addressId == null || _addressId!.isEmpty || _city == null || _postalCode == null) {
      setState(() => _errorMessage = 'Pilih kecamatan/kota tujuan dari daftar pencarian');
      return;
    }

    setState(() => _errorMessage = null);

    final error = await ref.read(sellerStoreProvider.notifier).updateStore(
          name: _nameController.text.trim(),
          about: _aboutController.text.trim(),
          phone: _phoneController.text.trim(),
          addressId: _addressId!,
          city: _city!,
          address: _addressController.text.trim(),
          postalCode: _postalCode!,
          latitude: _latitude,
          longitude: _longitude,
          aiAssistantEnabled: _aiAssistantEnabled,
          logoPath: _pickedLogo?.path,
        );

    if (!mounted) return;
    if (error == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informasi toko berhasil diperbarui')),
      );
    } else {
      setState(() => _errorMessage = error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = ref.watch(sellerStoreProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _errorMessage!,
                  style: AppTheme.bodySm.copyWith(color: const Color(0xFFDC2626)),
                ),
              ),
              const SizedBox(height: 16),
            ],

            Center(
              child: GestureDetector(
                onTap: _pickLogo,
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 44,
                      backgroundColor: AppTheme.iconBackground,
                      backgroundImage: _pickedLogo != null
                          ? FileImage(File(_pickedLogo!.path))
                          : (widget.store.logo != null
                              ? NetworkImage(widget.store.logo!) as ImageProvider
                              : null),
                      child: _pickedLogo == null && widget.store.logo == null
                          ? const AppIcon(AppIcons.store, size: AppIconSize.lg)
                          : null,
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: AppTheme.primary,
                          shape: BoxShape.circle,
                        ),
                        child: const AppIcon(
                          AppIcons.image,
                          size: AppIconSize.sm,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Nama Toko'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Nama toko wajib diisi' : null,
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: _aboutController,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'Tentang Toko'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Deskripsi toko wajib diisi' : null,
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Nomor Telepon Toko',
                hintText: '08xxxxxxxxxx',
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Nomor telepon wajib diisi';
                if (!_phoneRegex.hasMatch(v.trim())) {
                  return 'Format nomor telepon tidak valid (contoh: 08123456789)';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),

            Text('Lokasi Toko', style: AppTheme.titleSm),
            const SizedBox(height: 8),

            DestinationSearchField(
              controller: _destinationSearchController,
              onSelected: _selectDestination,
            ),
            if (_city != null) ...[
              const SizedBox(height: 8),
              Text(
                'Terpilih: $_city, $_postalCode',
                style: AppTheme.labelMd.copyWith(color: AppTheme.success),
              ),
            ],
            const SizedBox(height: 12),

            TextFormField(
              controller: _addressController,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Alamat Lengkap'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Alamat wajib diisi' : null,
            ),
            const SizedBox(height: 12),

            SwitchListTile(
              value: _aiAssistantEnabled,
              onChanged: (v) => setState(() => _aiAssistantEnabled = v),
              title: Text('Aktifkan Asisten AI', style: AppTheme.titleSm),
              subtitle: Text(
                'Bantu jawab pertanyaan pembeli secara otomatis',
                style: AppTheme.bodySm.copyWith(color: AppTheme.textSecondary),
              ),
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 24),

            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: viewModel.isSaving ? null : _submit,
                child: viewModel.isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Simpan Perubahan'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
