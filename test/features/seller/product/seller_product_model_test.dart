import 'package:flutter_test/flutter_test.dart';
import 'package:blukios_marketplace/features/seller/product/models/seller_product_model.dart';

Map<String, dynamic> _fixture({Object? price = 150000}) => {
      'id': 'p1',
      'name': 'Produk',
      'slug': 'produk',
      'description': 'd',
      'condition': 'new',
      'price': price,
      'weight': 2.2,
      'stock': 10,
    };

void main() {
  group('SellerProductModel.fromJson', () {
    test('parses the C1 integer money contract for price', () {
      final p = SellerProductModel.fromJson(_fixture());
      expect(p.price, 150000.0);
    });

    // A silent fallback to 0 here would zero out a real listing's price
    // the moment the seller opens the edit form -- must throw instead.
    test('throws instead of defaulting to 0 when price is missing', () {
      final json = _fixture()..remove('price');
      expect(() => SellerProductModel.fromJson(json), throwsA(isA<FormatException>()));
    });

    test('throws on a legacy decimal-string price instead of truncating', () {
      expect(
        () => SellerProductModel.fromJson(_fixture(price: '150000.00')),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('SellerProductVariantModel.fromJson', () {
    test('parses the C1 integer money contract for variant price', () {
      final v = SellerProductVariantModel.fromJson({
        'id': 'v1',
        'name': 'Merah/L',
        'price': 175000,
        'stock': 5,
      });
      expect(v.price, 175000.0);
    });

    test('throws instead of defaulting to 0 when variant price is missing', () {
      expect(
        () => SellerProductVariantModel.fromJson({'id': 'v1', 'name': 'Merah/L', 'stock': 5}),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
