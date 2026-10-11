import 'package:blukios_marketplace/core/utils/currency_formatter.dart';
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

  /// Part of [grandTotal] paid with Saldo Blukios; the rest went through
  /// Midtrans. On a cancelled order this part is already back in the saldo.
  final double balanceUsed;

  /// Part of [grandTotal] charged through Midtrans (what snap_token pays).
  final double midtransAmount;

  /// Saldo Blukios covered the whole order: already paid, no snap_token.
  final bool paidWithBalance;
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

  /// The buyer's complaint on this order, null when there is none (or the
  /// viewer may not see it).
  final TransactionComplaint? complaint;

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
    this.balanceUsed = 0,
    double? midtransAmount,
    this.paidWithBalance = false,
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
    this.complaint,
  }) : midtransAmount = midtransAmount ?? grandTotal - balanceUsed;

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
      balanceUsed: (json.moneyIntOrNull('balance_used') ?? 0).toDouble(),
      midtransAmount: json.moneyIntOrNull('midtrans_amount')?.toDouble(),
      paidWithBalance: json['paid_with_balance'] == true,
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
      complaint: json['complaint'] is Map<String, dynamic>
          ? TransactionComplaint.fromJson(json['complaint'] as Map<String, dynamic>)
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
      balanceUsed: balanceUsed,
      midtransAmount: midtransAmount,
      paidWithBalance: paidWithBalance,
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
      complaint: complaint,
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

  /// An open or escalated complaint blocks completing the order (the API
  /// answers 422 until it is withdrawn or resolved).
  bool get hasActiveComplaint => complaint?.isActive ?? false;

  /// What the buyer is told about their money. Mirrors the API's
  /// `App\Support\RefundMessage` word for word, so push, email and app
  /// agree. [refundAmount] is the Midtrans part only; [balanceUsed] went
  /// back to Saldo Blukios when the order was cancelled.
  String? get refundMessage {
    if (refundStatus == null) return null;
    final refund = refundAmount ?? 0;
    final x = CurrencyFormatter.formatRupiah(refund);
    final balanceNote = balanceUsed == 0
        ? ''
        : ' ${CurrencyFormatter.formatRupiah(balanceUsed)} sudah kembali ke Saldo Blukios.';

    if (refundStatus == 'refunded' && refundMethod == 'balance') {
      return '${CurrencyFormatter.formatRupiah(refund + balanceUsed)} sudah masuk ke Saldo Blukios dan bisa dipakai untuk belanja.';
    }
    if (refund == 0) {
      // Nothing owed through Midtrans (paid fully with Saldo Blukios).
      return balanceUsed == 0 ? null : 'Pesananmu dibatalkan.$balanceNote';
    }
    return switch (refundStatus) {
      'processing' => 'Pesananmu dibatalkan. Pengembalian $x ke metode pembayaranmu sedang diproses.$balanceNote',
      'manual_required' => 'Pengembalian dana $x sedang kami periksa dan akan segera diselesaikan.$balanceNote',
      'refunded' => refundMethod == 'manual'
          ? '$x sudah ditransfer ke rekening yang kamu isi.$balanceNote'
          : '$x sudah dikembalikan ke metode pembayaranmu. Waktu dana masuk mengikuti bank atau penyedia e-wallet.$balanceNote',
      _ => null,
    };
  }

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

/// `TransactionResource.complaint`: the buyer's complaint on a delivering
/// order. Labels match the web (fe-blue useTransactionStatus.js).
class TransactionComplaint {
  static const reasons = {
    'not_received': 'Barang tidak sampai',
    'damaged': 'Barang rusak',
    'wrong_item': 'Barang salah',
    'other': 'Lainnya',
  };

  static const statuses = {
    'open': 'Menunggu tanggapan penjual',
    'escalated': 'Ditinjau admin',
    'approved': 'Disetujui – dana dikembalikan',
    'rejected': 'Ditolak',
    'withdrawn': 'Ditarik',
  };

  final String id;

  /// `open` | `escalated` | `approved` | `rejected` | `withdrawn`.
  final String status;
  final String reason;
  final String description;

  /// Full photo URLs.
  final List<String> photos;
  final String? sellerResponse;
  final String? adminNote;

  /// Seller must answer an `open` complaint by then, or it escalates.
  final String? deadlineAt;
  final String? escalatedAt;
  final String? resolvedAt;
  final String? createdAt;

  const TransactionComplaint({
    required this.id,
    required this.status,
    this.reason = '',
    this.description = '',
    this.photos = const [],
    this.sellerResponse,
    this.adminNote,
    this.deadlineAt,
    this.escalatedAt,
    this.resolvedAt,
    this.createdAt,
  });

  bool get isActive => status == 'open' || status == 'escalated';

  String get statusLabel => statuses[status] ?? status;
  String get reasonLabel => reasons[reason] ?? reason;

  factory TransactionComplaint.fromJson(Map<String, dynamic> json) {
    return TransactionComplaint(
      id: json.asString('id'),
      status: json.asString('status'),
      reason: json.asString('reason'),
      description: json.asString('description'),
      photos: json['photos'] is List
          ? (json['photos'] as List).whereType<String>().toList()
          : const [],
      sellerResponse: json.asStringOrNull('seller_response'),
      adminNote: json.asStringOrNull('admin_note'),
      deadlineAt: json.asStringOrNull('deadline_at'),
      escalatedAt: json.asStringOrNull('escalated_at'),
      resolvedAt: json.asStringOrNull('resolved_at'),
      createdAt: json.asStringOrNull('created_at'),
    );
  }
}
