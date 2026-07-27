import 'package:flutter/foundation.dart';
import 'package:blukios_marketplace/features/address/data/address_repository.dart';
import 'package:blukios_marketplace/features/address/models/address_model.dart';
import 'package:blukios_marketplace/features/cart/models/cart_model.dart';
import 'package:blukios_marketplace/features/shipment/data/shipment_repository.dart';
import 'package:blukios_marketplace/features/shipment/models/courier_option_model.dart';
import 'package:blukios_marketplace/features/transaction/data/transaction_repository.dart';
import 'package:blukios_marketplace/features/transaction/models/transaction_model.dart';

class CheckoutViewModel extends ChangeNotifier {
  final CartGroupModel group;
  final AddressRepository _addressRepository;
  final ShipmentRepository _shipmentRepository;
  final TransactionRepository _transactionRepository;

  CheckoutViewModel(
    this.group,
    this._addressRepository,
    this._shipmentRepository,
    this._transactionRepository,
  );

  List<AddressModel> savedAddresses = [];
  bool isLoadingAddresses = true;

  AddressModel? selectedAddress;

  List<CourierOptionModel> couriers = [];
  CourierOptionModel? selectedCourier;
  bool isCalculatingShipping = false;
  String? shippingError;

  bool isSubmitting = false;
  String? submitError;

  double get subtotal => group.subtotal;
  double get tax => (subtotal * 0.11).roundToDouble();
  double get shippingCost => selectedCourier?.shippingCostNet ?? 0;
  double get grandTotal => subtotal + tax + shippingCost;

  Future<void> loadSavedAddresses() async {
    isLoadingAddresses = true;
    notifyListeners();

    try {
      savedAddresses = await _addressRepository.getAddresses();
      final primary = savedAddresses.where((a) => a.isPrimary);
      if (primary.isNotEmpty) {
        selectAddress(primary.first);
      } else if (savedAddresses.isNotEmpty) {
        selectAddress(savedAddresses.first);
      }
    } catch (_) {
      savedAddresses = [];
    } finally {
      isLoadingAddresses = false;
      notifyListeners();
    }
  }

  void selectAddress(AddressModel address) {
    selectedAddress = address;
    _resetShipping();
    notifyListeners();
  }

  void _resetShipping() {
    couriers = [];
    selectedCourier = null;
    shippingError = null;
  }

  Future<void> calculateShipping() async {
    final shipperId = group.storeAddressId;
    final address = selectedAddress;

    if (shipperId == null) {
      shippingError = 'Alamat toko tidak tersedia. Tidak bisa menghitung ongkir.';
      notifyListeners();
      return;
    }
    if (address == null) {
      shippingError = 'Pilih alamat pengiriman terlebih dahulu';
      notifyListeners();
      return;
    }

    isCalculatingShipping = true;
    shippingError = null;
    notifyListeners();

    try {
      couriers = await _shipmentRepository.calculate(
        shipperDestinationId: shipperId,
        receiverDestinationId: address.cityId,
        itemValue: subtotal,
        weight: group.totalWeight,
        receiverCityName: address.city,
      );
      if (couriers.isEmpty) {
        shippingError =
            'Kurir tidak tersedia untuk alamat ini. Coba pilih ulang alamat dengan kecamatan/kota yang lebih umum.';
      }
    } catch (e) {
      shippingError = 'Gagal menghitung ongkir. Silakan coba lagi.';
    } finally {
      isCalculatingShipping = false;
      notifyListeners();
    }
  }

  void selectCourier(CourierOptionModel courier) {
    selectedCourier = courier;
    notifyListeners();
  }

  /// Returns the created transaction on success, or null on failure
  /// (with [submitError] populated).
  Future<TransactionModel?> submit({required String buyerId}) async {
    final address = selectedAddress;
    final courier = selectedCourier;

    if (address == null) {
      submitError = 'Pilih alamat pengiriman terlebih dahulu';
      notifyListeners();
      return null;
    }
    if (courier == null) {
      submitError = 'Pilih kurir terlebih dahulu';
      notifyListeners();
      return null;
    }

    isSubmitting = true;
    submitError = null;
    notifyListeners();

    try {
      final transaction = await _transactionRepository.createTransaction(
        buyerId: buyerId,
        storeId: group.storeId,
        addressId: address.cityId,
        address: address.address,
        city: address.city,
        postalCode: address.postalCode,
        destLatitude: address.latitude,
        destLongitude: address.longitude,
        shipping: courier.shippingName,
        shippingType: courier.serviceName,
        shippingCost: courier.shippingCostNet,
        products: group.items
            .map((item) => {'product_id': item.productId, 'qty': item.quantity})
            .toList(),
      );
      return transaction;
    } catch (e) {
      submitError = e.toString();
      return null;
    } finally {
      isSubmitting = false;
      notifyListeners();
    }
  }
}
