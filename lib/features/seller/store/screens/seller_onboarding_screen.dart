import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:blukios_marketplace/config/app_theme.dart';
import 'package:blukios_marketplace/config/routes.dart';
import 'package:blukios_marketplace/features/seller/store/viewmodels/seller_store_viewmodel.dart';
import 'package:blukios_marketplace/features/seller/store/widgets/destination_search_field.dart';
import 'package:blukios_marketplace/features/shipment/models/shipment_destination_model.dart';
import 'package:blukios_marketplace/shared/widgets/app_scaffold.dart';

/// Store registration form for users who are not sellers yet.
///
/// `POST /register-store` only requires `name` and `phone` — location
/// fields are optional here and can be filled in later from the store
/// profile screen. On success the user's role flips to `store`
/// server-side, so the notifier refreshes the session automatically.
class SellerOnboardingScreen extends ConsumerStatefulWidget {
  const SellerOnboardingScreen({super.key});

  @override
  ConsumerState<SellerOnboardingScreen> createState() => _SellerOnboardingScreenState();
}

class _SellerOnboardingScreenState extends ConsumerState<SellerOnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _destinationSearchController = TextEditingController();

  String? _city;
  String? _postalCode;
  String? _errorMessage;

  static final _phoneRegex = RegExp(r'^08[0-9]{8,13}$');

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _destinationSearchController.dispose();
    super.dispose();
  }

  void _selectDestination(ShipmentDestinationModel destination) {
    setState(() {
      _city = destination.cityName;
      _postalCode = destination.zipCode;
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _errorMessage = null);

    final error = await ref.read(sellerStoreProvider.notifier).registerStore(
          name: _nameController.text.trim(),
          phone: _phoneController.text.trim(),
          city: _city,
          address: _addressController.text.trim().isEmpty
              ? null
              : _addressController.text.trim(),
          postalCode: _postalCode,
        );

    if (!mounted) return;
    if (error == null) {
      context.pushReplacement(AppRoutes.sellerStoreProfile);
    } else {
      setState(() => _errorMessage = error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = ref.watch(sellerStoreProvider);

    return AppScaffold(
      title: 'Daftar Toko',
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Buka toko dan mulai berjualan di Blukios',
                  style: AppTheme.titleLg,
                ),
                const SizedBox(height: 4),
                Text(
                  'Lengkapi data berikut untuk mendaftarkan toko Anda. '
                  'Alamat toko bisa dilengkapi nanti.',
                  style: AppTheme.bodySm.copyWith(color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 20),

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

                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Nama Toko'),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Nama toko wajib diisi' : null,
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

                Text('Lokasi Toko (opsional)', style: AppTheme.titleSm),
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
                        : const Text('Daftarkan Toko'),
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
