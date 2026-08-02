import 'package:blukios_marketplace/core/utils/json.dart';

/// Full category model for the browse feature.
///
/// Extends what `home/models/category_model.dart` covers — that one is
/// kept as-is for the home screen's category strip so it isn't touched by
/// unrelated feature work. `childrens` (not `children`) matches the API's
/// actual field spelling; `whenLoaded` means it's absent unless the
/// endpoint eager-loads subcategories.
class CategoryDetailModel {
  final String id;
  final String? parentId;
  final String? image;
  final String name;
  final String slug;
  final String? tagline;
  final String? description;
  final int productCount;
  final int childrenCount;
  final List<CategoryDetailModel>? children;

  CategoryDetailModel({
    required this.id,
    this.parentId,
    this.image,
    required this.name,
    required this.slug,
    this.tagline,
    this.description,
    required this.productCount,
    required this.childrenCount,
    this.children,
  });

  bool get hasChildren => childrenCount > 0;

  factory CategoryDetailModel.fromJson(Map<String, dynamic> json) {
    final rawChildren = json['childrens'];
    return CategoryDetailModel(
      id: json.asString('id'),
      parentId: json['parent_id']?.toString(),
      image: json['image'],
      name: json.asString('name'),
      slug: json.asString('slug'),
      tagline: json['tagline'],
      description: json['description'],
      productCount: json.asInt('product_count'),
      childrenCount: json.asInt('children_count'),
      children: rawChildren is List
          ? rawChildren
              .whereType<Map<String, dynamic>>()
              .map(CategoryDetailModel.fromJson)
              .toList()
          : null,
    );
  }
}
