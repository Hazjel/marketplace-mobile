import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persists the auth session (Sanctum token) across app restarts.
///
/// `flutter_secure_storage` on Android is backed by the OS keystore, which
/// is known to occasionally throw `PlatformException` after an OS/keystore
/// upgrade, a restored device backup, or app-data corruption — see
/// https://github.com/mogol/flutter_secure_storage/issues (a long-running
/// class of issues). Without handling it, a single bad read would leave
/// [AuthState] stuck at `unknown` forever (the router never redirects,
/// since `unknown` means "haven't decided yet"), which looks to the user
/// like the app randomly forgot they were logged in. `resetOnError: true`
/// makes Android recover by wiping the corrupted store instead of throwing
/// on every call, and every method here degrades to "no session" on
/// failure rather than propagating, so a storage failure is equivalent to
/// a logged-out state — recoverable by logging in again — not a stuck app.
class SecureStorage {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(resetOnError: true),
  );
  static const _tokenKey = 'auth_token';
  static const _userKey = 'user_data';

  static Future<void> saveToken(String token) async {
    try {
      await _storage.write(key: _tokenKey, value: token);
    } catch (e, st) {
      debugPrint('SecureStorage.saveToken failed: $e\n$st');
    }
  }

  static Future<String?> getToken() async {
    try {
      return await _storage.read(key: _tokenKey);
    } catch (e, st) {
      debugPrint('SecureStorage.getToken failed: $e\n$st');
      return null;
    }
  }

  static Future<void> clearToken() async {
    try {
      await _storage.delete(key: _tokenKey);
    } catch (e, st) {
      debugPrint('SecureStorage.clearToken failed: $e\n$st');
    }
  }

  static Future<void> saveUser(String userData) async {
    try {
      await _storage.write(key: _userKey, value: userData);
    } catch (e, st) {
      debugPrint('SecureStorage.saveUser failed: $e\n$st');
    }
  }

  static Future<String?> getUser() async {
    try {
      return await _storage.read(key: _userKey);
    } catch (e, st) {
      debugPrint('SecureStorage.getUser failed: $e\n$st');
      return null;
    }
  }

  static Future<void> clearAll() async {
    try {
      await _storage.deleteAll();
    } catch (e, st) {
      debugPrint('SecureStorage.clearAll failed: $e\n$st');
    }
  }
}
