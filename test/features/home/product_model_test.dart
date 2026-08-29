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
    // `as num` and threw, taking the product detail screen down.
    test('accepts a numeric string for total_sold', () {
      final p = ProductModel.fromJson({
        'id': 'x',
        'name': 'n',
        'slug': 's',
        'total_sold': '3',
        'price': '150000',
        'stock': '7',
      });

      expect(p.totalSold, 3);
      expect(p.price, 150000);
      expect(p.stock, 7);
    });

    test('falls back instead of throwing when numeric fields are missing', () {
      final p = ProductModel.fromJson({'id': 'x', 'name': 'n', 'slug': 's'});

      expect(p.price, 0);
      expect(p.stock, 0);
      expect(p.weight, 0.0);
      expect(p.totalSold, 0);
      expect(p.condition, 'new');
      expect(p.thumbnail, isNull);
      expect(p.store, isNull);
    });

    test('tolerates explicit nulls and a null store', () {
      final p = ProductModel.fromJson({
        'id': 'x',
        'name': null,
        'slug': null,
        'description': null,
        'price': null,
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
        'store': {'id': 's1', 'name': 'Toko', 'logo': 'https://example.test/l.png'},
      });

      expect(p.store?.logo, 'https://example.test/l.png');
      expect(p.store?.username, isNull);
    });
  });

  group('ProductVariantModel.fromJson', () {
    // Kontrak nyata ProductVariantResource: ProductVariantMongo::price cast
    // 'decimal:2', jadi payload varian JSON-nya "150000.00" (string) sebelum
    // dinormalisasi -- fixture di sini pakai bentuk itu persis, bukan angka
    // literal, supaya test ini benar-benar menutup gap yang int.tryParse()
    // tidak tangani.
    test('parses price/stock from the real decimal-string API contract', () {
      final v = ProductVariantModel.fromJson({
        'id': 'variant-1',
        'name': 'Biru/L',
        'price': '150000.00',
        'stock': '5',
        'sku': 'KV-BIRU-L',
        'variant_attributes': {'Warna': 'Biru', 'Ukuran': 'L'},
      });

      expect(v.price, 150000);
      expect(v.stock, 5);
      expect(v.attributes, {'Warna': 'Biru', 'Ukuran': 'L'});
    });

    test('also accepts numeric (already-normalized) price/stock', () {
      final v = ProductVariantModel.fromJson({
        'id': 'variant-1',
        'name': 'Biru/L',
        'price': 150000,
        'stock': 5,
      });

      expect(v.price, 150000);
      expect(v.stock, 5);
    });
  });
}
