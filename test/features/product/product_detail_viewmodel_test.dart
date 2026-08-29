import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:blukios_marketplace/core/providers.dart';
import 'package:blukios_marketplace/features/cart/data/cart_repository.dart';
import 'package:blukios_marketplace/features/home/data/product_repository.dart';
import 'package:blukios_marketplace/features/home/models/product_model.dart';
import 'package:blukios_marketplace/features/product/viewmodels/product_detail_viewmodel.dart';
import 'package:blukios_marketplace/features/recommendation/data/recommendation_repository.dart';
import 'package:blukios_marketplace/features/recommendation/viewmodels/recommendation_viewmodel.dart';

class MockProductRepository extends Mock implements ProductRepository {}

class MockCartRepository extends Mock implements CartRepository {}

class MockRecommendationRepository extends Mock implements RecommendationRepository {}

ProductVariantModel _variant({
  String id = 'variant-1',
  String name = 'Merah/S',
  int price = 100000,
  int stock = 10,
}) {
  return ProductVariantModel(id: id, name: name, price: price, stock: stock);
}

ProductModel _product({
  bool hasVariants = false,
  List<ProductVariantModel> variants = const [],
  int price = 50000,
  int stock = 20,
}) {
  return ProductModel(
    id: 'prod-1',
    name: 'Kaos Variasi',
    slug: 'kaos-variasi',
    price: price,
    stock: stock,
    weight: 200,
    condition: 'new',
    totalSold: 3,
    hasVariants: hasVariants,
    variants: variants,
  );
}

void main() {
  late MockProductRepository productRepository;
  late MockCartRepository cartRepository;
  late MockRecommendationRepository recommendationRepository;
  late ProviderContainer container;

  setUp(() {
    productRepository = MockProductRepository();
    cartRepository = MockCartRepository();
    recommendationRepository = MockRecommendationRepository();
    when(() => recommendationRepository.trackView(
          productId: any(named: 'productId'),
          userId: any(named: 'userId'),
        )).thenAnswer((_) async {});
    when(() => recommendationRepository.fetchSimilar(any())).thenAnswer((_) async => []);

    container = ProviderContainer(
      overrides: [
        productRepositoryProvider.overrideWithValue(productRepository),
        cartRepositoryProvider.overrideWithValue(cartRepository),
        recommendationRepositoryProvider.overrideWithValue(recommendationRepository),
      ],
    );
  });

  tearDown(() => container.dispose());

  group('loadProduct — variant auto-select', () {
    // Sama seperti web's ProductDetail.vue: begitu halaman terbuka, harga
    // dan stok yang ditampilkan harus sudah valid untuk satu varian
    // spesifik, bukan agregat product.price/stock.
    test('auto-selects the first variant for a variant product', () async {
      final variants = [_variant(id: 'v1', price: 100000, stock: 10), _variant(id: 'v2', price: 150000, stock: 5)];
      when(() => productRepository.getProductBySlug('kaos-variasi'))
          .thenAnswer((_) async => _product(hasVariants: true, variants: variants));

      await container.read(productDetailProvider('kaos-variasi').notifier).loadProduct();

      final state = container.read(productDetailProvider('kaos-variasi'));
      expect(state.selectedVariant?.id, 'v1');
      expect(state.effectivePrice, 100000);
      expect(state.effectiveStock, 10);
    });

    test('leaves selectedVariant null for a non-variant product, uses aggregate price/stock', () async {
      when(() => productRepository.getProductBySlug('kaos-variasi'))
          .thenAnswer((_) async => _product(price: 50000, stock: 20));

      await container.read(productDetailProvider('kaos-variasi').notifier).loadProduct();

      final state = container.read(productDetailProvider('kaos-variasi'));
      expect(state.selectedVariant, isNull);
      expect(state.effectivePrice, 50000);
      expect(state.effectiveStock, 20);
    });
  });

  group('selectVariant', () {
    test('switches effectivePrice/effectiveStock to the newly picked variant', () async {
      final variants = [_variant(id: 'v1', price: 100000, stock: 10), _variant(id: 'v2', price: 150000, stock: 5)];
      when(() => productRepository.getProductBySlug('kaos-variasi'))
          .thenAnswer((_) async => _product(hasVariants: true, variants: variants));
      final notifier = container.read(productDetailProvider('kaos-variasi').notifier);
      await notifier.loadProduct();

      notifier.selectVariant(variants[1]);

      final state = container.read(productDetailProvider('kaos-variasi'));
      expect(state.selectedVariant?.id, 'v2');
      expect(state.effectivePrice, 150000);
      expect(state.effectiveStock, 5);
    });
  });

  group('addToCart', () {
    // Guard ini seharusnya tidak pernah kena kalau UI benar (auto-select di
    // loadProduct() menjamin ada pilihan default), tapi tetap dites supaya
    // regresi (mis. auto-select dihapus) ketahuan di sini, bukan lolos ke
    // server lalu baru gagal di TransactionRepository::resolveVariant().
    test('rejects when the product has variants but none is selected', () async {
      // has_variants=true with an empty variants list is an edge case the
      // backend shouldn't send, but it's exactly the shape that leaves
      // auto-select in loadProduct() with nothing to pick -- selectedVariant
      // stays null, which is the guard's real trigger condition.
      when(() => productRepository.getProductBySlug('kaos-variasi')).thenAnswer(
        (_) async => _product(hasVariants: true, variants: const []),
      );
      final notifier = container.read(productDetailProvider('kaos-variasi').notifier);
      await notifier.loadProduct();
      expect(container.read(productDetailProvider('kaos-variasi')).selectedVariant, isNull);

      final error = await notifier.addToCart();

      expect(error, 'Pilih varian terlebih dahulu');
      verifyNever(() => cartRepository.addToCart(
            productId: any(named: 'productId'),
            variantId: any(named: 'variantId'),
          ));
    });

    test('sends the selected variant id to the cart repository', () async {
      final variant = _variant(id: 'v1', price: 100000, stock: 10);
      when(() => productRepository.getProductBySlug('kaos-variasi'))
          .thenAnswer((_) async => _product(hasVariants: true, variants: [variant]));
      when(() => cartRepository.addToCart(
            productId: any(named: 'productId'),
            variantId: any(named: 'variantId'),
          )).thenAnswer((_) async {});
      final notifier = container.read(productDetailProvider('kaos-variasi').notifier);
      await notifier.loadProduct();

      final error = await notifier.addToCart();

      expect(error, isNull);
      verify(() => cartRepository.addToCart(productId: 'prod-1', variantId: 'v1')).called(1);
    });

    test('passes a null variantId for a non-variant product', () async {
      when(() => productRepository.getProductBySlug('kaos-variasi'))
          .thenAnswer((_) async => _product(price: 50000, stock: 20));
      when(() => cartRepository.addToCart(
            productId: any(named: 'productId'),
            variantId: any(named: 'variantId'),
          )).thenAnswer((_) async {});
      final notifier = container.read(productDetailProvider('kaos-variasi').notifier);
      await notifier.loadProduct();

      final error = await notifier.addToCart();

      expect(error, isNull);
      verify(() => cartRepository.addToCart(productId: 'prod-1', variantId: null)).called(1);
    });
  });
}
