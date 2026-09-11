import 'package:blukios_marketplace/core/utils/json.dart';

class VoucherModel {
  final String voucherId;
  final String code;
  final double discountAmount;

  const VoucherModel({
    required this.voucherId,
    required this.code,
    required this.discountAmount,
  });

  factory VoucherModel.fromJson(Map<String, dynamic> json) {
    return VoucherModel(
      voucherId: json['voucher_id'].toString(),
      code: json['code'] ?? '',
      discountAmount: json.moneyInt('discount_amount').toDouble(),
    );
  }
}
