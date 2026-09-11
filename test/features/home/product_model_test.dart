import 'package:flutter_test/flutter_test.dart';
import 'package:blukios_marketplace/features/home/models/product_model.dart';

void main() {
  group('ProductModel.fromJson', () {
    test('parses the shape the listing endpoints return', () {
      final p = ProductModel.fromJson({
        'id': '019f6bba-3992-71e3-a29a-348cd96e0452',
        'name': 'Celana Kulot',
        'slug': 'celana-kulot-234',
        'description': 'Deskripsi',
        'price': 150000,
        'stock': 7,
        'weight': 300.0,
        'condition': 'new',
        'thumbnail': 'https://example.test/a.png',
        'total_sold': 1,
        'store': {'id': 's1', 'name': 'Toko', 'username': 'toko', 'logo': null},
      });

      expect(p.id, '019f6bba-3992-71e3-a29a-348cd96e0452');
      expect(p.price, 150000);
      expect(p.stock, 7);
      expect(p.weight, 300.0);
      expect(p.totalSold, 1);
      expect(p.store?.logo, isNull);
      expect(p.reviews, isEmpty);
    });

    // /product/slug/{slug} used to send total_sold as a string because MySQL
    // SUM() comes back from PDO that way. The old parser cast it with
    // `as num` and threw, taking the product detail screen down. total_sold
    // is not a money-contract field, so it keeps its lenient string coercion.
    test('accepts a numeric string for total_sold', () {
      final p = ProductModel.fromJson({
        'id': 'x',
        'name': 'n',
        'slug': 's',
        'total_sold': '3',
        'price': 150000,
        'stock': '7',
      });

      expect(p.totalSold, 3);
      expect(p.price, 150000);
      expect(p.stock, 7);
    });

    test('falls back instead of throwing when non-money numeric fields are missing', () {
      final p = ProductModel.fromJson({'id': 'x', 'name': 'n', 'slug': 's', 'price': 0});

      expect(p.price, 0);
      expect(p.stock, 0);
      expect(p.weight, 0.0);
      expect(p.totalSold, 0);
      expect(p.condition, 'new');
      expect(p.thumbnail, isNull);
      expect(p.store, isNull);
    });

    test('tolerates explicit nulls on non-money fields and a null store', () {
      final p = ProductModel.fromJson({
        'id': 'x',
        'name': null,
        'slug': null,
        'description': null,
        'price': 0,
        'stock': null,
        'weight': null,
        'total_sold': null,
        'thumbnail': null,
        'store': null,
      });

      expect(p.name, '');
      expect(p.price, 0);
      expect(p.totalSold, 0);
      expect(p.description, isNull);
      expect(p.store, isNull);
    });

    test('keeps a store logo when the API supplies one', () {
      final p = ProductModel.fromJson({
        'id': 'x',
        'name': 'n',
        'slug': 's',
        'price': 150000,
        'store': {'id': 's1', 'name': 'Toko', 'logo': 'https://example.test/l.png'},
      });

      expect(p.store?.logo, 'https://example.test/l.png');
      expect(p.store?.username, isNull);
    });

    // Sprint C1 hardened the money-JSON contract (money-json-contract.md):
    // `price` is now always emitted as a JSON integer, and the backend
    // itself throws rather than emit a fractional/legacy value. The mobile
    // client mirrors that: a missing or non-integer `price` is a contract
    // violation and must surface loudly, never silently render as free
    // (Rp 0) or crash with a confusing NoSuchMethodError.
    test('throws instead of defaulting to 0 when price is missing', () {
      expect(
        () => ProductModel.fromJson({'id': 'x', 'name': 'n', 'slug': 's'}),
        throwsA(isA<FormatException>()),
      );
    });

    test('throws instead of defaulting to 0 when price is null', () {
      expect(
        () => ProductModel.fromJson({'id': 'x', 'name': 'n', 'slug': 's', 'price': null}),
        throwsA(isA<FormatException>()),
      );
    });

    test('throws on a legacy decimal-string price instead of truncating', () {
      expect(
        () => ProductModel.fromJson({'id': 'x', 'name': 'n', 'slug': 's', 'price': '150000.00'}),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('ProductVariantModel.fromJson', () {
    test('parses the JSON-integer price the C1 contract guarantees', () {
      final v = ProductVariantModel.fromJson({
        'id': 'variant-1',
        'name': 'Biru/L',
        'price': 150000,
        'stock': 5,
        'sku': 'KV-BIRU-L',
        'variant_attributes': {'Warna': 'Biru', 'Ukuran': 'L'},
      });

      expect(v.price, 150000);
      expect(v.stock, 5);
      expect(v.attributes, {'Warna': 'Biru', 'Ukuran': 'L'});
    });

    // Pre-C1, ProductVariantMongo::price cast 'decimal:2' leaked through as
    // a raw string ("150000.00") -- the mobile parser used to tolerate it.
    // Post-C1 the resource always normalizes to an integer, so a
    // decimal-string here means the contract regressed and must be
    // surfaced, not silently re-truncated.
    test('throws on the pre-C1 decimal-string price instead of tolerating it', () {
      expect(
        () => ProductVariantModel.fromJson({
          'id': 'variant-1',
          'name': 'Biru/L',
          'price': '150000.00',
          'stock': '5',
        }),
        throwsA(isA<FormatException>()),
      );
    });

    test('throws when price is missing', () {
      expect(
        () => ProductVariantModel.fromJson({'id': 'variant-1', 'name': 'Biru/L', 'stock': 5}),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
