import 'package:blukios_marketplace/core/utils/json.dart';
import 'package:blukios_marketplace/features/review/models/review_model.dart';

class ProductModel {
  final String id;
  final String name;
  final String slug;
  final String? description;

  /// Untuk produk bervarian, ini AGREGAT (varian termurah/total stok
  /// lintas varian -- lihat ProductRepository::create() di backend), BUKAN
  /// harga/stok baris yang sesungguhnya dibeli. Pakai [variants] untuk
  /// harga/stok varian spesifik.
  final int price;
  final int stock;
  final double weight;
  final String condition;
  final String? thumbnail;
  final int totalSold;
  final StoreMini? store;

  final bool hasVariants;

  /// Cuma terisi pada endpoint detail (has_variants=true) -- list endpoint
  /// tidak mengirim ini sama sekali.
  final List<ProductVariantModel> variants;

  /// Only present on the detail endpoints (`/product/{id}` and
  /// `/product/slug/{slug}`) — the API uses `whenLoaded`, so on list
  /// responses the key is absent entirely, not null.
  final List<ReviewModel> reviews;

  ProductModel({
    required this.id,
    required this.name,
    required this.slug,
    this.description,
    required this.price,
    required this.stock,
    required this.weight,
    required this.condition,
    this.thumbnail,
    required this.totalSold,
    this.store,
    this.hasVariants = false,
    this.variants = const [],
    this.reviews = const [],
  });

  double? get averageRating {
    if (reviews.isEmpty) return null;
    final total = reviews.fold<int>(0, (sum, r) => sum + r.rating);
    return total / reviews.length;
  }

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    return ProductModel(
      id: json.asString('id'),
      name: json.asString('name'),
      slug: json.asString('slug'),
      description: json.asStringOrNull('description'),
      price: json.asInt('price'),
      stock: json.asInt('stock'),
      weight: json.asDouble('weight'),
      condition: json.asString('condition', 'new'),
      thumbnail: json.asStringOrNull('thumbnail'),
      totalSold: json.asInt('total_sold'),
      store: json['store'] is Map<String, dynamic>
          ? StoreMini.fromJson(json['store'] as Map<String, dynamic>)
          : null,
      hasVariants: json['has_variants'] == true,
      variants: json['variants'] is List
          ? (json['variants'] as List)
              .whereType<Map<String, dynamic>>()
              .map(ProductVariantModel.fromJson)
              .toList()
          : const [],
      reviews: json['product_reviews'] is List
          ? (json['product_reviews'] as List)
              .whereType<Map<String, dynamic>>()
              .map(ReviewModel.fromJson)
              .toList()
          : const [],
    );
  }
}

class ProductVariantModel {
  final String id;
  final String name;
  final int price;
  final int stock;
  final String? sku;
  final String? image;

  /// Mis. {"Warna": "Merah", "Ukuran": "S"} -- dipakai untuk label
  /// pemilihan varian di UI.
  final Map<String, String> attributes;

  ProductVariantModel({
    required this.id,
    required this.name,
    required this.price,
    required this.stock,
    this.sku,
    this.image,
    this.attributes = const {},
  });

  factory ProductVariantModel.fromJson(Map<String, dynamic> json) {
    final rawAttributes = json['variant_attributes'];
    return ProductVariantModel(
      id: json.asString('id'),
      name: json.asString('name'),
      price: json.asInt('price'),
      stock: json.asInt('stock'),
      sku: json.asStringOrNull('sku'),
      image: json.asStringOrNull('image'),
      attributes: rawAttributes is Map
          ? rawAttributes.map((k, v) => MapEntry(k.toString(), v.toString()))
          : const {},
    );
  }
}

class StoreMini {
  final String id;
  final String name;
  final String? username;
  final String? logo;

  StoreMini({
    required this.id,
    required this.name,
    this.username,
    this.logo,
  });

  factory StoreMini.fromJson(Map<String, dynamic> json) {
    return StoreMini(
      id: json.asString('id'),
      name: json.asString('name'),
      username: json.asStringOrNull('username'),
      logo: json.asStringOrNull('logo'),
    );
  }
}
