import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:blukios_marketplace/core/network/api_exceptions.dart';
import 'package:blukios_marketplace/core/providers.dart';
import 'package:blukios_marketplace/features/seller/voucher/models/seller_voucher_model.dart';

/// Backs the seller voucher list + create/edit form.
class SellerVoucherData {
  final List<SellerVoucherModel> vouchers;
  final bool isLoading;
  final String? error;

  /// Id of the voucher currently being deleted, so its card can show a
  /// disabled/dimmed state without blocking the rest of the list.
  final String? deletingId;

  const SellerVoucherData({
    this.vouchers = const [],
    this.isLoading = true,
    this.error,
    this.deletingId,
  });

  SellerVoucherData copyWith({
    List<SellerVoucherModel>? vouchers,
    bool? isLoading,
    String? error,
    bool clearError = false,
    String? deletingId,
    bool clearDeletingId = false,
  }) {
    return SellerVoucherData(
      vouchers: vouchers ?? this.vouchers,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      deletingId: clearDeletingId ? null : (deletingId ?? this.deletingId),
    );
  }
}

class SellerVoucherNotifier extends Notifier<SellerVoucherData> {
  @override
  SellerVoucherData build() => const SellerVoucherData();

  Future<void> loadVouchers() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final vouchers = await ref.read(sellerVoucherRepositoryProvider).list();
      state = state.copyWith(vouchers: vouchers, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e is ValidationException ? e.firstError : e.toString(),
      );
    }
  }

  /// Returns null on success, or an error message (with
  /// [ValidationException.firstError] surfaced when the server rejected a
  /// specific field).
  Future<String?> createVoucher({
    required String code,
    required String type,
    required double value,
    double? minPurchase,
    double? maxDiscount,
    int? usageLimit,
    int? usageLimitPerBuyer,
    DateTime? startsAt,
    DateTime? expiresAt,
    bool? isActive,
  }) async {
    try {
      final voucher = await ref.read(sellerVoucherRepositoryProvider).create(
            code: code,
            type: type,
            value: value,
            minPurchase: minPurchase,
            maxDiscount: maxDiscount,
            usageLimit: usageLimit,
            usageLimitPerBuyer: usageLimitPerBuyer,
            startsAt: startsAt,
            expiresAt: expiresAt,
            isActive: isActive,
          );
      state = state.copyWith(vouchers: [voucher, ...state.vouchers]);
      return null;
    } catch (e) {
      return e is ValidationException ? e.firstError : e.toString();
    }
  }

  Future<String?> updateVoucher(
    String id, {
    required String code,
    required String type,
    required double value,
    double? minPurchase,
    double? maxDiscount,
    int? usageLimit,
    int? usageLimitPerBuyer,
    DateTime? startsAt,
    DateTime? expiresAt,
    bool? isActive,
  }) async {
    try {
      final voucher =
          await ref.read(sellerVoucherRepositoryProvider).update(
                id,
                code: code,
                type: type,
                value: value,
                minPurchase: minPurchase,
                maxDiscount: maxDiscount,
                usageLimit: usageLimit,
                usageLimitPerBuyer: usageLimitPerBuyer,
                startsAt: startsAt,
                expiresAt: expiresAt,
                isActive: isActive,
              );
      state = state.copyWith(
        vouchers:
            state.vouchers.map((v) => v.id == id ? voucher : v).toList(),
      );
      return null;
    } catch (e) {
      return e is ValidationException ? e.firstError : e.toString();
    }
  }

  /// Returns null on success, or an error message — e.g. the backend's
  /// "sudah pernah dipakai, nonaktifkan saja" sentence when the voucher
  /// has redemption history, surfaced verbatim via [ValidationException].
  Future<String?> deleteVoucher(String id) async {
    state = state.copyWith(deletingId: id);
    try {
      await ref.read(sellerVoucherRepositoryProvider).delete(id);
      state = state.copyWith(
        vouchers: state.vouchers.where((v) => v.id != id).toList(),
        clearDeletingId: true,
      );
      return null;
    } catch (e) {
      state = state.copyWith(clearDeletingId: true);
      return e is ValidationException ? e.firstError : e.toString();
    }
  }
}

final sellerVoucherProvider =
    NotifierProvider<SellerVoucherNotifier, SellerVoucherData>(
  SellerVoucherNotifier.new,
);
