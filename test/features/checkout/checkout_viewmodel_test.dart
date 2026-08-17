import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:blukios_marketplace/core/providers.dart';
import 'package:blukios_marketplace/features/address/data/address_repository.dart';
import 'package:blukios_marketplace/features/address/models/address_model.dart';
import 'package:blukios_marketplace/features/cart/models/cart_model.dart';
import 'package:blukios_marketplace/features/checkout/viewmodels/checkout_viewmodel.dart';
import 'package:blukios_marketplace/features/shipment/data/shipment_repository.dart';
import 'package:blukios_marketplace/features/shipment/models/courier_option_model.dart';
import 'package:blukios_marketplace/features/transaction/data/transaction_repository.dart';
import 'package:blukios_marketplace/features/transaction/models/transaction_model.dart';

class MockAddressRepository extends Mock implements AddressRepository {}

class MockShipmentRepository extends Mock implements ShipmentRepository {}

class MockTransactionRepository extends Mock implements TransactionRepository {}

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

CartGroupModel _group({String storeAddressId = 'shop-city-1'}) {
  return CartGroupModel(
    storeId: 'store-1',
    storeName: 'Test Store',
    storeAddressId: storeAddressId,
    items: [
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
  late ProviderContainer container;
  late CartGroupModel testGroup;

  setUp(() {
    addressRepository = MockAddressRepository();
    shipmentRepository = MockShipmentRepository();
    transactionRepository = MockTransactionRepository();
    testGroup = _group();
    container = ProviderContainer(
      overrides: [
        addressRepositoryProvider.overrideWithValue(addressRepository),
        shipmentRepositoryProvider.overrideWithValue(shipmentRepository),
        transactionRepositoryProvider.overrideWithValue(transactionRepository),
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
  });
}
