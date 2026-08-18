import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:blukios_marketplace/core/providers.dart';
import 'package:blukios_marketplace/features/transaction/models/transaction_model.dart';

class SellerOrderDetailData {
  final TransactionModel? order;
  final bool isLoading;
  final String? error;
  final bool isUpdating;
  final String? updateError;

  const SellerOrderDetailData({
    this.order,
    this.isLoading = true,
    this.error,
    this.isUpdating = false,
    this.updateError,
  });

  SellerOrderDetailData copyWith({
    TransactionModel? order,
    bool? isLoading,
    String? error,
    bool clearError = false,
    bool? isUpdating,
    String? updateError,
    bool clearUpdateError = false,
  }) {
    return SellerOrderDetailData(
      order: order ?? this.order,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      isUpdating: isUpdating ?? this.isUpdating,
      updateError: clearUpdateError ? null : (updateError ?? this.updateError),
    );
  }
}

/// Keyed by transaction id, so each order detail screen has isolated state
/// and is disposed when the screen closes — same pattern as CheckoutNotifier.
class SellerOrderDetailNotifier
    extends AutoDisposeFamilyNotifier<SellerOrderDetailData, String> {
  bool _disposed = false;

  @override
  SellerOrderDetailData build(String orderId) {
    ref.onDispose(() => _disposed = true);
    return const SellerOrderDetailData();
  }

  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final order =
          await ref.read(transactionRepositoryProvider).getTransactionDetail(arg);
      if (_disposed) return;
      state = state.copyWith(order: order, isLoading: false);
    } catch (e) {
      if (_disposed) return;
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Updates delivery status / tracking number. [deliveryStatus] must be
  /// `processing` or `delivering` — see the comment on
  /// [TransactionRepository.updateDeliveryStatus] for why `completed` is
  /// deliberately excluded from what the seller can set here.
  ///
  /// Returns true on success.
  Future<bool> updateStatus({
    required String deliveryStatus,
    String? trackingNumber,
    String? deliveryProofPath,
  }) async {
    state = state.copyWith(isUpdating: true, clearUpdateError: true);

    try {
      final updated =
          await ref.read(transactionRepositoryProvider).updateDeliveryStatus(
                id: arg,
                deliveryStatus: deliveryStatus,
                trackingNumber: trackingNumber,
                deliveryProofPath: deliveryProofPath,
              );
      if (_disposed) return false;
      state = state.copyWith(order: updated, isUpdating: false);
      return true;
    } catch (e) {
      if (_disposed) return false;
      state = state.copyWith(isUpdating: false, updateError: e.toString());
      return false;
    }
  }
}

final sellerOrderDetailProvider = AutoDisposeNotifierProviderFamily<
    SellerOrderDetailNotifier, SellerOrderDetailData, String>(
  SellerOrderDetailNotifier.new,
);
