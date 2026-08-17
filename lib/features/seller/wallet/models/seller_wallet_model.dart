import 'package:blukios_marketplace/core/utils/json.dart';
import 'package:blukios_marketplace/features/home/models/product_model.dart';

/// `StoreBalanceResource` — `store_balance_histories` is only present when
/// eager loaded server-side, so [histories] is empty on most responses
/// (the standalone history list endpoint is used instead).
class StoreBalanceModel {
  final String id;
  final StoreMini? store;
  final double balance;
  final double pendingBalance;
  final List<StoreBalanceHistoryModel> histories;

  StoreBalanceModel({
    required this.id,
    this.store,
    required this.balance,
    required this.pendingBalance,
    this.histories = const [],
  });

  factory StoreBalanceModel.fromJson(Map<String, dynamic> json) {
    final rawHistories = json['store_balance_histories'];
    return StoreBalanceModel(
      id: json.asString('id'),
      store: json['store'] is Map<String, dynamic>
          ? StoreMini.fromJson(json['store'])
          : null,
      balance: json.asDouble('balance'),
      pendingBalance: json.asDouble('pending_balance'),
      histories: rawHistories is List
          ? rawHistories
              .whereType<Map<String, dynamic>>()
              .map(StoreBalanceHistoryModel.fromJson)
              .toList()
          : const [],
    );
  }
}

/// `StoreBalanceHistoryResource`. `type` is one of `income`, `withdraw`,
/// `initial` per the backend migration, but rendered generically here in
/// case new types are added server-side.
class StoreBalanceHistoryModel {
  final String id;
  final String type;
  final String? referenceId;
  final String? referenceType;
  final double amount;
  final String? remarks;

  StoreBalanceHistoryModel({
    required this.id,
    required this.type,
    this.referenceId,
    this.referenceType,
    required this.amount,
    this.remarks,
  });

  bool get isCredit => type == 'income' || type == 'initial';

  factory StoreBalanceHistoryModel.fromJson(Map<String, dynamic> json) {
    return StoreBalanceHistoryModel(
      id: json.asString('id'),
      type: json.asString('type'),
      referenceId: json.asStringOrNull('reference_id'),
      referenceType: json.asStringOrNull('reference_type'),
      amount: json.asDouble('amount'),
      remarks: json.asStringOrNull('remarks'),
    );
  }
}

/// `WithdrawalResource`. `bankAccountNumber` arrives pre-masked from the
/// server (e.g. `"****1234"`) — never render the raw number, it isn't sent.
class WithdrawalModel {
  final String id;
  final double amount;
  final String bankAccountName;
  final String bankAccountNumber;
  final String bankName;
  final String? proof;
  final String status;
  final String? createdAt;

  WithdrawalModel({
    required this.id,
    required this.amount,
    required this.bankAccountName,
    required this.bankAccountNumber,
    required this.bankName,
    this.proof,
    required this.status,
    this.createdAt,
  });

  factory WithdrawalModel.fromJson(Map<String, dynamic> json) {
    return WithdrawalModel(
      id: json.asString('id'),
      amount: json.asDouble('amount'),
      bankAccountName: json.asString('bank_account_name'),
      bankAccountNumber: json.asString('bank_account_number'),
      bankName: json.asString('bank_name'),
      proof: json.asStringOrNull('proof'),
      status: json.asString('status'),
      createdAt: json.asStringOrNull('created_at'),
    );
  }
}
