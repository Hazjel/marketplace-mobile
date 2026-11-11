import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:blukios_marketplace/core/network/api_exceptions.dart';
import 'package:blukios_marketplace/core/providers.dart';
import 'package:blukios_marketplace/features/seller/product/data/seller_product_repository.dart';
import 'package:blukios_marketplace/features/seller/product/models/seller_product_form_models.dart';
import 'package:blukios_marketplace/features/seller/product/viewmodels/seller_product_form_viewmodel.dart';

class MockSellerProductRepository extends Mock implements SellerProductRepository {}

const _payload = SellerProductPayload(
  storeId: 's1',
  categoryId: 'c1',
  name: 'Kaos',
  description: 'Kaos katun',
  condition: 'new',
  price: 50000,
  weight: 200,
  stock: 3,
);

void main() {
  late MockSellerProductRepository repository;
  late ProviderContainer container;

  setUpAll(() => registerFallbackValue(_payload));

  setUp(() {
    repository = MockSellerProductRepository();
    container = ProviderContainer(
      overrides: [sellerProductRepositoryProvider.overrideWithValue(repository)],
    );
    // Keep the auto-dispose notifier alive for the whole test.
    container.listen(sellerProductFormProvider, (_, __) {});
  });

  tearDown(() => container.dispose());

  SellerProductFormNotifier notifier() => container.read(sellerProductFormProvider.notifier);
  String? error() => container.read(sellerProductFormProvider).errorMessage;

  // `ProductUpdateRequest` (bb7f0bf) puts the variant ownership failure in
  // `errors`; the top-level message is the generic one.
  final unknownVariant = ValidationException.fromBody(const {
    'success': false,
    'message': 'Validasi gagal',
    'errors': {
      'variants.0.id': ['Varian tidak ditemukan pada produk ini.'],
    },
  });

  test('update shows the variant validation error, not "Validasi gagal"', () async {
    when(() => repository.updateProduct('p1', any())).thenThrow(unknownVariant);

    expect(await notifier().submitUpdate('p1', _payload), isNull);
    expect(error(), 'Varian tidak ditemukan pada produk ini.');
    expect(container.read(sellerProductFormProvider).isSaving, isFalse);
  });

  test('create shows the first validation error', () async {
    when(() => repository.createProduct(any())).thenThrow(unknownVariant);

    expect(await notifier().submitCreate(_payload), isNull);
    expect(error(), 'Varian tidak ditemukan pada produk ini.');
  });

  test('a 403 shows the server message', () async {
    when(() => repository.updateProduct('p1', any())).thenThrow(
      ApiException(message: 'Tidak diizinkan mengubah produk toko lain', statusCode: 403),
    );

    expect(await notifier().submitUpdate('p1', _payload), isNull);
    expect(error(), 'Tidak diizinkan mengubah produk toko lain');
  });
}
