import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:blukios_marketplace/core/network/api_exceptions.dart';
import 'package:blukios_marketplace/core/providers.dart';
import 'package:blukios_marketplace/features/auth/viewmodels/auth_viewmodel.dart';
import 'package:blukios_marketplace/features/balance/models/buyer_balance_model.dart';

class BuyerBalanceData {
  /// Null until a load succeeds.
  final int? balance;
  final List<BuyerBalanceHistory> histories;
  final int currentPage;
  final bool hasMore;
  final bool isLoading;
  final bool isLoadingMore;
  final String? error;

  /// The API answered 403: no buyer profile, so no Saldo Blukios.
  final bool notBuyer;

  const BuyerBalanceData({
    this.balance,
    this.histories = const [],
    this.currentPage = 0,
    this.hasMore = false,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.error,
    this.notBuyer = false,
  });

  BuyerBalanceData copyWith({
    bool? isLoading,
    bool? isLoadingMore,
    String? error,
    bool clearError = false,
  }) {
    return BuyerBalanceData(
      balance: balance,
      histories: histories,
      currentPage: currentPage,
      hasMore: hasMore,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: clearError ? null : (error ?? this.error),
      notBuyer: notBuyer,
    );
  }
}

/// Shared by the profile entry, the Saldo Blukios screen and checkout, so a
/// refresh anywhere shows everywhere.
class BuyerBalanceNotifier extends Notifier<BuyerBalanceData> {
  /// Bumped by every load() and account switch; a response from an older
  /// generation is dropped.
  int _generation = 0;
  Future<void>? _loading;

  @override
  BuyerBalanceData build() {
    // Another account logging in must not see the previous one's saldo.
    ref.watch(authProvider.select((a) => a.currentUser?.id));
    _generation++;
    _loading = null;
    return const BuyerBalanceData();
  }

  /// Loads the balance and the first history page, replacing the list.
  /// Joins a load already in flight; supersedes a running loadMore().
  Future<void> load() {
    if (_loading case final running?) return running;
    late final Future<void> loading;
    loading = _load(++_generation).whenComplete(() {
      if (identical(_loading, loading)) _loading = null;
    });
    return _loading = loading;
  }

  Future<void> _load(int generation) async {
    state = state.copyWith(isLoading: true, isLoadingMore: false, clearError: true);
    try {
      final page = await ref.read(buyerBalanceRepositoryProvider).getBalance();
      if (generation != _generation) return;
      state = BuyerBalanceData(
        balance: page.balance,
        histories: page.histories.items,
        currentPage: page.histories.meta.currentPage,
        hasMore: page.histories.hasMore,
      );
    } catch (e) {
      if (generation != _generation) return;
      // Balance unknown: nothing may offer a stale amount.
      state = e is ApiException && e.statusCode == 403
          ? const BuyerBalanceData(notBuyer: true)
          : BuyerBalanceData(error: e is ApiException ? e.message : e.toString());
    }
  }

  Future<void> loadMore() async {
    if (_loading != null || !state.hasMore || state.isLoadingMore) return;
    final generation = _generation;
    state = state.copyWith(isLoadingMore: true, clearError: true);
    try {
      final page = await ref
          .read(buyerBalanceRepositoryProvider)
          .getBalance(page: state.currentPage + 1);
      if (generation != _generation) return;
      state = BuyerBalanceData(
        balance: page.balance,
        histories: [...state.histories, ...page.histories.items],
        currentPage: page.histories.meta.currentPage,
        hasMore: page.histories.hasMore,
      );
    } catch (e) {
      if (generation != _generation) return;
      state = state.copyWith(isLoadingMore: false, error: e.toString());
    }
  }
}

final buyerBalanceProvider =
    NotifierProvider<BuyerBalanceNotifier, BuyerBalanceData>(
  BuyerBalanceNotifier.new,
);
