import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';

/// In-memory stand-in for the platform-specific keystore/keychain that
/// `flutter_secure_storage` normally talks to over a Pigeon channel — which
/// doesn't exist in a plain `flutter test` (VM) environment and would throw
/// `MissingPluginException` otherwise.
///
/// `FlutterSecureStoragePlatform.instance` is a federated-plugin injection
/// point (same pattern as most other Flutter plugins split into a
/// platform-interface package) — setting it to this fake before a test and
/// registering it via [FlutterSecureStoragePlatform.instance] is enough:
/// `SecureStorage` (the app's wrapper) is unaware and unaffected, since it
/// only ever talks to `FlutterSecureStorage`, which itself just delegates to
/// whatever `FlutterSecureStoragePlatform.instance` currently is.
class FakeSecureStoragePlatform extends FlutterSecureStoragePlatform {
  final Map<String, String> _store = {};

  @override
  Future<void> write({
    required String key,
    required String value,
    required Map<String, String> options,
  }) async {
    _store[key] = value;
  }

  @override
  Future<String?> read({
    required String key,
    required Map<String, String> options,
  }) async {
    return _store[key];
  }

  @override
  Future<bool> containsKey({
    required String key,
    required Map<String, String> options,
  }) async {
    return _store.containsKey(key);
  }

  @override
  Future<void> delete({
    required String key,
    required Map<String, String> options,
  }) async {
    _store.remove(key);
  }

  @override
  Future<Map<String, String>> readAll({
    required Map<String, String> options,
  }) async {
    return Map.of(_store);
  }

  @override
  Future<void> deleteAll({required Map<String, String> options}) async {
    _store.clear();
  }
}
