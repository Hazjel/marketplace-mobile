import 'package:flutter/foundation.dart';
import 'package:blukios_marketplace/features/address/data/address_repository.dart';
import 'package:blukios_marketplace/features/address/models/address_model.dart';

class AddressViewModel extends ChangeNotifier {
  final AddressRepository _addressRepository;

  AddressViewModel(this._addressRepository);

  List<AddressModel> addresses = [];
  bool isLoading = true;
  bool isSaving = false;
  String? error;

  AddressModel? get primaryAddress {
    if (addresses.isEmpty) return null;
    for (final a in addresses) {
      if (a.isPrimary) return a;
    }
    return addresses.first;
  }

  Future<void> loadAddresses() async {
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      addresses = await _addressRepository.getAddresses();
    } catch (e) {
      error = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// Returns null on success, or an error message on failure.
  Future<String?> createAddress(AddressModel address) async {
    isSaving = true;
    notifyListeners();

    try {
      await _addressRepository.createAddress(address);
      // Refetch so is_primary demotion (handled server-side) stays authoritative.
      addresses = await _addressRepository.getAddresses();
      return null;
    } catch (e) {
      return e.toString();
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }

  /// Returns null on success, or an error message on failure.
  Future<String?> updateAddress(String id, AddressModel address) async {
    isSaving = true;
    notifyListeners();

    try {
      await _addressRepository.updateAddress(id, address);
      // Refetch so is_primary demotion (handled server-side) stays authoritative.
      addresses = await _addressRepository.getAddresses();
      return null;
    } catch (e) {
      return e.toString();
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }

  /// Returns null on success, or an error message on failure.
  Future<String?> deleteAddress(String id) async {
    try {
      await _addressRepository.deleteAddress(id);
      addresses.removeWhere((a) => a.id == id);
      notifyListeners();
      return null;
    } catch (e) {
      return e.toString();
    }
  }
}
