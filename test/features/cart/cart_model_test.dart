import 'package:flutter_test/flutter_test.dart';
import 'package:blukios_marketplace/features/cart/models/cart_model.dart';

// product['price']/['stock'] adalah agregat (harga varian TERMURAH, total
// stok lintas varian -- lihat ProductRepository::create() di backend), BUKAN
// harga/stok baris yang sesungguhnya dibeli. Bug aslinya: CartItemModel
// selalu memakai field itu langsung, jadi cart varian mahal ikut
// menampilkan harga varian termurah setiap kali di-refresh dari server.
void main() {
  group('CartItemModel.fromJson — variant price/stock resolution', () {
    Map<String, dynamic> serverItem({String? variantId}) => {
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
              {'id': 'variant-mahal', 'name': 'Biru/L', 'price': 150000, 'stock': 5},
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

    // Kontrak nyata ProductVariantResource: ProductVariantMongo::price cast
    // 'decimal:2' -> payload "150000.00" (string). Sebelumnya baris ini
    // memakai .toDouble() langsung, yang CRASH (NoSuchMethodError) untuk
    // String, bukan cuma salah nilai -- fixture ini pakai bentuk API asli,
    // bukan angka literal, supaya menutup gap itu.
    test('parses a variant price/stock sent as the real decimal-string API contract', () {
      final json = {
        'id': 'cart-item-3',
        'product_id': 'product-1',
        'variant_id': 'variant-mahal',
        'quantity': 1,
        'note': null,
        'product': {
          'name': 'Kaos Variasi',
          'price': '100000.00',
          'stock': 15,
          'weight': 200,
          'variants': [
            {'id': 'variant-mahal', 'name': 'Biru/L', 'price': '150000.00', 'stock': '5'},
          ],
        },
      };

      final item = CartItemModel.fromJson(json);

      expect(item.price, 150000.0);
      expect(item.stock, 5);
    });
  });
}
