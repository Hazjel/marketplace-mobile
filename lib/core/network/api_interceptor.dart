import 'package:dio/dio.dart';
import 'package:blukios_marketplace/core/storage/secure_storage.dart';

/// QueuedInterceptor serializes request processing,
/// preventing race conditions from async token reads.
class ApiInterceptor extends QueuedInterceptor {
  @override
  Future<void> onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    final token = await SecureStorage.getToken();
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode == 401) {
      await SecureStorage.clearToken();
    }
    handler.next(err);
  }
}
