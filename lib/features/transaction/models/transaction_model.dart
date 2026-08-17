class TransactionModel {
  final String id;
  final String code;
  final String? storeId;
  final String? storeName;
  final String? addressId;
  final String? address;
  final String? city;
  final String? postalCode;
  final double? destLatitude;
  final double? destLongitude;
  final String? shipping;
  final String? shippingType;
  final double shippingCost;
  final String? trackingNumber;
  final String? deliveryProof;
  final String deliveryStatus;
  final double tax;
  final double grandTotal;
  final String paymentStatus;
  final String? snapToken;
  final String? createdAt;
  final List<TransactionDetailModel> transactionDetails;

  /// Product ids already reviewed within this transaction — from the
  /// `product_reviews` relation, present when the API loads it (e.g. on
  /// `GET /transaction/{id}`, not necessarily on the list endpoint).
  final Set<String> reviewedProductIds;

  TransactionModel({
    required this.id,
    required this.code,
    this.storeId,
    this.storeName,
    this.addressId,
    this.address,
    this.city,
    this.postalCode,
    this.destLatitude,
    this.destLongitude,
    this.shipping,
    this.shippingType,
    required this.shippingCost,
    this.trackingNumber,
    this.deliveryProof,
    required this.deliveryStatus,
    required this.tax,
    required this.grandTotal,
    required this.paymentStatus,
    this.snapToken,
    this.createdAt,
    required this.transactionDetails,
    this.reviewedProductIds = const {},
  });

  factory TransactionModel.fromJson(Map<String, dynamic> json) {
    final store = json['store'];
    return TransactionModel(
      id: json['id'].toString(),
      code: json['code'] ?? '',
      storeId: store != null ? store['id']?.toString() : null,
      storeName: store != null ? store['name'] : null,
      addressId: json['address_id']?.toString(),
      address: json['address'],
      city: json['city'],
      postalCode: json['postal_code'],
      destLatitude: json['dest_latitude'] != null ? (json['dest_latitude'] as num).toDouble() : null,
      destLongitude: json['dest_longitude'] != null ? (json['dest_longitude'] as num).toDouble() : null,
      shipping: json['shipping'],
      shippingType: json['shipping_type'],
      shippingCost: (json['shipping_cost'] ?? 0).toDouble(),
      trackingNumber: json['tracking_number'],
      deliveryProof: json['delivery_proof'],
      deliveryStatus: json['delivery_status'] ?? 'pending',
      tax: (json['tax'] ?? 0).toDouble(),
      grandTotal: (json['grand_total'] ?? 0).toDouble(),
      paymentStatus: json['payment_status'] ?? 'pending',
      snapToken: json['snap_token'],
      createdAt: json['created_at'],
      transactionDetails: json['transaction_details'] != null
          ? (json['transaction_details'] as List)
              .map((e) => TransactionDetailModel.fromJson(e))
              .toList()
          : [],
      reviewedProductIds: json['product_reviews'] is List
          ? (json['product_reviews'] as List)
              .map((e) => (e as Map)['product_id']?.toString())
              .whereType<String>()
              .toSet()
          : const {},
    );
  }

  TransactionModel copyWith({Set<String>? reviewedProductIds}) {
    return TransactionModel(
      id: id,
      code: code,
      storeId: storeId,
      storeName: storeName,
      addressId: addressId,
      address: address,
      city: city,
      postalCode: postalCode,
      destLatitude: destLatitude,
      destLongitude: destLongitude,
      shipping: shipping,
      shippingType: shippingType,
      shippingCost: shippingCost,
      trackingNumber: trackingNumber,
      deliveryProof: deliveryProof,
      deliveryStatus: deliveryStatus,
      tax: tax,
      grandTotal: grandTotal,
      paymentStatus: paymentStatus,
      snapToken: snapToken,
      createdAt: createdAt,
      transactionDetails: transactionDetails,
      reviewedProductIds: reviewedProductIds ?? this.reviewedProductIds,
    );
  }

  String get paymentStatusLabel {
    switch (paymentStatus) {
      case 'pending':
        return 'Menunggu Pembayaran';
      case 'paid':
        return 'Dibayar';
      case 'failed':
        return 'Gagal';
      case 'cancelled':
        return 'Dibatalkan';
      case 'expired':
        return 'Kedaluwarsa';
      default:
        return paymentStatus;
    }
  }

  String get deliveryStatusLabel {
    switch (deliveryStatus) {
      case 'pending':
        return 'Menunggu Diproses';
      case 'processing':
        return 'Diproses';
      case 'delivering':
        return 'Dikirim';
      case 'completed':
        return 'Selesai';
      default:
        return deliveryStatus;
    }
  }
}

class TransactionDetailModel {
  final String id;
  final String productId;
  final String? productName;
  final String? productThumbnail;
  final int qty;
  final double subtotal;

  TransactionDetailModel({
    required this.id,
    required this.productId,
    this.productName,
    this.productThumbnail,
    required this.qty,
    required this.subtotal,
  });

  factory TransactionDetailModel.fromJson(Map<String, dynamic> json) {
    final product = json['product'];
    return TransactionDetailModel(
      id: json['id'].toString(),
      productId: (json['product_id'] ?? '').toString(),
      productName: product != null ? product['name'] : null,
      productThumbnail: product != null ? product['thumbnail'] : null,
      qty: (json['qty'] ?? 1) is int ? json['qty'] ?? 1 : (json['qty'] as num).toInt(),
      subtotal: (json['subtotal'] ?? 0).toDouble(),
    );
  }
}
