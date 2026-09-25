import 'package:blukios_marketplace/core/utils/json.dart';

/// Produk relevan yang dikembalikan RAG bersama jawaban bot. `price` lewat
/// [moneyInt] seperti model lain: kontrak C1 mewajibkan rupiah bulat, dan JSON
/// bisa mengirimnya sebagai int, string, atau double.
class AiChatProduct {
  final String id;
  final String slug;
  final String name;
  final int price;
  final String? thumbnail;
  final String? storeName;
  final String? categoryName;

  const AiChatProduct({
    required this.id,
    required this.slug,
    required this.name,
    required this.price,
    this.thumbnail,
    this.storeName,
    this.categoryName,
  });

  /// Rute detail produk memakai slug. Kalau RAG tidak mengirim slug, id
  /// dipakai sebagai gantinya supaya kartunya tetap bisa dibuka.
  String get routeKey => slug.isNotEmpty ? slug : id;

  factory AiChatProduct.fromJson(Map<String, dynamic> json) {
    return AiChatProduct(
      id: json['id']?.toString() ?? '',
      slug: json['slug']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      price: json.moneyInt('price'),
      thumbnail: _emptyToNull(json['thumbnail']),
      storeName: _emptyToNull(json['store']),
      categoryName: _emptyToNull(json['category']),
    );
  }

  static String? _emptyToNull(dynamic value) {
    final text = value?.toString() ?? '';
    return text.isEmpty ? null : text;
  }
}

/// Balasan satu putaran percakapan dari `POST /predict`.
class AiChatReply {
  final String reply;
  final String status;
  final String sessionId;
  final List<AiChatProduct> products;

  const AiChatReply({
    required this.reply,
    required this.status,
    required this.sessionId,
    this.products = const [],
  });

  /// chat-service membalas 200 dengan `status: "error"` saat LLM-nya gagal,
  /// dan `reply` berisi pesan minta maaf yang tetap layak ditampilkan. Jadi
  /// ini bukan kegagalan HTTP, tapi tetap perlu ditandai di UI.
  bool get isError => status == 'error';

  factory AiChatReply.fromJson(Map<String, dynamic> json) {
    final rawProducts = json['products'];
    return AiChatReply(
      reply: json['reply']?.toString() ?? '',
      status: json['status']?.toString() ?? 'success',
      sessionId: json['session_id']?.toString() ?? '',
      products: rawProducts is List
          ? rawProducts
              .whereType<Map<String, dynamic>>()
              .map(AiChatProduct.fromJson)
              .toList()
          : const [],
    );
  }
}

/// Satu bubble di layar. Pesan pengguna tidak punya produk.
class AiChatMessage {
  final String text;
  final bool isBot;
  final bool isError;
  final List<AiChatProduct> products;

  const AiChatMessage({
    required this.text,
    required this.isBot,
    this.isError = false,
    this.products = const [],
  });

  factory AiChatMessage.user(String text) =>
      AiChatMessage(text: text, isBot: false);

  factory AiChatMessage.bot(AiChatReply reply) => AiChatMessage(
        text: reply.reply,
        isBot: true,
        isError: reply.isError,
        products: reply.products,
      );
}
