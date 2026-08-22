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
    // `SecureStorage.getToken()` already degrades platform *errors* to
    // `null` (see its own doc comment), but a hung platform-channel call
    // (keystore deadlock, corrupted secure-storage backend on some devices)
    // never throws at all — it just never completes, which left this whole
    // method (and therefore `AuthState`) stuck at `unknown` forever even
    // after the retry/fallback fix below. A hard timeout here guarantees
    // this can never hang past a few seconds regardless of cause.
    String? token;
    try {
      token = await SecureStorage.getToken().timeout(const Duration(seconds: 5));
    } catch (_) {
      token = null;
    }
    if (token == null) {
      state = state.copyWith(state: AuthState.unauthenticated, clearUser: true);
      return;
    }

    // Only a real auth rejection (invalid/expired/revoked token) should sign
    // the user out on the FIRST try — a network blip, timeout, or server
    // hiccup on startup must not wipe an otherwise-valid saved session.
    // But staying `unknown` with no bound on it was a real bug (reported
    // live: app permanently stuck on the splash screen) — this call fires
    // exactly once, from app.dart's initState, with nothing else ever
    // re-triggering it, so a persistent non-401 failure meant `unknown`
    // forever with zero recovery path short of the user never being able
    // to open the app at all. Retry a few times with backoff to ride out a
    // genuine blip, then fall back to unauthenticated — reaching the login
    // screen and having to sign back in is a far better outcome than an
    // app that never loads.
    const maxAttempts = 3;
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        // `ApiClient`'s own connect/receive timeouts (30s) already bound a
        // normal request, but they don't cover every failure mode (e.g. a
        // response that starts streaming but never finishes) — a hard cap
        // here means this attempt can never outlast ~10s regardless.
        final user = await ref
            .read(authRepositoryProvider)
            .getProfile()
            .timeout(const Duration(seconds: 10));
        state = state.copyWith(state: AuthState.authenticated, currentUser: user);
        return;
      } on ApiException catch (e) {
        if (e.statusCode == 401) {
          await SecureStorage.clearAll();
          state = state.copyWith(state: AuthState.unauthenticated, clearUser: true);
          return;
        }
        // Any other status (timeout, 5xx, offline) — fall through to retry.
      } catch (_) {
        // Non-API exception (e.g. JSON parsing, our own .timeout()) — also
        // just retry.
      }

      if (attempt < maxAttempts) {
        await Future.delayed(Duration(milliseconds: 400 * attempt));
      }
    }

    state = state.copyWith(state: AuthState.unauthenticated, clearUser: true);
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
