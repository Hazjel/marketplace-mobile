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
  });

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    return ProductModel(
      id: json['id'].toString(),
      name: json['name'] ?? '',
      slug: json['slug'] ?? '',
      description: json['description'],
      price: (json['price'] ?? 0) is int ? json['price'] : (json['price'] as num).toInt(),
      stock: (json['stock'] ?? 0) is int ? json['stock'] : (json['stock'] as num).toInt(),
      weight: (json['weight'] ?? 0).toDouble(),
      condition: json['condition'] ?? 'new',
      thumbnail: json['thumbnail'],
      totalSold: (json['total_sold'] ?? 0) is int ? json['total_sold'] ?? 0 : (json['total_sold'] as num).toInt(),
      store: json['store'] != null ? StoreMini.fromJson(json['store']) : null,
    );
  }
}

class StoreMini {
  final String id;
  final String name;
  final String? logo;

  StoreMini({required this.id, required this.name, this.logo});

  factory StoreMini.fromJson(Map<String, dynamic> json) {
    return StoreMini(
      id: json['id'].toString(),
      name: json['name'] ?? '',
      logo: json['logo'],
    );
  }
}
