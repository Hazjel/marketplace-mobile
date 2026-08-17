import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:blukios_marketplace/core/monitoring/analytics_service.dart';
import 'package:blukios_marketplace/core/network/api_exceptions.dart';
import 'package:blukios_marketplace/core/providers.dart';
import 'package:blukios_marketplace/core/storage/secure_storage.dart';
import 'package:blukios_marketplace/features/auth/models/user_model.dart';

enum AuthState { unknown, authenticated, unauthenticated }

class AuthData {
  final AuthState state;
  final UserModel? currentUser;
  final bool isLoading;
  final String? errorMessage;

  const AuthData({
    this.state = AuthState.unknown,
    this.currentUser,
    this.isLoading = false,
    this.errorMessage,
  });

  AuthData copyWith({
    AuthState? state,
    UserModel? currentUser,
    bool clearUser = false,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AuthData(
      state: state ?? this.state,
      currentUser: clearUser ? null : (currentUser ?? this.currentUser),
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class AuthNotifier extends Notifier<AuthData> {
  @override
  AuthData build() => const AuthData();

  Future<void> checkAuthStatus() async {
    final token = await SecureStorage.getToken();
    if (token == null) {
      state = state.copyWith(state: AuthState.unauthenticated, clearUser: true);
      return;
    }

    try {
      final user = await ref.read(authRepositoryProvider).getProfile();
      state = state.copyWith(state: AuthState.authenticated, currentUser: user);
    } on ApiException catch (e) {
      // Only a real auth rejection (invalid/expired/revoked token) should
      // sign the user out. A network blip, timeout, or server hiccup on
      // startup must NOT wipe an otherwise-valid saved session — that was
      // forcing a full re-login on every flaky connection. Stay
      // `unknown` so the router holds its redirect decision instead of
      // bouncing to /login; the next successful check (retry, next
      // launch, or a real API call's own 401) resolves it properly.
      if (e.statusCode == 401) {
        await SecureStorage.clearAll();
        state = state.copyWith(state: AuthState.unauthenticated, clearUser: true);
      }
    } catch (_) {
      // Non-API exception (e.g. JSON parsing) — same "don't destroy a
      // possibly-valid session over a transient failure" reasoning.
    }
  }

  Future<bool> login(String email, String password) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final user = await ref.read(authRepositoryProvider).login(email, password);
      state = state.copyWith(
        state: AuthState.authenticated,
        currentUser: user,
        isLoading: false,
      );
      AnalyticsService.logEvent('login', parameters: {'method': 'email'});
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.message);
      return false;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Terjadi kesalahan, coba lagi',
      );
      return false;
    }
  }

  Future<bool> register({
    required String name,
    required String email,
    required String password,
    required String phoneNumber,
    required String role,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final user = await ref.read(authRepositoryProvider).register(
            name: name,
            email: email,
            password: password,
            phoneNumber: phoneNumber,
            role: role,
          );
      state = state.copyWith(
        state: AuthState.authenticated,
        currentUser: user,
        isLoading: false,
      );
      AnalyticsService.logEvent('sign_up', parameters: {'method': 'email', 'role': role});
      return true;
    } on ApiException catch (e) {
      String errorMsg = e.message;
      if (e.errors is Map) {
        final fieldErrors = (e.errors as Map)
            .values
            .expand((v) => v is List ? v : [v])
            .join('\n');
        if (fieldErrors.isNotEmpty) errorMsg = fieldErrors;
      }
      state = state.copyWith(isLoading: false, errorMessage: errorMsg);
      return false;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Terjadi kesalahan, coba lagi',
      );
      return false;
    }
  }

  /// After an external flow (e.g. Google OAuth deep link) saves the token
  /// directly to SecureStorage, call this to refresh session state.
  Future<void> refreshAfterExternalLogin() => checkAuthStatus();

  Future<void> logout() async {
    await ref.read(authRepositoryProvider).logout();
    state = state.copyWith(
      state: AuthState.unauthenticated,
      clearUser: true,
      clearError: true,
    );
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthData>(AuthNotifier.new);
