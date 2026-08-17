import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:blukios_marketplace/core/providers.dart';
import 'package:blukios_marketplace/features/auth/viewmodels/auth_viewmodel.dart';
import 'package:blukios_marketplace/features/seller/store/models/seller_store_model.dart';

class SellerStoreData {
  final SellerStoreModel? store;
  final bool isLoading;
  final bool isSaving;
  final String? error;

  const SellerStoreData({
    this.store,
    this.isLoading = false,
    this.isSaving = false,
    this.error,
  });

  bool get hasStore => store != null;

  SellerStoreData copyWith({
    SellerStoreModel? store,
    bool? isLoading,
    bool? isSaving,
    String? error,
    bool clearError = false,
  }) {
    return SellerStoreData(
      store: store ?? this.store,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class SellerStoreNotifier extends Notifier<SellerStoreData> {
  @override
  SellerStoreData build() => const SellerStoreData();

  Future<void> loadMyStore() async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final store = await ref.read(sellerStoreRepositoryProvider).getMyStore();
      state = state.copyWith(store: store, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Returns null on success, or an error message on failure. On success
  /// the user's role flips to `store` server-side, so this also refreshes
  /// the session via [AuthNotifier.checkAuthStatus].
  Future<String?> registerStore({
    required String name,
    required String phone,
    String? city,
    String? address,
    String? postalCode,
    double? latitude,
    double? longitude,
  }) async {
    state = state.copyWith(isSaving: true, clearError: true);

    try {
      final store = await ref.read(sellerStoreRepositoryProvider).registerStore(
            name: name,
            phone: phone,
            city: city,
            address: address,
            postalCode: postalCode,
            latitude: latitude,
            longitude: longitude,
          );
      state = state.copyWith(store: store, isSaving: false);
      await ref.read(authProvider.notifier).checkAuthStatus();
      return null;
    } catch (e) {
      state = state.copyWith(isSaving: false);
      return e.toString();
    }
  }

  /// Returns null on success, or an error message on failure.
  Future<String?> updateStore({
    required String name,
    required String about,
    required String phone,
    required String addressId,
    required String city,
    required String address,
    required String postalCode,
    double? latitude,
    double? longitude,
    bool? aiAssistantEnabled,
    String? logoPath,
  }) async {
    final currentStore = state.store;
    if (currentStore == null) {
      return 'Toko belum terdaftar';
    }

    state = state.copyWith(isSaving: true, clearError: true);

    try {
      final store = await ref.read(sellerStoreRepositoryProvider).updateStore(
            id: currentStore.id,
            name: name,
            about: about,
            phone: phone,
            addressId: addressId,
            city: city,
            address: address,
            postalCode: postalCode,
            latitude: latitude,
            longitude: longitude,
            aiAssistantEnabled: aiAssistantEnabled,
            logoPath: logoPath,
          );
      state = state.copyWith(store: store, isSaving: false);
      return null;
    } catch (e) {
      state = state.copyWith(isSaving: false);
      return e.toString();
    }
  }
}

final sellerStoreProvider =
    NotifierProvider<SellerStoreNotifier, SellerStoreData>(SellerStoreNotifier.new);
