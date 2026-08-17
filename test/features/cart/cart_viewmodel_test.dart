import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:blukios_marketplace/core/providers.dart';
import 'package:blukios_marketplace/features/cart/data/cart_repository.dart';
import 'package:blukios_marketplace/features/cart/models/cart_model.dart';
import 'package:blukios_marketplace/features/cart/viewmodels/cart_viewmodel.dart';

class MockCartRepository extends Mock implements CartRepository {}

CartItemModel _item({
  String id = 'item-1',
  String productId = 'prod-1',
  String? variantId,
  int quantity = 1,
  double price = 10000,
}) {
  return CartItemModel(
    id: id,
    productId: productId,
    variantId: variantId,
    quantity: quantity,
    productName: 'Test Product',
    price: price,
    stock: 10,
    weight: 1.0,
  );
}

CartGroupModel _group({
  String storeId = 'store-1',
  String storeName = 'Test Store',
  List<CartItemModel>? items,
}) {
  return CartGroupModel(
    storeId: storeId,
    storeName: storeName,
    items: items ?? [_item()],
  );
}

void main() {
  late MockCartRepository cartRepository;
  late ProviderContainer container;

  setUp(() {
    cartRepository = MockCartRepository();
    container = ProviderContainer(
      overrides: [cartRepositoryProvider.overrideWithValue(cartRepository)],
    );
  });

  tearDown(() => container.dispose());

  group('loadCart', () {
    test('success populates groups and clears loading', () async {
      final groups = [_group()];
      when(() => cartRepository.getCart()).thenAnswer((_) async => groups);

      await container.read(cartProvider.notifier).loadCart();

      final state = container.read(cartProvider);
      expect(state.groups, groups);
      expect(state.isLoading, isFalse);
      expect(state.error, isNull);
    });

    test('failure surfaces the error and clears loading', () async {
      when(() => cartRepository.getCart()).thenThrow(Exception('Tidak ada koneksi internet'));

      await container.read(cartProvider.notifier).loadCart();

      final state = container.read(cartProvider);
      expect(state.isLoading, isFalse);
      expect(state.error, contains('Tidak ada koneksi internet'));
    });
  });

  group('removeItem', () {
    test('removes the item from its group locally on success', () async {
      final groups = [
        _group(items: [_item(id: 'item-1', productId: 'prod-1'), _item(id: 'item-2', productId: 'prod-2')]),
      ];
      when(() => cartRepository.getCart()).thenAnswer((_) async => groups);
      await container.read(cartProvider.notifier).loadCart();

      when(() => cartRepository.removeFromCart('prod-1', variantId: null))
          .thenAnswer((_) async {});

      final error = await container.read(cartProvider.notifier).removeItem('prod-1');

      expect(error, isNull);
      final remainingItems = container.read(cartProvider).groups.single.items;
      expect(remainingItems, hasLength(1));
      expect(remainingItems.single.productId, 'prod-2');
    });

    test('a group with no items left is dropped entirely, not left empty', () async {
      final groups = [_group(items: [_item(id: 'item-1', productId: 'prod-1')])];
      when(() => cartRepository.getCart()).thenAnswer((_) async => groups);
      await container.read(cartProvider.notifier).loadCart();

      when(() => cartRepository.removeFromCart('prod-1', variantId: null))
          .thenAnswer((_) async {});

      await container.read(cartProvider.notifier).removeItem('prod-1');

      expect(container.read(cartProvider).groups, isEmpty);
    });

    test('failure returns the error message and leaves state unchanged', () async {
      final groups = [_group()];
      when(() => cartRepository.getCart()).thenAnswer((_) async => groups);
      await container.read(cartProvider.notifier).loadCart();

      when(() => cartRepository.removeFromCart('prod-1', variantId: null))
          .thenThrow(Exception('Gagal menghapus produk'));

      final error = await container.read(cartProvider.notifier).removeItem('prod-1');

      expect(error, contains('Gagal menghapus produk'));
      expect(container.read(cartProvider).groups.single.items, hasLength(1));
    });
  });

  group('removeGroup', () {
    test('drops the whole store group locally (post-checkout cleanup)', () async {
      final groups = [_group(storeId: 'store-1'), _group(storeId: 'store-2')];
      when(() => cartRepository.getCart()).thenAnswer((_) async => groups);
      await container.read(cartProvider.notifier).loadCart();

      container.read(cartProvider.notifier).removeGroup('store-1');

      final remaining = container.read(cartProvider).groups;
      expect(remaining, hasLength(1));
      expect(remaining.single.storeId, 'store-2');
    });
  });

  group('totalPrice', () {
    test('sums subtotal across all groups', () async {
      final groups = [
        _group(storeId: 's1', items: [_item(price: 10000, quantity: 2)]),
        _group(storeId: 's2', items: [_item(price: 5000, quantity: 3)]),
      ];
      when(() => cartRepository.getCart()).thenAnswer((_) async => groups);

      await container.read(cartProvider.notifier).loadCart();

      // (10000*2) + (5000*3) = 35000
      expect(container.read(cartProvider).totalPrice, 35000);
    });
  });
}
