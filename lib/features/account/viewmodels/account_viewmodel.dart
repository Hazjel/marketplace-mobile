import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:blukios_marketplace/core/providers.dart';
import 'package:blukios_marketplace/features/account/data/profile_repository.dart';
import 'package:blukios_marketplace/features/auth/models/user_model.dart';
import 'package:blukios_marketplace/features/auth/viewmodels/auth_viewmodel.dart';

final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => ProfileRepository(ref.watch(apiClientProvider)),
);

class AccountData {
  final UserModel? user;
  final bool isLoading;
  final bool isSaving;
  final String? error;

  const AccountData({
    this.user,
    this.isLoading = true,
    this.isSaving = false,
    this.error,
  });

  /// Defaults mirror the API's own key set — the settings screen renders
  /// from these so a not-yet-loaded profile still shows the right toggles.
  static const notificationDefaults = <String, bool>{
    'order_updates': true,
    'review_reminders': true,
    'promotions': false,
    'price_drops': true,
    'newsletter': false,
    'new_messages': true,
  };

  static const privacyDefaults = <String, bool>{
    'profile_visible': true,
    'show_online_status': true,
    'show_purchase_history': false,
  };

  Map<String, bool> get notificationPrefs => {
        ...notificationDefaults,
        ...?user?.notificationPrefs,
      };

  Map<String, bool> get privacyPrefs => {
        ...privacyDefaults,
        ...?user?.privacyPrefs,
      };

  AccountData copyWith({
    UserModel? user,
    bool? isLoading,
    bool? isSaving,
    String? error,
    bool clearError = false,
  }) {
    return AccountData(
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class AccountNotifier extends Notifier<AccountData> {
  @override
  AccountData build() {
    // Seed from the session we already have so the screen paints
    // immediately, then refresh from the server for prefs/avatar.
    final sessionUser = ref.watch(authProvider).currentUser;
    return AccountData(user: sessionUser, isLoading: sessionUser == null);
  }

  Future<void> loadProfile() async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final user = await ref.read(profileRepositoryProvider).getProfile();
      state = state.copyWith(user: user, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Returns null on success, or an error message on failure.
  Future<String?> updateProfile({
    required String name,
    String? phoneNumber,
    String? currentPassword,
    String? newPassword,
    String? avatarPath,
  }) async {
    state = state.copyWith(isSaving: true, clearError: true);

    try {
      final user = await ref.read(profileRepositoryProvider).updateProfile(
            name: name,
            phoneNumber: phoneNumber,
            currentPassword: currentPassword,
            newPassword: newPassword,
            avatarPath: avatarPath,
          );
      state = state.copyWith(user: user, isSaving: false);
      return null;
    } catch (e) {
      state = state.copyWith(isSaving: false);
      return e.toString();
    }
  }

  /// Optimistically flips [key] so the switch responds instantly, then
  /// reverts if the request fails.
  Future<String?> toggleNotification(String key, bool value) async {
    final updated = {...state.notificationPrefs, key: value};
    final previous = state.user;
    state = state.copyWith(user: previous?.copyWith(notificationPrefs: updated));

    try {
      final user = await ref
          .read(profileRepositoryProvider)
          .updateSettings(notificationPrefs: updated);
      state = state.copyWith(user: user);
      return null;
    } catch (e) {
      state = state.copyWith(user: previous);
      return e.toString();
    }
  }

  Future<String?> togglePrivacy(String key, bool value) async {
    final updated = {...state.privacyPrefs, key: value};
    final previous = state.user;
    state = state.copyWith(user: previous?.copyWith(privacyPrefs: updated));

    try {
      final user = await ref
          .read(profileRepositoryProvider)
          .updateSettings(privacyPrefs: updated);
      state = state.copyWith(user: user);
      return null;
    } catch (e) {
      state = state.copyWith(user: previous);
      return e.toString();
    }
  }
}

final accountProvider =
    NotifierProvider<AccountNotifier, AccountData>(AccountNotifier.new);
