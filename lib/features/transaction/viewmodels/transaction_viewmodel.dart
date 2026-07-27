import 'package:flutter/foundation.dart';
import 'package:blukios_marketplace/features/transaction/data/transaction_repository.dart';
import 'package:blukios_marketplace/features/transaction/models/transaction_model.dart';

class TransactionViewModel extends ChangeNotifier {
  final TransactionRepository _transactionRepository;

  TransactionViewModel(this._transactionRepository);

  List<TransactionModel> transactions = [];
  bool isLoading = true;
  String? error;

  Future<void> loadTransactions() async {
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      transactions = await _transactionRepository.getTransactions();
    } catch (e) {
      error = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// Re-checks payment status against Midtrans for one transaction and
  /// updates it in place. Returns null on success, or an error message.
  Future<String?> refreshStatus(String id) async {
    try {
      final updated = await _transactionRepository.checkPaymentStatus(id);
      transactions = transactions.map((t) => t.id == id ? updated : t).toList();
      notifyListeners();
      return null;
    } catch (e) {
      return e.toString();
    }
  }
}
