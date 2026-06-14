import 'package:dio/dio.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final dynamic errors;

  ApiException({required this.message, this.statusCode, this.errors});

  factory ApiException.fromDioError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
        return ApiException(message: 'Koneksi timeout, coba lagi');
      case DioExceptionType.receiveTimeout:
        return ApiException(message: 'Server tidak merespons');
      case DioExceptionType.badResponse:
        final data = e.response?.data;
        return ApiException(
          message: data?['message'] ?? 'Terjadi kesalahan',
          statusCode: e.response?.statusCode,
          errors: data?['errors'],
        );
      case DioExceptionType.connectionError:
        return ApiException(message: 'Tidak ada koneksi internet');
      default:
        return ApiException(message: 'Terjadi kesalahan tidak terduga');
    }
  }

  @override
  String toString() => message;
}
