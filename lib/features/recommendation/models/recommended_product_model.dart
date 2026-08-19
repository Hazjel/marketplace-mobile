import 'package:blukios_marketplace/core/utils/json.dart';

/// A single item returned by the recommendation service
/// (`/recommend/product/{id}/similar` and `/recommend/user/{id}`).
///
/// Deliberately not [ProductModel] — this payload is leaner (no
/// `description`, `weight`, `store`) and uses a flat `category` string
/// instead of a nested category object, so it doesn't fit that model.
class RecommendedProductModel {
  final String id;
  final String slug;
  final String name;
  final double price;
  final String? thumbnail;
  final String condition;
  final int stock;
  final int totalSold;
  final double rating;
  final String categoryId;
  final String category;

  /// Only present on collaborative-source items from `/user/{id}` — omit
  /// or treat as absent otherwise, never rely on its presence.
  final double? score;

  RecommendedProductModel({
    required this.id,
    required this.slug,
    required this.name,
    required this.price,
    this.thumbnail,
    required this.condition,
    required this.stock,
    required this.totalSold,
    required this.rating,
    required this.categoryId,
    required this.category,
    this.score,
  });

  factory RecommendedProductModel.fromJson(Map<String, dynamic> json) {
    final rawScore = json['_score'];
    return RecommendedProductModel(
      id: json.asString('id'),
      slug: json.asString('slug'),
      name: json.asString('name'),
      price: json.asDouble('price'),
      thumbnail: json.asStringOrNull('thumbnail'),
      condition: json.asString('condition'),
      stock: json.asInt('stock'),
      totalSold: json.asInt('total_sold'),
      rating: json.asDouble('rating'),
      categoryId: json.asString('category_id'),
      category: json.asString('category'),
      score: rawScore is num ? rawScore.toDouble() : null,
    );
  }
}
