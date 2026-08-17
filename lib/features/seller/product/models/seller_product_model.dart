import 'package:blukios_marketplace/core/utils/json.dart';

/// Product as seen by its own seller — includes fields the public
/// [ProductModel] (home feature) doesn't need, like every product image
/// (not just the thumbnail) and the raw category id for the edit form.
class SellerProductModel {
  final String id;
  final String name;
  final String slug;
  final String description;
  final String condition; // 'new' | 'second'
  final double price;
  final double weight;
  final int stock;
  final int totalSold;
  final String? categoryId;
  final String? categoryName;
  final List<SellerProductImageModel> images;

  /// Whether this product's actual sellable units are its [variants]
  /// rather than the top-level [price]/[stock]. The API (`ProductRepository`
  /// on the Laravel side) recomputes [price] (min of variant prices) and
  /// [stock] (sum of variant stocks) whenever variants are present, so those
  /// two fields stay populated either way — they just become derived values
  /// once variants exist instead of the seller-entered source of truth.
  final bool hasVariants;
  final List<SellerProductVariantModel> variants;

  SellerProductModel({
    required this.id,
    required this.name,
    required this.slug,
    required this.description,
    required this.condition,
    required this.price,
    required this.weight,
    required this.stock,
    required this.totalSold,
    this.categoryId,
    this.categoryName,
    this.images = const [],
    this.hasVariants = false,
    this.variants = const [],
  });

  String? get thumbnailUrl {
    final thumb = images.where((i) => i.isThumbnail);
    if (thumb.isNotEmpty) return thumb.first.url;
    return images.isNotEmpty ? images.first.url : null;
  }

  factory SellerProductModel.fromJson(Map<String, dynamic> json) {
    final category = json['product_category'];
    return SellerProductModel(
      id: json.asString('id'),
      name: json.asString('name'),
      slug: json.asString('slug'),
      description: json.asString('description'),
      condition: json.asString('condition', 'new'),
      price: json.asDouble('price'),
      weight: json.asDouble('weight'),
      stock: json.asInt('stock'),
      totalSold: json.asInt('total_sold'),
      categoryId: category is Map<String, dynamic>
          ? category.asStringOrNull('id')
          : null,
      categoryName:
          category is Map<String, dynamic> ? category.asString('name') : null,
      images: json['product_images'] is List
          ? (json['product_images'] as List)
              .whereType<Map<String, dynamic>>()
              .map(SellerProductImageModel.fromJson)
              .toList()
          : const [],
      hasVariants: json.asBool('has_variants'),
      variants: json['variants'] is List
          ? (json['variants'] as List)
              .whereType<Map<String, dynamic>>()
              .map(SellerProductVariantModel.fromJson)
              .toList()
          : const [],
    );
  }
}

class SellerProductImageModel {
  final String id;
  final String url;
  final bool isThumbnail;

  SellerProductImageModel({
    required this.id,
    required this.url,
    required this.isThumbnail,
  });

  factory SellerProductImageModel.fromJson(Map<String, dynamic> json) {
    return SellerProductImageModel(
      id: json.asString('id'),
      url: json.asString('image'),
      isThumbnail: json.asBool('is_thumbnail'),
    );
  }
}

/// A single sellable variant of a product (e.g. "Red / L"). [id] is null
/// for a variant the seller just added in this form session and hasn't
/// been persisted yet — the update endpoint creates a new variant when no
/// id is sent, and updates the matching one when it is.
class SellerProductVariantModel {
  final String? id;
  final String name;
  final double price;
  final int stock;
  final String? sku;

  /// Arbitrary key-value pairs, e.g. {"Warna": "Merah", "Ukuran": "L"}.
  final Map<String, String> variantAttributes;

  const SellerProductVariantModel({
    this.id,
    required this.name,
    required this.price,
    required this.stock,
    this.sku,
    this.variantAttributes = const {},
  });

  factory SellerProductVariantModel.fromJson(Map<String, dynamic> json) {
    final attrs = json['variant_attributes'];
    return SellerProductVariantModel(
      id: json.asStringOrNull('id'),
      name: json.asString('name'),
      price: json.asDouble('price'),
      stock: json.asInt('stock'),
      sku: json.asStringOrNull('sku'),
      variantAttributes: attrs is Map
          ? attrs.map((k, v) => MapEntry(k.toString(), v.toString()))
          : const {},
    );
  }

  SellerProductVariantModel copyWith({
    String? id,
    bool clearId = false,
    String? name,
    double? price,
    int? stock,
    String? sku,
    Map<String, String>? variantAttributes,
  }) {
    return SellerProductVariantModel(
      id: clearId ? null : (id ?? this.id),
      name: name ?? this.name,
      price: price ?? this.price,
      stock: stock ?? this.stock,
      sku: sku ?? this.sku,
      variantAttributes: variantAttributes ?? this.variantAttributes,
    );
  }
}
