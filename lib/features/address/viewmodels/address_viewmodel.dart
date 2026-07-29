import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:blukios_marketplace/core/providers.dart';
import 'package:blukios_marketplace/features/address/models/address_model.dart';

class AddressData {
  final List<AddressModel> addresses;
  final bool isLoading;
  final bool isSaving;
  final String? error;

  const AddressData({
    this.addresses = const [],
    this.isLoading = true,
    this.isSaving = false,
    this.error,
  });

  AddressModel? get primaryAddress {
    if (addresses.isEmpty) return null;
    for (final a in addresses) {
      if (a.isPrimary) return a;
    }
    return addresses.first;
  }

  AddressData copyWith({
    List<AddressModel>? addresses,
    bool? isLoading,
    bool? isSaving,
    String? error,
    bool clearError = false,
  }) {
    return AddressData(
      addresses: addresses ?? this.addresses,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class AddressNotifier extends Notifier<AddressData> {
  @override
  AddressData build() => const AddressData();

  Future<void> loadAddresses() async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final addresses = await ref.read(addressRepositoryProvider).getAddresses();
      state = state.copyWith(addresses: addresses, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Returns null on success, or an error message on failure.
  Future<String?> createAddress(AddressModel address) async {
    state = state.copyWith(isSaving: true);

    try {
      final repository = ref.read(addressRepositoryProvider);
      await repository.createAddress(address);
      // Refetch so is_primary demotion (handled server-side) stays authoritative.
      final addresses = await repository.getAddresses();
      state = state.copyWith(addresses: addresses, isSaving: false);
      return null;
    } catch (e) {
      state = state.copyWith(isSaving: false);
      return e.toString();
    }
  }

  /// Returns null on success, or an error message on failure.
  Future<String?> updateAddress(String id, AddressModel address) async {
    state = state.copyWith(isSaving: true);

    try {
      final repository = ref.read(addressRepositoryProvider);
      await repository.updateAddress(id, address);
      // Refetch so is_primary demotion (handled server-side) stays authoritative.
      final addresses = await repository.getAddresses();
      state = state.copyWith(addresses: addresses, isSaving: false);
      return null;
    } catch (e) {
      state = state.copyWith(isSaving: false);
      return e.toString();
    }
  }

  /// Returns null on success, or an error message on failure.
  Future<String?> deleteAddress(String id) async {
    try {
      await ref.read(addressRepositoryProvider).deleteAddress(id);
      state = state.copyWith(
        addresses: state.addresses.where((a) => a.id != id).toList(),
      );
      return null;
    } catch (e) {
      return e.toString();
    }
  }
}

final addressProvider =
    NotifierProvider<AddressNotifier, AddressData>(AddressNotifier.new);
