import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:blukios_marketplace/core/providers.dart';
import 'package:blukios_marketplace/core/network/api_exceptions.dart';
import 'package:blukios_marketplace/features/address/data/address_repository.dart';
import 'package:blukios_marketplace/features/address/models/address_model.dart';
import 'package:blukios_marketplace/core/network/api_response.dart';
import 'package:blukios_marketplace/features/balance/data/buyer_balance_repository.dart';
import 'package:blukios_marketplace/features/balance/models/buyer_balance_model.dart';
import 'package:blukios_marketplace/features/cart/models/cart_model.dart';
import 'package:blukios_marketplace/features/checkout/data/voucher_repository.dart';
import 'package:blukios_marketplace/features/checkout/models/voucher_model.dart';
import 'package:blukios_marketplace/features/checkout/viewmodels/checkout_viewmodel.dart';
import 'package:blukios_marketplace/features/shipment/data/shipment_repository.dart';
import 'package:blukios_marketplace/features/shipment/models/courier_option_model.dart';
import 'package:blukios_marketplace/features/transaction/data/transaction_repository.dart';
import 'package:blukios_marketplace/features/transaction/models/transaction_model.dart';

class MockAddressRepository extends Mock implements AddressRepository {}

class MockShipmentRepository extends Mock implements ShipmentRepository {}

class MockTransactionRepository extends Mock implements TransactionRepository {}

class MockVoucherRepository extends Mock implements VoucherRepository {}

class MockBuyerBalanceRepository extends Mock implements BuyerBalanceRepository {}

BuyerBalancePage _balance(int amount) => BuyerBalancePage(
      balance: amount,
      histories: const PaginatedResponse(
        items: [],
        meta: PaginationMeta(currentPage: 1, lastPage: 1, perPage: 20, total: 0),
      ),
    );

AddressModel _address({String id = 'addr-1', bool isPrimary = false, String cityId = 'city-1'}) {
  return AddressModel(
    id: id,
    label: 'Rumah',
    recipientName: 'Budi',
    phone: '081234567890',
    address: 'Jl. Test No.1',
    city: 'Jakarta',
    cityId: cityId,
    postalCode: '12345',
    isPrimary: isPrimary,
  );
}

CartGroupModel _group({String storeAddressId = 'shop-city-1', List<CartItemModel>? items}) {
  return CartGroupModel(
    storeId: 'store-1',
    storeName: 'Test Store',
    storeAddressId: storeAddressId,
    items: items ??
        [
          CartItemModel(
            id: 'item-1',
            productId: 'prod-1',
            quantity: 2,
            productName: 'Test Product',
            price: 10000,
            stock: 10,
            weight: 1.0,
          ),
        ],
  );
}

TransactionModel _transaction() {
  return TransactionModel(
    id: 'trx-1',
    code: 'TRX001',
    shippingCost: 5000,
    deliveryStatus: 'pending',
    tax: 2200,
    grandTotal: 27200,
    paymentStatus: 'pending',
    transactionDetails: const [],
  );
}

void main() {
  late MockAddressRepository addressRepository;
  late MockShipmentRepository shipmentRepository;
  late MockTransactionRepository transactionRepository;
  late MockVoucherRepository voucherRepository;
  late MockBuyerBalanceRepository balanceRepository;
  late ProviderContainer container;
  late CartGroupModel testGroup;

  setUp(() {
    addressRepository = MockAddressRepository();
    shipmentRepository = MockShipmentRepository();
    transactionRepository = MockTransactionRepository();
    voucherRepository = MockVoucherRepository();
    balanceRepository = MockBuyerBalanceRepository();
    when(() => balanceRepository.getBalance()).thenAnswer((_) async => _balance(0));
    testGroup = _group();
    container = ProviderContainer(
      overrides: [
        addressRepositoryProvider.overrideWithValue(addressRepository),
        shipmentRepositoryProvider.overrideWithValue(shipmentRepository),
        transactionRepositoryProvider.overrideWithValue(transactionRepository),
        voucherRepositoryProvider.overrideWithValue(voucherRepository),
        buyerBalanceRepositoryProvider.overrideWithValue(balanceRepository),
      ],
    );
  });

  tearDown(() => container.dispose());

  group('loadSavedAddresses', () {
    test('preselects the primary address when one exists', () async {
      final addresses = [_address(id: 'a1'), _address(id: 'a2', isPrimary: true)];
      when(() => addressRepository.getAddresses()).thenAnswer((_) async => addresses);

      await container.read(checkoutProvider(testGroup).notifier).loadSavedAddresses();

      final state = container.read(checkoutProvider(testGroup));
      expect(state.savedAddresses, addresses);
      expect(state.selectedAddress?.id, 'a2');
      expect(state.isLoadingAddresses, isFalse);
    });

    test('falls back to the first address when none is primary', () async {
      final addresses = [_address(id: 'a1'), _address(id: 'a2')];
      when(() => addressRepository.getAddresses()).thenAnswer((_) async => addresses);

      await container.read(checkoutProvider(testGroup).notifier).loadSavedAddresses();

      expect(container.read(checkoutProvider(testGroup)).selectedAddress?.id, 'a1');
    });
  });

  // Must match TransactionRepository::create on the API, or the summary
  // shows a different amount from what Midtrans charges.
  group('totals', () {
    final courier = CourierOptionModel(shippingName: 'JNE', serviceName: 'REG', shippingCostNet: 5000, code: 'jne');

    test('charge no tax and add the flat service fee', () {
      final data = CheckoutData(group: _group(), selectedCourier: courier);

      expect(data.subtotal, 20000);
      expect(data.serviceFee, 1000);
      expect(data.grandTotal, 26000); // 20000 + 5000 + 1000
    });

    test('a voucher never reduces the service fee', () {
      final data = CheckoutData(
        group: _group(),
        selectedCourier: courier,
        appliedVoucher: const VoucherModel(voucherId: 'v1', code: 'BESAR', discountAmount: 50000),
      );

      expect(data.grandTotal, 1000);
    });
  });

  group('selectAddress', () {
    test('resets any previously calculated shipping/courier', () async {
      when(() => addressRepository.getAddresses()).thenAnswer((_) async => [_address()]);
      await container.read(checkoutProvider(testGroup).notifier).loadSavedAddresses();

      when(() => shipmentRepository.calculate(
            shipperDestinationId: any(named: 'shipperDestinationId'),
            receiverDestinationId: any(named: 'receiverDestinationId'),
            itemValue: any(named: 'itemValue'),
            weight: any(named: 'weight'),
            receiverCityName: any(named: 'receiverCityName'),
          )).thenAnswer((_) async => [
            CourierOptionModel(shippingName: 'JNE', serviceName: 'REG', shippingCostNet: 5000, code: 'jne'),
          ]);
      final notifier = container.read(checkoutProvider(testGroup).notifier);
      await notifier.calculateShipping();
      notifier.selectCourier(
        CourierOptionModel(shippingName: 'JNE', serviceName: 'REG', shippingCostNet: 5000, code: 'jne'),
      );
      expect(container.read(checkoutProvider(testGroup)).selectedCourier, isNotNull);

      notifier.selectAddress(_address(id: 'new-addr'));

      final state = container.read(checkoutProvider(testGroup));
      expect(state.selectedAddress?.id, 'new-addr');
      expect(state.selectedCourier, isNull);
      expect(state.couriers, isEmpty);
    });
  });

  group('calculateShipping', () {
    test('populates couriers on success', () async {
      final couriers = [
        CourierOptionModel(shippingName: 'JNE', serviceName: 'REG', shippingCostNet: 5000, code: 'jne'),
      ];
      when(() => addressRepository.getAddresses()).thenAnswer((_) async => [_address()]);
      await container.read(checkoutProvider(testGroup).notifier).loadSavedAddresses();
      when(() => shipmentRepository.calculate(
            shipperDestinationId: any(named: 'shipperDestinationId'),
            receiverDestinationId: any(named: 'receiverDestinationId'),
            itemValue: any(named: 'itemValue'),
            weight: any(named: 'weight'),
            receiverCityName: any(named: 'receiverCityName'),
          )).thenAnswer((_) async => couriers);

      await container.read(checkoutProvider(testGroup).notifier).calculateShipping();

      final state = container.read(checkoutProvider(testGroup));
      expect(state.couriers, couriers);
      expect(state.shippingError, isNull);
      expect(state.isCalculatingShipping, isFalse);
    });

    test('surfaces an error when no address is selected yet', () async {
      // No loadSavedAddresses() call — selectedAddress stays null.
      await container.read(checkoutProvider(testGroup).notifier).calculateShipping();

      expect(container.read(checkoutProvider(testGroup)).shippingError, isNotNull);
      verifyNever(() => shipmentRepository.calculate(
            shipperDestinationId: any(named: 'shipperDestinationId'),
            receiverDestinationId: any(named: 'receiverDestinationId'),
            itemValue: any(named: 'itemValue'),
            weight: any(named: 'weight'),
          ));
    });
  });

  group('submit', () {
    test('fails fast with no address selected, never calls the repository', () async {
      final result = await container.read(checkoutProvider(testGroup).notifier).submit(buyerId: 'buyer-1');

      expect(result, isNull);
      expect(container.read(checkoutProvider(testGroup)).submitError, isNotNull);
      verifyNever(() => transactionRepository.createTransaction(
            idempotencyKey: any(named: 'idempotencyKey'),
            buyerId: any(named: 'buyerId'),
            storeId: any(named: 'storeId'),
            addressId: any(named: 'addressId'),
            address: any(named: 'address'),
            city: any(named: 'city'),
            postalCode: any(named: 'postalCode'),
            shipping: any(named: 'shipping'),
            shippingType: any(named: 'shippingType'),
            shippingCost: any(named: 'shippingCost'),
            products: any(named: 'products'),
          ));
    });

    test('fails fast with no courier selected, even with an address chosen', () async {
      when(() => addressRepository.getAddresses()).thenAnswer((_) async => [_address()]);
      await container.read(checkoutProvider(testGroup).notifier).loadSavedAddresses();

      final result = await container.read(checkoutProvider(testGroup).notifier).submit(buyerId: 'buyer-1');

      expect(result, isNull);
      expect(container.read(checkoutProvider(testGroup)).submitError, isNotNull);
    });

    test('success returns the created transaction', () async {
      when(() => addressRepository.getAddresses()).thenAnswer((_) async => [_address()]);
      await container.read(checkoutProvider(testGroup).notifier).loadSavedAddresses();
      final notifier = container.read(checkoutProvider(testGroup).notifier);
      notifier.selectCourier(
        CourierOptionModel(shippingName: 'JNE', serviceName: 'REG', shippingCostNet: 5000, code: 'jne'),
      );
      final transaction = _transaction();
      when(() => transactionRepository.createTransaction(
            idempotencyKey: any(named: 'idempotencyKey'),
            buyerId: any(named: 'buyerId'),
            storeId: any(named: 'storeId'),
            addressId: any(named: 'addressId'),
            address: any(named: 'address'),
            city: any(named: 'city'),
            postalCode: any(named: 'postalCode'),
            destLatitude: any(named: 'destLatitude'),
            destLongitude: any(named: 'destLongitude'),
            shipping: any(named: 'shipping'),
            shippingType: any(named: 'shippingType'),
            shippingCost: any(named: 'shippingCost'),
            products: any(named: 'products'),
          )).thenAnswer((_) async => transaction);

      final result = await notifier.submit(buyerId: 'buyer-1');

      expect(result, transaction);
      expect(container.read(checkoutProvider(testGroup)).isSubmitting, isFalse);
      expect(container.read(checkoutProvider(testGroup)).submitError, isNull);
    });

    // TransactionRepository::resolveVariant() di backend menolak checkout
    // produk bervarian tanpa variant_id -- submit() sebelumnya cuma kirim
    // product_id/qty, jadi checkout varian selalu gagal di server meski
    // sudah lolos semua validasi lokal.
    test('includes variant_id in the products payload when the cart line has one', () async {
      final groupWithVariant = _group(items: [
        CartItemModel(
          id: 'item-1',
          productId: 'prod-1',
          variantId: 'variant-mahal',
          quantity: 2,
          productName: 'Test Product',
          price: 150000,
          stock: 5,
          weight: 1.0,
        ),
      ]);
      final container2 = ProviderContainer(
        overrides: [
          addressRepositoryProvider.overrideWithValue(addressRepository),
          shipmentRepositoryProvider.overrideWithValue(shipmentRepository),
          transactionRepositoryProvider.overrideWithValue(transactionRepository),
          voucherRepositoryProvider.overrideWithValue(voucherRepository),
          buyerBalanceRepositoryProvider.overrideWithValue(balanceRepository),
        ],
      );
      addTearDown(container2.dispose);

      when(() => addressRepository.getAddresses()).thenAnswer((_) async => [_address()]);
      await container2.read(checkoutProvider(groupWithVariant).notifier).loadSavedAddresses();
      final notifier = container2.read(checkoutProvider(groupWithVariant).notifier);
      notifier.selectCourier(
        CourierOptionModel(shippingName: 'JNE', serviceName: 'REG', shippingCostNet: 5000, code: 'jne'),
      );
      when(() => transactionRepository.createTransaction(
            idempotencyKey: any(named: 'idempotencyKey'),
            buyerId: any(named: 'buyerId'),
            storeId: any(named: 'storeId'),
            addressId: any(named: 'addressId'),
            address: any(named: 'address'),
            city: any(named: 'city'),
            postalCode: any(named: 'postalCode'),
            destLatitude: any(named: 'destLatitude'),
            destLongitude: any(named: 'destLongitude'),
            shipping: any(named: 'shipping'),
            shippingType: any(named: 'shippingType'),
            shippingCost: any(named: 'shippingCost'),
            products: any(named: 'products'),
          )).thenAnswer((_) async => _transaction());

      await notifier.submit(buyerId: 'buyer-1');

      verify(() => transactionRepository.createTransaction(
            idempotencyKey: any(named: 'idempotencyKey'),
            buyerId: any(named: 'buyerId'),
            storeId: any(named: 'storeId'),
            addressId: any(named: 'addressId'),
            address: any(named: 'address'),
            city: any(named: 'city'),
            postalCode: any(named: 'postalCode'),
            destLatitude: any(named: 'destLatitude'),
            destLongitude: any(named: 'destLongitude'),
            shipping: any(named: 'shipping'),
            shippingType: any(named: 'shippingType'),
            shippingCost: any(named: 'shippingCost'),
            products: [
              {'product_id': 'prod-1', 'variant_id': 'variant-mahal', 'qty': 2},
            ],
          )).called(1);
    });

    test('passes the applied voucher code through to the repository', () async {
      when(() => addressRepository.getAddresses()).thenAnswer((_) async => [_address()]);
      await container.read(checkoutProvider(testGroup).notifier).loadSavedAddresses();
      final notifier = container.read(checkoutProvider(testGroup).notifier);
      notifier.selectCourier(
        CourierOptionModel(shippingName: 'JNE', serviceName: 'REG', shippingCostNet: 5000, code: 'jne'),
      );
      when(() => voucherRepository.validateVoucher(
            code: any(named: 'code'),
            storeId: any(named: 'storeId'),
            subtotal: any(named: 'subtotal'),
          )).thenAnswer((_) async => const VoucherModel(
            voucherId: 'v1',
            code: 'HEMAT10',
            discountAmount: 2000,
          ));
      await notifier.applyVoucherCode('hemat10');

      final transaction = _transaction();
      when(() => transactionRepository.createTransaction(
            idempotencyKey: any(named: 'idempotencyKey'),
            buyerId: any(named: 'buyerId'),
            storeId: any(named: 'storeId'),
            addressId: any(named: 'addressId'),
            address: any(named: 'address'),
            city: any(named: 'city'),
            postalCode: any(named: 'postalCode'),
            destLatitude: any(named: 'destLatitude'),
            destLongitude: any(named: 'destLongitude'),
            shipping: any(named: 'shipping'),
            shippingType: any(named: 'shippingType'),
            shippingCost: any(named: 'shippingCost'),
            products: any(named: 'products'),
            voucherCode: any(named: 'voucherCode'),
          )).thenAnswer((_) async => transaction);

      await notifier.submit(buyerId: 'buyer-1');

      verify(() => transactionRepository.createTransaction(
            idempotencyKey: any(named: 'idempotencyKey'),
            buyerId: any(named: 'buyerId'),
            storeId: any(named: 'storeId'),
            addressId: any(named: 'addressId'),
            address: any(named: 'address'),
            city: any(named: 'city'),
            postalCode: any(named: 'postalCode'),
            destLatitude: any(named: 'destLatitude'),
            destLongitude: any(named: 'destLongitude'),
            shipping: any(named: 'shipping'),
            shippingType: any(named: 'shippingType'),
            shippingCost: any(named: 'shippingCost'),
            products: any(named: 'products'),
            voucherCode: 'HEMAT10',
          )).called(1);
    });
  });

  group('applyVoucherCode', () {
    test('sets appliedVoucher and reduces grandTotal on success', () async {
      when(() => voucherRepository.validateVoucher(
            code: any(named: 'code'),
            storeId: any(named: 'storeId'),
            subtotal: any(named: 'subtotal'),
          )).thenAnswer((_) async => const VoucherModel(
            voucherId: 'v1',
            code: 'HEMAT10',
            discountAmount: 2000,
          ));

      final notifier = container.read(checkoutProvider(testGroup).notifier);
      final before = container.read(checkoutProvider(testGroup)).grandTotal;
      await notifier.applyVoucherCode('HEMAT10');

      final state = container.read(checkoutProvider(testGroup));
      expect(state.appliedVoucher?.code, 'HEMAT10');
      expect(state.isValidatingVoucher, isFalse);
      expect(state.voucherError, isNull);
      expect(state.grandTotal, before - 2000);
    });

    test('surfaces the backend message and does not apply on failure', () async {
      when(() => voucherRepository.validateVoucher(
            code: any(named: 'code'),
            storeId: any(named: 'storeId'),
            subtotal: any(named: 'subtotal'),
          )).thenThrow(ApiException(message: 'Kode voucher tidak ditemukan'));

      final notifier = container.read(checkoutProvider(testGroup).notifier);
      await notifier.applyVoucherCode('SALAH');

      final state = container.read(checkoutProvider(testGroup));
      expect(state.appliedVoucher, isNull);
      expect(state.voucherError, 'Kode voucher tidak ditemukan');
    });

    test('removeVoucher clears the applied voucher and restores grandTotal', () async {
      when(() => voucherRepository.validateVoucher(
            code: any(named: 'code'),
            storeId: any(named: 'storeId'),
            subtotal: any(named: 'subtotal'),
          )).thenAnswer((_) async => const VoucherModel(
            voucherId: 'v1',
            code: 'HEMAT10',
            discountAmount: 2000,
          ));
      final notifier = container.read(checkoutProvider(testGroup).notifier);
      await notifier.applyVoucherCode('HEMAT10');
      final withDiscount = container.read(checkoutProvider(testGroup)).grandTotal;

      notifier.removeVoucher();

      final state = container.read(checkoutProvider(testGroup));
      expect(state.appliedVoucher, isNull);
      expect(state.grandTotal, withDiscount + 2000);
    });
  });

  group('Saldo Blukios', () {
    final courier = CourierOptionModel(shippingName: 'JNE', serviceName: 'REG', shippingCostNet: 5000, code: 'jne');

    test('preview: saldo covers up to the total, the rest is due', () {
      // grandTotal = 20000 + 5000 + 1000 = 26000
      final partial = CheckoutData(group: _group(), selectedCourier: courier, balance: 10000, useBalance: true);
      expect(partial.balanceToUse, 10000);
      expect(partial.amountDue, 16000);

      final full = CheckoutData(group: _group(), selectedCourier: courier, balance: 50000, useBalance: true);
      expect(full.balanceToUse, 26000);
      expect(full.amountDue, 0);

      final off = CheckoutData(group: _group(), selectedCourier: courier, balance: 50000);
      expect(off.balanceToUse, 0);
      expect(off.amountDue, 26000);
    });

    void stubCreate(Future<TransactionModel> Function(Invocation) answer) {
      when(() => transactionRepository.createTransaction(
            idempotencyKey: any(named: 'idempotencyKey'),
            buyerId: any(named: 'buyerId'),
            storeId: any(named: 'storeId'),
            addressId: any(named: 'addressId'),
            address: any(named: 'address'),
            city: any(named: 'city'),
            postalCode: any(named: 'postalCode'),
            destLatitude: any(named: 'destLatitude'),
            destLongitude: any(named: 'destLongitude'),
            shipping: any(named: 'shipping'),
            shippingType: any(named: 'shippingType'),
            shippingCost: any(named: 'shippingCost'),
            products: any(named: 'products'),
            voucherCode: any(named: 'voucherCode'),
            useBalance: any(named: 'useBalance'),
          )).thenAnswer(answer);
    }

    Future<CheckoutNotifier> ready() async {
      when(() => addressRepository.getAddresses()).thenAnswer((_) async => [_address()]);
      final notifier = container.read(checkoutProvider(testGroup).notifier);
      await notifier.loadSavedAddresses();
      notifier.selectCourier(courier);
      stubCreate((_) async => _transaction());
      return notifier;
    }

    void verifyUseBalance(bool expected) {
      verify(() => transactionRepository.createTransaction(
            idempotencyKey: any(named: 'idempotencyKey'),
            buyerId: any(named: 'buyerId'),
            storeId: any(named: 'storeId'),
            addressId: any(named: 'addressId'),
            address: any(named: 'address'),
            city: any(named: 'city'),
            postalCode: any(named: 'postalCode'),
            destLatitude: any(named: 'destLatitude'),
            destLongitude: any(named: 'destLongitude'),
            shipping: any(named: 'shipping'),
            shippingType: any(named: 'shippingType'),
            shippingCost: any(named: 'shippingCost'),
            products: any(named: 'products'),
            voucherCode: any(named: 'voucherCode'),
            useBalance: expected,
          )).called(1);
    }

    test('use_balance is sent when switched on with saldo', () async {
      when(() => balanceRepository.getBalance()).thenAnswer((_) async => _balance(10000));
      final notifier = await ready();
      await notifier.loadBalance();
      expect(container.read(checkoutProvider(testGroup)).balance, 10000);

      notifier.setUseBalance(true);
      await notifier.submit(buyerId: 'buyer-1');

      verifyUseBalance(true);
    });

    test('use_balance is not sent when the switch is off', () async {
      when(() => balanceRepository.getBalance()).thenAnswer((_) async => _balance(10000));
      final notifier = await ready();
      await notifier.loadBalance();

      await notifier.submit(buyerId: 'buyer-1');

      verifyUseBalance(false);
    });

    test('use_balance is not sent when the saldo is empty, even switched on', () async {
      final notifier = await ready();
      await notifier.loadBalance();

      notifier.setUseBalance(true);
      await notifier.submit(buyerId: 'buyer-1');

      verifyUseBalance(false);
    });

    test('a failed checkout refreshes the saldo', () async {
      when(() => balanceRepository.getBalance()).thenAnswer((_) async => _balance(10000));
      final notifier = await ready();
      await notifier.loadBalance();
      notifier.setUseBalance(true);
      stubCreate((_) async => throw ApiException(message: 'Saldo Blukios tidak cukup', statusCode: 422));
      when(() => balanceRepository.getBalance()).thenAnswer((_) async => _balance(0));

      final result = await notifier.submit(buyerId: 'buyer-1');
      expect(result, isNull);
      expect(container.read(checkoutProvider(testGroup)).submitError, 'Saldo Blukios tidak cukup');

      await pumpEventQueue(); // the refresh doesn't hold up the error
      final state = container.read(checkoutProvider(testGroup));
      expect(state.balance, 0);
      expect(state.balanceToUse, 0);
    });

    test('a saldo that cannot be loaded is not offered with a stale amount', () async {
      when(() => balanceRepository.getBalance()).thenAnswer((_) async => _balance(10000));
      final notifier = await ready();
      await notifier.loadBalance();
      when(() => balanceRepository.getBalance())
          .thenThrow(ApiException(message: 'Terjadi kesalahan', statusCode: 500));

      await notifier.loadBalance();

      expect(container.read(checkoutProvider(testGroup)).balance, 0);
    });
  });

  group('idempotency', () {
    final courier = CourierOptionModel(shippingName: 'JNE', serviceName: 'REG', shippingCostNet: 5000, code: 'jne');

    void stubCreate(Future<TransactionModel> Function(Invocation) answer) {
      when(() => transactionRepository.createTransaction(
            idempotencyKey: any(named: 'idempotencyKey'),
            buyerId: any(named: 'buyerId'),
            storeId: any(named: 'storeId'),
            addressId: any(named: 'addressId'),
            address: any(named: 'address'),
            city: any(named: 'city'),
            postalCode: any(named: 'postalCode'),
            destLatitude: any(named: 'destLatitude'),
            destLongitude: any(named: 'destLongitude'),
            shipping: any(named: 'shipping'),
            shippingType: any(named: 'shippingType'),
            shippingCost: any(named: 'shippingCost'),
            products: any(named: 'products'),
            voucherCode: any(named: 'voucherCode'),
            useBalance: any(named: 'useBalance'),
          )).thenAnswer(answer);
    }

    List<String> sentKeys() => verify(() => transactionRepository.createTransaction(
          idempotencyKey: captureAny(named: 'idempotencyKey'),
          buyerId: any(named: 'buyerId'),
          storeId: any(named: 'storeId'),
          addressId: any(named: 'addressId'),
          address: any(named: 'address'),
          city: any(named: 'city'),
          postalCode: any(named: 'postalCode'),
          destLatitude: any(named: 'destLatitude'),
          destLongitude: any(named: 'destLongitude'),
          shipping: any(named: 'shipping'),
          shippingType: any(named: 'shippingType'),
          shippingCost: any(named: 'shippingCost'),
          products: any(named: 'products'),
          voucherCode: any(named: 'voucherCode'),
          useBalance: any(named: 'useBalance'),
        )).captured.cast<String>();

    Future<CheckoutNotifier> ready() async {
      when(() => addressRepository.getAddresses()).thenAnswer((_) async => [_address()]);
      final notifier = container.read(checkoutProvider(testGroup).notifier);
      await notifier.loadSavedAddresses();
      notifier.selectCourier(courier);
      return notifier;
    }

    final networkError = ApiException(message: 'Tidak ada koneksi internet');

    test('a double submit sends one request', () async {
      final notifier = await ready();
      final response = Completer<TransactionModel>();
      stubCreate((_) => response.future);

      final first = notifier.submit(buyerId: 'buyer-1');
      final second = await notifier.submit(buyerId: 'buyer-1');
      response.complete(_transaction());

      expect(second, isNull);
      expect(await first, isNotNull);
      expect(sentKeys(), hasLength(1));
    });

    test('a retry after a network error reuses the key and says the order may exist', () async {
      final notifier = await ready();
      stubCreate((_) async => throw networkError);
      await notifier.submit(buyerId: 'buyer-1');
      expect(
        container.read(checkoutProvider(testGroup)).submitError,
        'Periksa menu Transaksi — pesanan mungkin sudah dibuat',
      );

      stubCreate((_) async => _transaction());
      await notifier.submit(buyerId: 'buyer-1');

      final keys = sentKeys();
      expect(keys, hasLength(2));
      expect(keys[1], keys[0]);
    });

    test('toggling Saldo Blukios makes the next submit a new attempt', () async {
      when(() => balanceRepository.getBalance()).thenAnswer((_) async => _balance(10000));
      final notifier = await ready();
      await notifier.loadBalance();
      stubCreate((_) async => throw networkError);
      await notifier.submit(buyerId: 'buyer-1');

      notifier.setUseBalance(true);
      await notifier.submit(buyerId: 'buyer-1');

      final keys = sentKeys();
      expect(keys[1], isNot(keys[0]));
    });

    test('after a successful order the next submit gets a new key', () async {
      final notifier = await ready();
      stubCreate((_) async => _transaction());
      await notifier.submit(buyerId: 'buyer-1');
      await notifier.submit(buyerId: 'buyer-1');

      final keys = sentKeys();
      expect(keys[1], isNot(keys[0]));
    });
  });

  group('checkoutOutcome', () {
    TransactionModel order({String? snapToken, bool paidWithBalance = false}) => TransactionModel(
          id: 'trx-1',
          code: 'TRX001',
          shippingCost: 5000,
          deliveryStatus: 'pending',
          tax: 0,
          grandTotal: 26000,
          balanceUsed: paidWithBalance ? 26000 : 0,
          paidWithBalance: paidWithBalance,
          paymentStatus: paidWithBalance ? 'paid' : 'pending',
          snapToken: snapToken,
          transactionDetails: const [],
        );

    test('paid fully with saldo skips the payment page', () {
      expect(checkoutOutcome(order(paidWithBalance: true)), CheckoutOutcome.paidWithBalance);
    });

    test('paid with saldo skips the payment page even if a snap token came along', () {
      expect(
        checkoutOutcome(order(paidWithBalance: true, snapToken: 'snap-1')),
        CheckoutOutcome.paidWithBalance,
      );
    });

    test('a snap token opens the payment page', () {
      expect(checkoutOutcome(order(snapToken: 'snap-1')), CheckoutOutcome.openPayment);
    });

    test('no snap token and not paid with saldo is still an error', () {
      expect(checkoutOutcome(order()), CheckoutOutcome.paymentPageMissing);
    });
  });
}
