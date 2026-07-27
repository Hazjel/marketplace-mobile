import 'package:flutter/foundation.dart';
import 'package:blukios_marketplace/core/network/api_exceptions.dart';
import 'package:blukios_marketplace/core/storage/secure_storage.dart';
import 'package:blukios_marketplace/features/auth/data/auth_repository.dart';
import 'package:blukios_marketplace/features/auth/models/user_model.dart';

enum AuthState { unknown, authenticated, unauthenticated }

class AuthViewModel extends ChangeNotifier {
  final AuthRepository _authRepository;

  AuthViewModel(this._authRepository);

  AuthState state = AuthState.unknown;
  UserModel? currentUser;
  bool isLoading = false;
  String? errorMessage;

  Future<void> checkAuthStatus() async {
    final token = await SecureStorage.getToken();
    if (token == null) {
      state = AuthState.unauthenticated;
      notifyListeners();
      return;
    }

    try {
      currentUser = await _authRepository.getProfile();
      state = AuthState.authenticated;
    } catch (_) {
      await SecureStorage.clearAll();
      state = AuthState.unauthenticated;
    }
    notifyListeners();
  }

  Future<bool> login(String email, String password) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      currentUser = await _authRepository.login(email, password);
      state = AuthState.authenticated;
      return true;
    } on ApiException catch (e) {
      errorMessage = e.message;
      return false;
    } catch (e) {
      errorMessage = 'Terjadi kesalahan, coba lagi';
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> register({
    required String name,
    required String email,
    required String password,
    required String phoneNumber,
    required String role,
  }) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      currentUser = await _authRepository.register(
        name: name,
        email: email,
        password: password,
        phoneNumber: phoneNumber,
        role: role,
      );
      state = AuthState.authenticated;
      return true;
    } on ApiException catch (e) {
      String errorMsg = e.message;
      if (e.errors is Map) {
        final fieldErrors = (e.errors as Map).values
            .expand((v) => v is List ? v : [v])
            .join('\n');
        if (fieldErrors.isNotEmpty) errorMsg = fieldErrors;
      }
      errorMessage = errorMsg;
      return false;
    } catch (e) {
      errorMessage = 'Terjadi kesalahan, coba lagi';
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// After an external flow (e.g. Google OAuth deep link) saves the token
  /// directly to SecureStorage, call this to refresh session state.
  Future<void> refreshAfterExternalLogin() => checkAuthStatus();

  Future<void> logout() async {
    await _authRepository.logout();
    currentUser = null;
    state = AuthState.unauthenticated;
    notifyListeners();
  }
}
