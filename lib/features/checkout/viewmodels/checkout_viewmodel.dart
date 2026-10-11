import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:blukios_marketplace/core/monitoring/analytics_service.dart';
import 'package:blukios_marketplace/core/network/api_exceptions.dart';
import 'package:blukios_marketplace/core/providers.dart';
import 'package:blukios_marketplace/core/utils/idempotency_key.dart';
import 'package:blukios_marketplace/features/address/models/address_model.dart';
import 'package:blukios_marketplace/features/balance/viewmodels/buyer_balance_viewmodel.dart';
import 'package:blukios_marketplace/features/cart/models/cart_model.dart';
import 'package:blukios_marketplace/features/checkout/models/voucher_model.dart';
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
  final VoucherModel? appliedVoucher;
  final bool isValidatingVoucher;
  final String? voucherError;

  /// Saldo Blukios available (0 until loaded or when it can't be).
  final int balance;
  final bool useBalance;

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
    this.appliedVoucher,
    this.isValidatingVoucher = false,
    this.voucherError,
    this.balance = 0,
    this.useBalance = false,
  });

  /// Flat platform fee per order, mirroring the API's
  /// `marketplace.buyer_service_fee`. Buyers pay no 11% tax since
  /// 2026-10-02; the server recomputes the real total on checkout.
  static const double buyerServiceFee = 1000;

  double get subtotal => group.subtotal;
  double get shippingCost => selectedCourier?.shippingCostNet ?? 0;
  double get discountAmount => appliedVoucher?.discountAmount ?? 0;
  double get serviceFee => buyerServiceFee;

  /// Same order as TransactionRepository::create: the discount is clamped
  /// before the service fee is added, so a voucher never reduces the fee.
  double get grandTotal =>
      (subtotal + shippingCost - discountAmount).clamp(0, double.infinity) + serviceFee;

  /// What Saldo Blukios would cover. A preview: the server recomputes it.
  double get balanceToUse =>
      useBalance && balance > 0 ? min(balance.toDouble(), grandTotal) : 0;

  /// "Sisa Dibayar": what's left for Midtrans.
  double get amountDue => grandTotal - balanceToUse;

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
    VoucherModel? appliedVoucher,
    bool clearAppliedVoucher = false,
    bool? isValidatingVoucher,
    String? voucherError,
    bool clearVoucherError = false,
    int? balance,
    bool? useBalance,
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
      appliedVoucher:
          clearAppliedVoucher ? null : (appliedVoucher ?? this.appliedVoucher),
      isValidatingVoucher: isValidatingVoucher ?? this.isValidatingVoucher,
      voucherError:
          clearVoucherError ? null : (voucherError ?? this.voucherError),
      balance: balance ?? this.balance,
      useBalance: useBalance ?? this.useBalance,
    );
  }
}

/// Keyed by the cart group being checked out, so each checkout screen has
/// isolated state and is disposed when the screen closes.
class CheckoutNotifier
    extends AutoDisposeFamilyNotifier<CheckoutData, CartGroupModel> {
  bool _disposed = false;

  /// X-Idempotency-Key of the current checkout attempt and what it ordered.
  String? _idempotencyKey;
  String? _attempt;

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

  /// Refreshes the shared Saldo Blukios and mirrors it here.
  Future<void> loadBalance() async {
    await ref.read(buyerBalanceProvider.notifier).load();
    if (_disposed) return;
    state = state.copyWith(balance: ref.read(buyerBalanceProvider).balance ?? 0);
  }

  void setUseBalance(bool value) => state = state.copyWith(useBalance: value);

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

  /// Preview-validates a voucher code against this checkout's store +
  /// subtotal. Only sets [CheckoutData.appliedVoucher] on success — the
  /// backend re-validates everything again at [submit] time, since a
  /// validate-then-checkout race is possible (e.g. usage limit exhausted
  /// in between); if that happens the order still goes through, just
  /// without the discount, rather than failing checkout outright.
  Future<void> applyVoucherCode(String code) async {
    if (code.trim().isEmpty) return;

    state = state.copyWith(
      isValidatingVoucher: true,
      clearVoucherError: true,
    );

    try {
      final voucher = await ref.read(voucherRepositoryProvider).validateVoucher(
            code: code.trim(),
            storeId: state.group.storeId,
            subtotal: state.subtotal,
          );
      if (_disposed) return;
      state = state.copyWith(
        appliedVoucher: voucher,
        isValidatingVoucher: false,
      );
    } catch (e) {
      if (_disposed) return;
      state = state.copyWith(
        isValidatingVoucher: false,
        voucherError: e is ApiException ? e.message : 'Gagal memeriksa voucher',
      );
    }
  }

  void removeVoucher() {
    state = state.copyWith(clearAppliedVoucher: true, clearVoucherError: true);
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
    // A second tap while the first request runs must not order twice.
    if (state.isSubmitting) return null;

    final useBalance = state.useBalance && state.balance > 0;
    // Same order = same key, so a retry after a lost response is answered
    // with the first result (API IdempotencyMiddleware) instead of ordering
    // again. Any change to what is ordered makes it a new attempt.
    final attempt = [
      buyerId,
      address.id,
      courier.shippingName,
      courier.serviceName,
      courier.shippingCostNet,
      state.appliedVoucher?.code,
      useBalance,
      for (final item in state.group.items)
        '${item.productId}/${item.variantId}/${item.quantity}',
    ].join('|');
    if (attempt != _attempt) {
      _attempt = attempt;
      _idempotencyKey = IdempotencyKey.generate();
    }

    state = state.copyWith(isSubmitting: true, clearSubmitError: true);

    try {
      final transaction =
          await ref.read(transactionRepositoryProvider).createTransaction(
                idempotencyKey: _idempotencyKey!,
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
                    .map((item) => {
                          'product_id': item.productId,
                          'variant_id': item.variantId,
                          'qty': item.quantity,
                        })
                    .toList(),
                voucherCode: state.appliedVoucher?.code,
                useBalance: useBalance,
              );
      // Done: the next submit is a new order.
      _attempt = null;
      _idempotencyKey = null;
      // The saldo may have moved; refresh it for the rest of the app.
      unawaited(ref.read(buyerBalanceProvider.notifier).load());
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
      // No server answer (timeout, connection) or an unreadable one: the
      // order may exist. A retry is safe, the key is kept.
      final serverMessage =
          e is ApiException && e.statusCode != null ? e.message : null;
      state = state.copyWith(
        isSubmitting: false,
        submitError: serverMessage ??
            'Periksa menu Transaksi — pesanan mungkin sudah dibuat',
      );
      // E.g. 422: another checkout spent the saldo first. Show what's left.
      unawaited(loadBalance());
      return null;
    }
  }
}

final checkoutProvider = AutoDisposeNotifierProviderFamily<CheckoutNotifier,
    CheckoutData, CartGroupModel>(
  CheckoutNotifier.new,
);

/// What the checkout screen does with a created order.
enum CheckoutOutcome { paidWithBalance, openPayment, paymentPageMissing }

CheckoutOutcome checkoutOutcome(TransactionModel transaction) {
  if (transaction.paidWithBalance) return CheckoutOutcome.paidWithBalance;
  if (transaction.snapToken == null) return CheckoutOutcome.paymentPageMissing;
  return CheckoutOutcome.openPayment;
}
