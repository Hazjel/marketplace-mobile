class CartItemModel {
  final String id;
  final String productId;
  final String? variantId;
  final int quantity;
  final String? note;
  final String productName;
  final String? productThumbnail;
  final double price;
  final int stock;
  final double weight;

  CartItemModel({
    required this.id,
    required this.productId,
    this.variantId,
    required this.quantity,
    this.note,
    required this.productName,
    this.productThumbnail,
    required this.price,
    required this.stock,
    required this.weight,
  });

  factory CartItemModel.fromJson(Map<String, dynamic> json) {
    final product = json['product'] ?? {};
    return CartItemModel(
      id: json['id'].toString(),
      productId: (json['product_id'] ?? product['id'] ?? '').toString(),
      variantId: json['variant_id']?.toString(),
      quantity: (json['quantity'] ?? 1) is int ? json['quantity'] ?? 1 : (json['quantity'] as num).toInt(),
      note: json['note'],
      productName: product['name'] ?? '',
      productThumbnail: product['thumbnail'],
      price: (product['price'] ?? 0).toDouble(),
      stock: (product['stock'] ?? 0) is int ? product['stock'] ?? 0 : (product['stock'] as num).toInt(),
      weight: (product['weight'] ?? 0).toDouble(),
    );
  }

  double get subtotal => price * quantity;
}

class CartGroupModel {
  final String storeId;
  final String storeName;
  final String? storeLogo;
  final String? storeAddressId;
  final List<CartItemModel> items;

  CartGroupModel({
    required this.storeId,
    required this.storeName,
    this.storeLogo,
    this.storeAddressId,
    required this.items,
  });

  factory CartGroupModel.fromJson(Map<String, dynamic> json) {
    final List rawItems = json['items'] ?? [];
    return CartGroupModel(
      storeId: (json['store_id'] ?? '').toString(),
      storeName: json['store_name'] ?? '-',
      storeLogo: json['store_logo'],
      storeAddressId: json['store_address_id']?.toString(),
      items: rawItems.map((e) => CartItemModel.fromJson(e)).toList(),
    );
  }

  double get subtotal => items.fold(0, (sum, item) => sum + item.subtotal);
  double get totalWeight => items.fold(0, (sum, item) => sum + (item.weight * item.quantity));
  int get itemCount => items.length;
}
