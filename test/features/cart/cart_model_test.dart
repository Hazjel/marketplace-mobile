import 'package:flutter_test/flutter_test.dart';
import 'package:blukios_marketplace/features/cart/models/cart_model.dart';

// product['price']/['stock'] adalah agregat (harga varian TERMURAH, total
// stok lintas varian -- lihat ProductRepository::create() di backend), BUKAN
// harga/stok baris yang sesungguhnya dibeli. Bug aslinya: CartItemModel
// selalu memakai field itu langsung, jadi cart varian mahal ikut
// menampilkan harga varian termurah setiap kali di-refresh dari server.
void main() {
  group('CartItemModel.fromJson — variant price/stock resolution', () {
    Map<String, dynamic> serverItem({String? variantId, Object? variantPrice = 150000}) => {
          'id': 'cart-item-1',
          'product_id': 'product-1',
          'variant_id': variantId,
          'quantity': 2,
          'note': null,
          'product': {
            'name': 'Kaos Variasi',
            'price': 100000, // agregat -- harga varian TERMURAH
            'stock': 15,
            'weight': 200,
            'variants': [
              {'id': 'variant-murah', 'name': 'Merah/S', 'price': 100000, 'stock': 10},
              {'id': 'variant-mahal', 'name': 'Biru/L', 'price': variantPrice, 'stock': 5},
            ],
          },
        };

    test('uses the purchased variant price/stock, not the cheapest-variant aggregate', () {
      final item = CartItemModel.fromJson(serverItem(variantId: 'variant-mahal'));

      expect(item.price, 150000);
      expect(item.stock, 5);
      expect(item.variantId, 'variant-mahal');
    });

    test('falls back to product.price/stock for a non-variant item', () {
      final json = {
        'id': 'cart-item-2',
        'product_id': 'product-2',
        'variant_id': null,
        'quantity': 1,
        'note': null,
        'product': {
          'name': 'Produk Tanpa Varian',
          'price': 20000,
          'stock': 5,
          'weight': 100,
          'variants': [],
        },
      };

      final item = CartItemModel.fromJson(json);

      expect(item.price, 20000);
      expect(item.stock, 5);
      expect(item.variantId, isNull);
    });

    test('falls back to the aggregate when variant_id points at a variant absent from the payload', () {
      final item = CartItemModel.fromJson(serverItem(variantId: 'variant-yang-hilang'));

      expect(item.price, 100000);
      expect(item.stock, 15);
      expect(item.variantId, 'variant-yang-hilang');
    });

    // Sprint C1: cart's `product` is a serialized ProductResource, and a
    // resolved variant a serialized ProductVariantResource -- both
    // C1-contracted, so their `price` is a JSON integer, never a decimal
    // string or float, regardless of cart being display-only.
    test('throws on a variant decimal-string price instead of tolerating it', () {
      expect(
        () => CartItemModel.fromJson(
          serverItem(variantId: 'variant-mahal', variantPrice: '150000.00'),
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('throws on a variant whole-valued double price instead of coercing it', () {
      expect(
        () => CartItemModel.fromJson(
          serverItem(variantId: 'variant-mahal', variantPrice: 150000.0),
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('throws on a product decimal-string price instead of tolerating it', () {
      final json = {
        'id': 'cart-item-2',
        'product_id': 'product-2',
        'variant_id': null,
        'quantity': 1,
        'note': null,
        'product': {
          'name': 'Produk Tanpa Varian',
          'price': '20000.00',
          'stock': 5,
          'weight': 100,
          'variants': [],
        },
      };

      expect(() => CartItemModel.fromJson(json), throwsA(isA<FormatException>()));
    });

    test('throws on a product whole-valued double price instead of coercing it', () {
      final json = {
        'id': 'cart-item-2',
        'product_id': 'product-2',
        'variant_id': null,
        'quantity': 1,
        'note': null,
        'product': {
          'name': 'Produk Tanpa Varian',
          'price': 20000.0,
          'stock': 5,
          'weight': 100,
          'variants': [],
        },
      };

      expect(() => CartItemModel.fromJson(json), throwsA(isA<FormatException>()));
    });

    test('throws instead of defaulting to 0 when the selected price is missing', () {
      final json = {
        'id': 'cart-item-2',
        'product_id': 'product-2',
        'variant_id': null,
        'quantity': 1,
        'note': null,
        'product': {
          'name': 'Produk Tanpa Varian',
          'stock': 5,
          'weight': 100,
          'variants': [],
        },
      };

      expect(() => CartItemModel.fromJson(json), throwsA(isA<FormatException>()));
    });
  });
}
