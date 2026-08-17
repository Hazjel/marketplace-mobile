import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:blukios_marketplace/core/network/api_exceptions.dart';
import 'package:blukios_marketplace/core/providers.dart';
import 'package:blukios_marketplace/features/seller/wallet/models/seller_wallet_model.dart';

/// Backs the wallet screen: balance card + balance history + withdrawal
/// history, all loaded together.
class SellerWalletData {
  final StoreBalanceModel? balance;
  final bool isLoadingBalance;
  final String? balanceError;

  final List<StoreBalanceHistoryModel> history;
  final bool isLoadingHistory;
  final String? historyError;

  final List<WithdrawalModel> withdrawals;
  final bool isLoadingWithdrawals;
  final String? withdrawalsError;

  const SellerWalletData({
    this.balance,
    this.isLoadingBalance = true,
    this.balanceError,
    this.history = const [],
    this.isLoadingHistory = true,
    this.historyError,
    this.withdrawals = const [],
    this.isLoadingWithdrawals = true,
    this.withdrawalsError,
  });

  SellerWalletData copyWith({
    StoreBalanceModel? balance,
    bool clearBalance = false,
    bool? isLoadingBalance,
    String? balanceError,
    bool clearBalanceError = false,
    List<StoreBalanceHistoryModel>? history,
    bool? isLoadingHistory,
    String? historyError,
    bool clearHistoryError = false,
    List<WithdrawalModel>? withdrawals,
    bool? isLoadingWithdrawals,
    String? withdrawalsError,
    bool clearWithdrawalsError = false,
  }) {
    return SellerWalletData(
      balance: clearBalance ? null : (balance ?? this.balance),
      isLoadingBalance: isLoadingBalance ?? this.isLoadingBalance,
      balanceError:
          clearBalanceError ? null : (balanceError ?? this.balanceError),
      history: history ?? this.history,
      isLoadingHistory: isLoadingHistory ?? this.isLoadingHistory,
      historyError:
          clearHistoryError ? null : (historyError ?? this.historyError),
      withdrawals: withdrawals ?? this.withdrawals,
      isLoadingWithdrawals: isLoadingWithdrawals ?? this.isLoadingWithdrawals,
      withdrawalsError: clearWithdrawalsError
          ? null
          : (withdrawalsError ?? this.withdrawalsError),
    );
  }
}

class SellerWalletNotifier extends Notifier<SellerWalletData> {
  @override
  SellerWalletData build() => const SellerWalletData();

  Future<void> loadAll() async {
    await Future.wait([loadBalance(), loadHistory(), loadWithdrawals()]);
  }

  Future<void> loadBalance() async {
    state = state.copyWith(isLoadingBalance: true, clearBalanceError: true);
    try {
      final balance =
          await ref.read(sellerWalletRepositoryProvider).getMyBalance();
      state = state.copyWith(
        balance: balance,
        clearBalance: balance == null,
        isLoadingBalance: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoadingBalance: false,
        balanceError: e is ValidationException ? e.firstError : e.toString(),
      );
    }
  }

  Future<void> loadHistory() async {
    state = state.copyWith(isLoadingHistory: true, clearHistoryError: true);
    try {
      final history =
          await ref.read(sellerWalletRepositoryProvider).getHistory();
      state = state.copyWith(history: history, isLoadingHistory: false);
    } catch (e) {
      state = state.copyWith(
        isLoadingHistory: false,
        historyError: e is ValidationException ? e.firstError : e.toString(),
      );
    }
  }

  Future<void> loadWithdrawals() async {
    state = state.copyWith(
      isLoadingWithdrawals: true,
      clearWithdrawalsError: true,
    );
    try {
      final withdrawals =
          await ref.read(sellerWalletRepositoryProvider).getWithdrawals();
      state = state.copyWith(
        withdrawals: withdrawals,
        isLoadingWithdrawals: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoadingWithdrawals: false,
        withdrawalsError:
            e is ValidationException ? e.firstError : e.toString(),
      );
    }
  }
}

final sellerWalletProvider =
    NotifierProvider<SellerWalletNotifier, SellerWalletData>(
  SellerWalletNotifier.new,
);

/// Backs the withdrawal request form. Auto-disposes so a stale submit
/// error doesn't linger the next time the form is opened.
class WithdrawalFormData {
  final bool isSubmitting;
  final String? error;
  final WithdrawalModel? result;

  const WithdrawalFormData({
    this.isSubmitting = false,
    this.error,
    this.result,
  });

  WithdrawalFormData copyWith({
    bool? isSubmitting,
    String? error,
    bool clearError = false,
    WithdrawalModel? result,
  }) {
    return WithdrawalFormData(
      isSubmitting: isSubmitting ?? this.isSubmitting,
      error: clearError ? null : (error ?? this.error),
      result: result ?? this.result,
    );
  }
}

class WithdrawalFormNotifier extends AutoDisposeNotifier<WithdrawalFormData> {
  @override
  WithdrawalFormData build() => const WithdrawalFormData();

  /// Returns the created withdrawal on success, or null on failure (with
  /// [WithdrawalFormData.error] populated — this surfaces the server's
  /// validation message verbatim, e.g. minimum amount or insufficient
  /// balance, rather than hardcoding a client-side minimum).
  Future<WithdrawalModel?> submit({
    required String storeBalanceId,
    required double amount,
    required String bankAccountName,
    required String bankAccountNumber,
    required String bankName,
  }) async {
    state = state.copyWith(isSubmitting: true, clearError: true);

    try {
      final withdrawal =
          await ref.read(sellerWalletRepositoryProvider).requestWithdrawal(
                storeBalanceId: storeBalanceId,
                amount: amount,
                bankAccountName: bankAccountName,
                bankAccountNumber: bankAccountNumber,
                bankName: bankName,
              );
      state = state.copyWith(isSubmitting: false, result: withdrawal);
      return withdrawal;
    } catch (e) {
      state = state.copyWith(
        isSubmitting: false,
        error: e is ValidationException ? e.firstError : e.toString(),
      );
      return null;
    }
  }
}

final withdrawalFormProvider =
    AutoDisposeNotifierProvider<WithdrawalFormNotifier, WithdrawalFormData>(
  WithdrawalFormNotifier.new,
);
