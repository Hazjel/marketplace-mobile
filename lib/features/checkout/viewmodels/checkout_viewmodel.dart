import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:blukios_marketplace/core/monitoring/analytics_service.dart';
import 'package:blukios_marketplace/core/providers.dart';
import 'package:blukios_marketplace/features/address/models/address_model.dart';
import 'package:blukios_marketplace/features/cart/models/cart_model.dart';
import 'package:blukios_marketplace/features/shipment/models/courier_option_model.dart';
import 'package:blukios_marketplace/features/transaction/models/transaction_model.dart';

class CheckoutData {
  final CartGroupModel group;
  final List<AddressModel> savedAddresses;
  final bool isLoadingAddresses;
  final AddressModel? selectedAddress;
  final List<CourierOptionModel> couriers;
  final CourierOptionModel? selectedCourier;
  final bool isCalculatingShipping;
  final String? shippingError;
  final bool isSubmitting;
  final String? submitError;

  const CheckoutData({
    required this.group,
    this.savedAddresses = const [],
    this.isLoadingAddresses = true,
    this.selectedAddress,
    this.couriers = const [],
    this.selectedCourier,
    this.isCalculatingShipping = false,
    this.shippingError,
    this.isSubmitting = false,
    this.submitError,
  });

  double get subtotal => group.subtotal;
  double get tax => (subtotal * 0.11).roundToDouble();
  double get shippingCost => selectedCourier?.shippingCostNet ?? 0;
  double get grandTotal => subtotal + tax + shippingCost;

  CheckoutData copyWith({
    List<AddressModel>? savedAddresses,
    bool? isLoadingAddresses,
    AddressModel? selectedAddress,
    List<CourierOptionModel>? couriers,
    CourierOptionModel? selectedCourier,
    bool clearSelectedCourier = false,
    bool? isCalculatingShipping,
    String? shippingError,
    bool clearShippingError = false,
    bool? isSubmitting,
    String? submitError,
    bool clearSubmitError = false,
  }) {
    return CheckoutData(
      group: group,
      savedAddresses: savedAddresses ?? this.savedAddresses,
      isLoadingAddresses: isLoadingAddresses ?? this.isLoadingAddresses,
      selectedAddress: selectedAddress ?? this.selectedAddress,
      couriers: couriers ?? this.couriers,
      selectedCourier:
          clearSelectedCourier ? null : (selectedCourier ?? this.selectedCourier),
      isCalculatingShipping:
          isCalculatingShipping ?? this.isCalculatingShipping,
      shippingError:
          clearShippingError ? null : (shippingError ?? this.shippingError),
      isSubmitting: isSubmitting ?? this.isSubmitting,
      submitError: clearSubmitError ? null : (submitError ?? this.submitError),
    );
  }
}

/// Keyed by the cart group being checked out, so each checkout screen has
/// isolated state and is disposed when the screen closes.
class CheckoutNotifier
    extends AutoDisposeFamilyNotifier<CheckoutData, CartGroupModel> {
  bool _disposed = false;

  @override
  CheckoutData build(CartGroupModel group) {
    ref.onDispose(() => _disposed = true);
    return CheckoutData(group: group);
  }

  Future<void> loadSavedAddresses() async {
    state = state.copyWith(isLoadingAddresses: true);

    try {
      final addresses = await ref.read(addressRepositoryProvider).getAddresses();
      if (_disposed) return;
      final primary = addresses.where((a) => a.isPrimary);
      final preselected = primary.isNotEmpty
          ? primary.first
          : (addresses.isNotEmpty ? addresses.first : null);

      state = state.copyWith(
        savedAddresses: addresses,
        selectedAddress: preselected,
        isLoadingAddresses: false,
        // Selecting an address invalidates any previously fetched shipping.
        couriers: const [],
        clearSelectedCourier: true,
        clearShippingError: true,
      );
    } catch (_) {
      if (_disposed) return;
      state = state.copyWith(
        savedAddresses: const [],
        isLoadingAddresses: false,
      );
    }
  }

  void selectAddress(AddressModel address) {
    state = state.copyWith(
      selectedAddress: address,
      couriers: const [],
      clearSelectedCourier: true,
      clearShippingError: true,
    );
  }

  Future<void> calculateShipping() async {
    final shipperId = state.group.storeAddressId;
    final address = state.selectedAddress;

    if (shipperId == null) {
      state = state.copyWith(
        shippingError: 'Alamat toko tidak tersedia. Tidak bisa menghitung ongkir.',
      );
      return;
    }
    if (address == null) {
      state = state.copyWith(
        shippingError: 'Pilih alamat pengiriman terlebih dahulu',
      );
      return;
    }

    state = state.copyWith(
      isCalculatingShipping: true,
      clearShippingError: true,
    );

    try {
      final couriers = await ref.read(shipmentRepositoryProvider).calculate(
            shipperDestinationId: shipperId,
            receiverDestinationId: address.cityId,
            itemValue: state.subtotal,
            weight: state.group.totalWeight,
            receiverCityName: address.city,
          );
      if (_disposed) return;

      state = state.copyWith(
        couriers: couriers,
        isCalculatingShipping: false,
        shippingError: couriers.isEmpty
            ? 'Kurir tidak tersedia untuk alamat ini. Coba pilih ulang alamat dengan kecamatan/kota yang lebih umum.'
            : null,
      );
    } catch (e) {
      if (_disposed) return;
      state = state.copyWith(
        isCalculatingShipping: false,
        shippingError: 'Gagal menghitung ongkir. Silakan coba lagi.',
      );
    }
  }

  void selectCourier(CourierOptionModel courier) {
    state = state.copyWith(selectedCourier: courier);
  }

  /// Returns the created transaction on success, or null on failure
  /// (with [CheckoutData.submitError] populated).
  Future<TransactionModel?> submit({required String buyerId}) async {
    final address = state.selectedAddress;
    final courier = state.selectedCourier;

    if (address == null) {
      state = state.copyWith(submitError: 'Pilih alamat pengiriman terlebih dahulu');
      return null;
    }
    if (courier == null) {
      state = state.copyWith(submitError: 'Pilih kurir terlebih dahulu');
      return null;
    }

    state = state.copyWith(isSubmitting: true, clearSubmitError: true);

    try {
      final transaction =
          await ref.read(transactionRepositoryProvider).createTransaction(
                buyerId: buyerId,
                storeId: state.group.storeId,
                addressId: address.cityId,
                address: address.address,
                city: address.city,
                postalCode: address.postalCode,
                destLatitude: address.latitude,
                destLongitude: address.longitude,
                shipping: courier.shippingName,
                shippingType: courier.serviceName,
                shippingCost: courier.shippingCostNet,
                products: state.group.items
                    .map((item) =>
                        {'product_id': item.productId, 'qty': item.quantity})
                    .toList(),
              );
      if (_disposed) return null;
      state = state.copyWith(isSubmitting: false);
      AnalyticsService.logEvent('checkout_submitted', parameters: {
        'value': state.grandTotal,
        'currency': 'IDR',
        'store_id': state.group.storeId,
      });
      return transaction;
    } catch (e) {
      if (_disposed) return null;
      state = state.copyWith(isSubmitting: false, submitError: e.toString());
      return null;
    }
  }
}

final checkoutProvider = AutoDisposeNotifierProviderFamily<CheckoutNotifier,
    CheckoutData, CartGroupModel>(
  CheckoutNotifier.new,
);
