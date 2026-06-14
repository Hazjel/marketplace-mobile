class CartModel {
  final String id;
  final String productId;
  final String productName;
  final String? productThumbnail;
  final int price;
  final int quantity;
  final int stock;
  final String? storeName;

  CartModel({
    required this.id,
    required this.productId,
    required this.productName,
    this.productThumbnail,
    required this.price,
    required this.quantity,
    required this.stock,
    this.storeName,
  });

  factory CartModel.fromJson(Map<String, dynamic> json) {
    final product = json['product'] ?? {};
    return CartModel(
      id: json['id'].toString(),
      productId: (json['product_id'] ?? product['id'] ?? '').toString(),
      productName: product['name'] ?? '',
      productThumbnail: product['thumbnail'],
      price: (product['price'] ?? 0) is int ? product['price'] ?? 0 : (product['price'] as num).toInt(),
      quantity: (json['quantity'] ?? 1) is int ? json['quantity'] ?? 1 : (json['quantity'] as num).toInt(),
      stock: (product['stock'] ?? 0) is int ? product['stock'] ?? 0 : (product['stock'] as num).toInt(),
      storeName: product['store']?['name'],
    );
  }

  int get subtotal => price * quantity;
}
