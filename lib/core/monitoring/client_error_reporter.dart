import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:blukios_marketplace/config/api_config.dart';

/// Sends crashes to the API (`POST /client-errors`, source `mobile`), where
/// `ops:check` emails them to the team. Crashlytics keeps the full detail;
/// this is what makes someone notice.
///
/// Uses its own Dio without [ApiInterceptor]: a failing report must never
/// trigger auth handling, a toast, or report itself.
class ClientErrorReporter {
  ClientErrorReporter._();

  static const int _maxPerSession = 10;

  // App version from `--dart-define=APP_RELEASE=1.2.0`; optional.
  static const String _release = String.fromEnvironment('APP_RELEASE');

  static final Set<String> _sent = {};

  static final Dio _dio = Dio(BaseOptions(
    baseUrl: ApiConfig.baseUrl,
    connectTimeout: const Duration(seconds: 5),
    sendTimeout: const Duration(seconds: 5),
    receiveTimeout: const Duration(seconds: 5),
    headers: const {'Accept': 'application/json'},
  ));

  @visibleForTesting
  static Future<void> Function(Map<String, dynamic> body)? sendOverride;

  @visibleForTesting
  static bool? enabledOverride;

  @visibleForTesting
  static void resetForTest() {
    _sent.clear();
    sendOverride = null;
    enabledOverride = null;
  }

  static bool get _enabled => enabledOverride ?? !kDebugMode;

  /// Reports [error] once per distinct message, at most [_maxPerSession]
  /// per app session. Never throws.
  static void report(Object error, StackTrace? stack, {String? context}) {
    if (!_enabled) return;
    // API failures are counted server-side (5xx) or expected (4xx, offline).
    if (error is DioException) return;

    final message = context == null || context.isEmpty ? '$error' : '$error ($context)';
    if (message.isEmpty || _sent.contains(message) || _sent.length >= _maxPerSession) return;
    _sent.add(message);

    final body = <String, dynamic>{
      'source': 'mobile',
      'message': _truncate(message, 500),
      if (stack != null) 'stack': _truncate(stack.toString(), 4000),
      if (_release.isNotEmpty) 'release': _release,
    };

    final send = sendOverride ?? _post;
    send(body).catchError((Object e) {
      debugPrint('ClientErrorReporter: report failed: $e');
    });
  }

  static Future<void> _post(Map<String, dynamic> body) async {
    await _dio.post<void>('/client-errors', data: body);
  }

  static String _truncate(String value, int max) =>
      value.length <= max ? value : value.substring(0, max);
}
