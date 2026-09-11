import 'package:blukios_marketplace/core/utils/json.dart';

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
    final product = (json['product'] ?? {}) as Map<String, dynamic>;
    final variantId = json['variant_id']?.toString();

    // product['price']/['stock'] agregat (varian termurah/total stok) --
    // sama seperti bug Vue's _applyServerCart(), harus resolve ke varian
    // yang SEBENARNYA dibeli lewat product['variants'], bukan pakai
    // agregat langsung.
    Map<String, dynamic>? variant;
    if (variantId != null && product['variants'] is List) {
      for (final v in (product['variants'] as List)) {
        if (v is Map<String, dynamic> && v['id']?.toString() == variantId) {
          variant = v;
          break;
        }
      }
    }

    // `product` is a serialized `ProductResource`, and a resolved `variant`
    // a serialized `ProductVariantResource` -- both C1-contracted, so their
    // `price` is always a JSON integer regardless of cart's own
    // display-only/non-authoritative status. moneyInt() throws instead of
    // silently accepting a legacy decimal-string or float, or defaulting a
    // missing price to 0.
    final priceSource = variant ?? product;

    return CartItemModel(
      id: json['id'].toString(),
      productId: (json['product_id'] ?? product['id'] ?? '').toString(),
      variantId: variantId,
      quantity: (json['quantity'] ?? 1) is int ? json['quantity'] ?? 1 : (json['quantity'] as num).toInt(),
      note: json['note'],
      productName: product['name'] ?? '',
      productThumbnail: product['thumbnail'],
      price: priceSource.moneyInt('price').toDouble(),
      stock: {'v': variant?['stock'] ?? product['stock'] ?? 0}.asInt('v'),
      weight: {'v': product['weight'] ?? 0}.asDouble('v'),
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

  CartGroupModel copyWith({List<CartItemModel>? items}) {
    return CartGroupModel(
      storeId: storeId,
      storeName: storeName,
      storeLogo: storeLogo,
      storeAddressId: storeAddressId,
      items: items ?? this.items,
    );
  }

  double get subtotal => items.fold(0, (sum, item) => sum + item.subtotal);
  double get totalWeight => items.fold(0, (sum, item) => sum + (item.weight * item.quantity));
  int get itemCount => items.length;

  // Value equality on storeId: checkoutProvider is a family keyed by this
  // model, and Riverpod caches family state by argument equality. Identity
  // equality would spawn a fresh CheckoutNotifier on every rebuild.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CartGroupModel && other.storeId == storeId);

  @override
  int get hashCode => storeId.hashCode;
}
