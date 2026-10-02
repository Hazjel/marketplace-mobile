import 'package:blukios_marketplace/core/utils/json.dart';

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
  /// Only on orders from before 2026-10-02; newer ones carry [serviceFee].
  final double tax;
  final double serviceFee;
  final double grandTotal;
  final String? voucherId;
  final String? voucherCode;
  final double discountAmount;
  final String paymentStatus;
  final String? snapToken;
  final String? createdAt;
  final List<TransactionDetailModel> transactionDetails;

  /// Refund for an order the seller rejected after payment: null when no
  /// refund is owed, else `processing` | `manual_required` | `refunded`.
  final String? refundStatus;
  final String? refundMethod;
  final double? refundAmount;
  final String? refundReason;
  final String? refundNote;
  final String? refundedAt;

  /// Bank account for a manual refund; the API only sends it to the buyer
  /// who owns the order and to admins.
  final RefundAccount? refundAccount;

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
    this.serviceFee = 0,
    required this.grandTotal,
    this.voucherId,
    this.voucherCode,
    this.discountAmount = 0,
    required this.paymentStatus,
    this.snapToken,
    this.createdAt,
    required this.transactionDetails,
    this.reviewedProductIds = const {},
    this.refundStatus,
    this.refundMethod,
    this.refundAmount,
    this.refundReason,
    this.refundNote,
    this.refundedAt,
    this.refundAccount,
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
      shippingCost: json.moneyInt('shipping_cost').toDouble(),
      trackingNumber: json['tracking_number'],
      deliveryProof: json['delivery_proof'],
      deliveryStatus: json['delivery_status'] ?? 'pending',
      tax: json.moneyInt('tax').toDouble(),
      serviceFee: (json.moneyIntOrNull('service_fee') ?? 0).toDouble(),
      grandTotal: json.moneyInt('grand_total').toDouble(),
      voucherId: json['voucher_id']?.toString(),
      voucherCode: json['voucher_code'],
      discountAmount: json.moneyInt('discount_amount').toDouble(),
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
      refundStatus: json.asStringOrNull('refund_status'),
      refundMethod: json.asStringOrNull('refund_method'),
      refundAmount: json.moneyIntOrNull('refund_amount')?.toDouble(),
      refundReason: json.asStringOrNull('refund_reason'),
      refundNote: json.asStringOrNull('refund_note'),
      refundedAt: json.asStringOrNull('refunded_at'),
      refundAccount: json['refund_account'] is Map<String, dynamic>
          ? RefundAccount.fromJson(json['refund_account'] as Map<String, dynamic>)
          : null,
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
      serviceFee: serviceFee,
      grandTotal: grandTotal,
      voucherId: voucherId,
      voucherCode: voucherCode,
      discountAmount: discountAmount,
      paymentStatus: paymentStatus,
      snapToken: snapToken,
      createdAt: createdAt,
      transactionDetails: transactionDetails,
      reviewedProductIds: reviewedProductIds ?? this.reviewedProductIds,
      refundStatus: refundStatus,
      refundMethod: refundMethod,
      refundAmount: refundAmount,
      refundReason: refundReason,
      refundNote: refundNote,
      refundedAt: refundedAt,
      refundAccount: refundAccount,
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

  /// No further status change is expected — safe to stop listening for
  /// live updates on this order. A cancelled order whose refund is still
  /// moving keeps listening.
  bool get isTerminal {
    if (refundStatus != null) return refundStatus == 'refunded';
    return deliveryStatus == 'completed' ||
        deliveryStatus == 'cancelled' ||
        const ['failed', 'cancelled', 'expired'].contains(paymentStatus);
  }

  /// Waiting for the platform to transfer by hand (bank VA payments).
  bool get awaitsManualRefund => refundStatus == 'manual_required';

  String? get refundStatusLabel {
    switch (refundStatus) {
      case null:
        return null;
      case 'processing':
        return 'Refund Diproses';
      case 'manual_required':
        return 'Menunggu Refund';
      case 'refunded':
        return 'Dana Dikembalikan';
      default:
        return refundStatus;
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
      case 'cancelled':
        return 'Dibatalkan';
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
      subtotal: json.moneyInt('subtotal').toDouble(),
    );
  }
}

class RefundAccount {
  final String bankName;
  final String accountNumber;
  final String accountName;

  const RefundAccount({
    required this.bankName,
    required this.accountNumber,
    required this.accountName,
  });

  factory RefundAccount.fromJson(Map<String, dynamic> json) {
    return RefundAccount(
      bankName: json.asStringOrNull('bank_name') ?? '',
      accountNumber: json.asStringOrNull('account_number') ?? '',
      accountName: json.asStringOrNull('account_name') ?? '',
    );
  }
}
