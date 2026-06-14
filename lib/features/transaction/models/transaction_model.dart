class TransactionModel {
  final String id;
  final String code;
  final String status;
  final int totalPrice;
  final int shippingCost;
  final String? paymentUrl;
  final String? shippingMethod;
  final String? trackingNumber;
  final String? createdAt;
  final List<TransactionDetailModel>? details;

  TransactionModel({
    required this.id,
    required this.code,
    required this.status,
    required this.totalPrice,
    required this.shippingCost,
    this.paymentUrl,
    this.shippingMethod,
    this.trackingNumber,
    this.createdAt,
    this.details,
  });

  factory TransactionModel.fromJson(Map<String, dynamic> json) {
    return TransactionModel(
      id: json['id'].toString(),
      code: json['code'] ?? '',
      status: json['status'] ?? 'pending',
      totalPrice: (json['total_price'] ?? 0) is int ? json['total_price'] ?? 0 : (json['total_price'] as num).toInt(),
      shippingCost: (json['shipping_cost'] ?? 0) is int ? json['shipping_cost'] ?? 0 : (json['shipping_cost'] as num).toInt(),
      paymentUrl: json['payment_url'],
      shippingMethod: json['shipping_method'],
      trackingNumber: json['tracking_number'],
      createdAt: json['created_at'],
      details: json['details'] != null
          ? (json['details'] as List)
              .map((e) => TransactionDetailModel.fromJson(e))
              .toList()
          : null,
    );
  }

  int get grandTotal => totalPrice + shippingCost;

  String get statusLabel {
    switch (status) {
      case 'pending':
        return 'Menunggu Pembayaran';
      case 'paid':
        return 'Dibayar';
      case 'processing':
        return 'Diproses';
      case 'shipped':
        return 'Dikirim';
      case 'delivered':
        return 'Diterima';
      case 'completed':
        return 'Selesai';
      case 'cancelled':
        return 'Dibatalkan';
      case 'expired':
        return 'Kedaluwarsa';
      default:
        return status;
    }
  }
}

class TransactionDetailModel {
  final String id;
  final String productId;
  final String productName;
  final String? productThumbnail;
  final int price;
  final int quantity;

  TransactionDetailModel({
    required this.id,
    required this.productId,
    required this.productName,
    this.productThumbnail,
    required this.price,
    required this.quantity,
  });

  factory TransactionDetailModel.fromJson(Map<String, dynamic> json) {
    return TransactionDetailModel(
      id: json['id'].toString(),
      productId: (json['product_id'] ?? '').toString(),
      productName: json['product']?['name'] ?? json['product_name'] ?? '',
      productThumbnail: json['product']?['thumbnail'],
      price: (json['price'] ?? 0) is int ? json['price'] ?? 0 : (json['price'] as num).toInt(),
      quantity: (json['quantity'] ?? 1) is int ? json['quantity'] ?? 1 : (json['quantity'] as num).toInt(),
    );
  }

  int get subtotal => price * quantity;
}
