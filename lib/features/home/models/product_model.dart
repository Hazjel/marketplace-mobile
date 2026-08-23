import 'package:blukios_marketplace/core/utils/json.dart';
import 'package:blukios_marketplace/features/review/models/review_model.dart';

class ProductModel {
  final String id;
  final String name;
  final String slug;
  final String? description;
  final int price;
  final int stock;
  final double weight;
  final String condition;
  final String? thumbnail;
  final int totalSold;
  final StoreMini? store;

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
      reviews: json['product_reviews'] is List
          ? (json['product_reviews'] as List)
              .whereType<Map<String, dynamic>>()
              .map(ReviewModel.fromJson)
              .toList()
          : const [],
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
