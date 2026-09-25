import 'package:flutter_test/flutter_test.dart';
import 'package:blukios_marketplace/features/ai_chat/models/ai_chat_models.dart';

void main() {
  group('AiChatReply.fromJson', () {
    test('membaca balasan lengkap beserta produk', () {
      final reply = AiChatReply.fromJson({
        'reply': 'Ini beberapa sepatu lari.',
        'status': 'success',
        'session_id': 'sess-1',
        'products': [
          {
            'id': 7,
            'slug': 'sepatu-lari',
            'name': 'Sepatu Lari',
            'price': 250000,
            'thumbnail': 'https://contoh/thumb.jpg',
            'store': 'Toko Olahraga',
            'category': 'Sepatu',
          },
        ],
      });

      expect(reply.reply, 'Ini beberapa sepatu lari.');
      expect(reply.sessionId, 'sess-1');
      expect(reply.isError, isFalse);
      expect(reply.products.single.id, '7');
      expect(reply.products.single.price, 250000);
      expect(reply.products.single.storeName, 'Toko Olahraga');
    });

    test('status error ditandai tanpa membuang teks balasannya', () {
      // chat-service membalas 200 + status error saat LLM-nya gagal, dan teks
      // permintaan maafnya tetap yang ditampilkan ke pengguna.
      final reply = AiChatReply.fromJson({
        'reply': 'Duh, Ri lagi pusing nih.',
        'status': 'error',
        'session_id': 'sess-2',
      });

      expect(reply.isError, isTrue);
      expect(reply.reply, 'Duh, Ri lagi pusing nih.');
      expect(reply.products, isEmpty);
    });

    test('products null atau bentuk lain tidak melempar', () {
      expect(
        AiChatReply.fromJson({
          'reply': 'oke',
          'status': 'success',
          'session_id': 's',
          'products': null,
        }).products,
        isEmpty,
      );
      expect(
        AiChatReply.fromJson({
          'reply': 'oke',
          'status': 'success',
          'session_id': 's',
          'products': 'bukan list',
        }).products,
        isEmpty,
      );
    });
  });

  group('AiChatProduct', () {
    test('price mengikuti kontrak rupiah bulat (int, bukan double/string)',
        () {
      final product = AiChatProduct.fromJson({
        'id': '1',
        'slug': 'contoh-produk',
        'name': 'Contoh',
        'price': 100000,
      });

      expect(product.price, 100000);
    });

    test('price bertipe string melanggar kontrak dan melempar', () {
      expect(
        () => AiChatProduct.fromJson({
          'id': '1',
          'slug': 'contoh-produk',
          'name': 'Contoh',
          'price': '100000',
        }),
        throwsFormatException,
      );
    });

    test('routeKey jatuh ke id kalau slug kosong', () {
      final product = AiChatProduct.fromJson({
        'id': '42',
        'slug': '',
        'name': 'Tanpa Slug',
        'price': 1000,
      });

      expect(product.routeKey, '42');
    });

    test('field teks yang kosong dibaca sebagai null', () {
      final product = AiChatProduct.fromJson({
        'id': '1',
        'slug': 'x',
        'name': 'X',
        'price': 0,
        'thumbnail': '',
        'store': '',
        'category': '',
      });

      expect(product.thumbnail, isNull);
      expect(product.storeName, isNull);
      expect(product.categoryName, isNull);
    });
  });
}
