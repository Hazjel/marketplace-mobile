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
