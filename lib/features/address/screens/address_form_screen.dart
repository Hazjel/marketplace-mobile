import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:blukios_marketplace/core/providers.dart';
import 'package:blukios_marketplace/features/address/models/address_model.dart';
import 'package:blukios_marketplace/features/address/viewmodels/address_viewmodel.dart';
import 'package:blukios_marketplace/features/shipment/models/shipment_destination_model.dart';

class AddressFormScreen extends ConsumerStatefulWidget {
  final AddressModel? existing;

  const AddressFormScreen({super.key, this.existing});

  @override
  ConsumerState<AddressFormScreen> createState() => _AddressFormScreenState();
}

class _AddressFormScreenState extends ConsumerState<AddressFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _labelController = TextEditingController(text: widget.existing?.label);
  late final _recipientController = TextEditingController(text: widget.existing?.recipientName);
  late final _phoneController = TextEditingController(text: widget.existing?.phone);
  late final _addressController = TextEditingController(text: widget.existing?.address);
  late final _destinationSearchController = TextEditingController(text: widget.existing?.city);

  String? _city;
  String? _cityId;
  String? _postalCode;
  double? _latitude;
  double? _longitude;
  bool _isPrimary = false;

  List<ShipmentDestinationModel> _destinationOptions = [];
  bool _showDestinationOptions = false;
  bool _searchingDestination = false;
  Timer? _debounce;
  String? _errorMessage;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing != null) {
      _city = existing.city;
      _cityId = existing.cityId;
      _postalCode = existing.postalCode;
      _latitude = existing.latitude;
      _longitude = existing.longitude;
      _isPrimary = existing.isPrimary;
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _labelController.dispose();
    _recipientController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _destinationSearchController.dispose();
    super.dispose();
  }

  void _onDestinationSearchChanged(String value) {
    _debounce?.cancel();
    if (value.trim().length < 2) {
      setState(() {
        _destinationOptions = [];
        _showDestinationOptions = false;
      });
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 500), () async {
      setState(() => _searchingDestination = true);
      try {
        final results =
            await ref.read(shipmentRepositoryProvider).searchDestination(value.trim());
        if (!mounted) return;
        setState(() {
          _destinationOptions = results;
          _showDestinationOptions = true;
        });
      } catch (_) {
        if (!mounted) return;
        setState(() => _destinationOptions = []);
      } finally {
        if (mounted) setState(() => _searchingDestination = false);
      }
    });
  }

  void _selectDestination(ShipmentDestinationModel destination) {
    setState(() {
      _cityId = destination.id;
      _city = destination.cityName;
      _postalCode = destination.zipCode;
      _destinationSearchController.text = destination.label;
      _showDestinationOptions = false;
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_cityId == null || _city == null || _postalCode == null) {
      setState(() => _errorMessage = 'Pilih kecamatan/kota tujuan dari daftar pencarian');
      return;
    }

    setState(() => _errorMessage = null);

    final address = AddressModel(
      id: widget.existing?.id ?? '',
      label: _labelController.text.trim(),
      recipientName: _recipientController.text.trim(),
      phone: _phoneController.text.trim(),
      address: _addressController.text.trim(),
      city: _city!,
      cityId: _cityId!,
      postalCode: _postalCode!,
      latitude: _latitude,
      longitude: _longitude,
      isPrimary: _isPrimary,
    );

    final notifier = ref.read(addressProvider.notifier);
    final error = _isEditing
        ? await notifier.updateAddress(widget.existing!.id, address)
        : await notifier.createAddress(address);

    if (!mounted) return;
    if (error == null) {
      Navigator.of(context).pop();
    } else {
      setState(() => _errorMessage = error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = ref.watch(addressProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Alamat' : 'Tambah Alamat'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
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
                      style: const TextStyle(color: Color(0xFFDC2626), fontSize: 13),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                TextFormField(
                  controller: _labelController,
                  decoration: const InputDecoration(labelText: 'Label (Rumah, Kantor, dll)'),
                  validator: (v) => (v == null || v.isEmpty) ? 'Label wajib diisi' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _recipientController,
                  decoration: const InputDecoration(labelText: 'Nama Penerima'),
                  validator: (v) => (v == null || v.isEmpty) ? 'Nama penerima wajib diisi' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Nomor Telepon'),
                  validator: (v) => (v == null || v.isEmpty) ? 'Nomor telepon wajib diisi' : null,
                ),
                const SizedBox(height: 12),

                // Destination search
                TextField(
                  controller: _destinationSearchController,
                  decoration: InputDecoration(
                    labelText: 'Cari Kecamatan / Kota',
                    suffixIcon: _searchingDestination
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : const Icon(Icons.search),
                  ),
                  onChanged: _onDestinationSearchChanged,
                ),
                if (_showDestinationOptions && _destinationOptions.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    constraints: const BoxConstraints(maxHeight: 200),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _destinationOptions.length,
                      itemBuilder: (context, index) {
                        final option = _destinationOptions[index];
                        return ListTile(
                          dense: true,
                          title: Text(option.label, style: const TextStyle(fontSize: 13)),
                          onTap: () => _selectDestination(option),
                        );
                      },
                    ),
                  ),
                if (_city != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Terpilih: $_city, $_postalCode',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF16A34A), fontWeight: FontWeight.w600),
                  ),
                ],
                const SizedBox(height: 12),

                TextFormField(
                  controller: _addressController,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Alamat Lengkap'),
                  validator: (v) => (v == null || v.isEmpty) ? 'Alamat wajib diisi' : null,
                ),
                const SizedBox(height: 12),

                CheckboxListTile(
                  value: _isPrimary,
                  onChanged: (v) => setState(() => _isPrimary = v ?? false),
                  title: const Text('Jadikan alamat utama', style: TextStyle(fontSize: 13)),
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
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
                        : Text(_isEditing ? 'Simpan Perubahan' : 'Tambah Alamat'),
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
