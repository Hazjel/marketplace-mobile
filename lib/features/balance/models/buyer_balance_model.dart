import 'package:blukios_marketplace/core/network/api_response.dart';
import 'package:blukios_marketplace/core/utils/currency_formatter.dart';
import 'package:blukios_marketplace/core/utils/json.dart';

/// One row of `GET /balance` → `histories.data`. [amount] is signed:
/// credits (refund, payment_returned) are positive, payments negative.
class BuyerBalanceHistory {
  final String id;
  final String type;
  final int amount;
  final String? remarks;
  final String? referenceCode;
  final String? createdAt;

  const BuyerBalanceHistory({
    required this.id,
    required this.type,
    required this.amount,
    this.remarks,
    this.referenceCode,
    this.createdAt,
  });

  factory BuyerBalanceHistory.fromJson(Map<String, dynamic> json) {
    return BuyerBalanceHistory(
      id: json.asString('id'),
      type: json.asString('type'),
      amount: json.moneyInt('amount'),
      remarks: json.asStringOrNull('remarks'),
      referenceCode: json.asStringOrNull('reference_code'),
      createdAt: json.asStringOrNull('created_at'),
    );
  }

  /// Same labels as the web's BuyerBalanceCard.
  String get typeLabel => switch (type) {
        'refund' => 'Refund',
        'payment' => 'Dipakai belanja',
        'payment_returned' => 'Dikembalikan',
        _ => type,
      };

  /// `+Rp 5.000` / `−Rp 5.000`, no sign at zero.
  String get signedAmount {
    final sign = amount > 0 ? '+' : (amount < 0 ? '−' : '');
    return '$sign${CurrencyFormatter.formatRupiah(amount.abs())}';
  }
}

/// `GET /balance` data: the current balance plus one page of history.
class BuyerBalancePage {
  final int balance;
  final PaginatedResponse<BuyerBalanceHistory> histories;

  const BuyerBalancePage({required this.balance, required this.histories});

  factory BuyerBalancePage.fromJson(Map<String, dynamic> json) {
    return BuyerBalancePage(
      balance: json.moneyInt('balance'),
      // `histories` is `{data: [...], meta: {...}}`, the shape
      // PaginatedResponse reads from under an envelope's `data`.
      histories: PaginatedResponse.parse(
        {'data': json['histories']},
        BuyerBalanceHistory.fromJson,
      ),
    );
  }
}
