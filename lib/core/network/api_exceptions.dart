import 'package:dio/dio.dart';

/// Base exception for all API errors.
class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final dynamic errors;

  ApiException({required this.message, this.statusCode, this.errors});

  factory ApiException.fromDioError(DioException e) {
    final statusCode = e.response?.statusCode;
    final data = e.response?.data;

    // 422 — Laravel validation: `{ message, errors: { field: [...] } }`.
    // No `success` key exists on this shape.
    if (statusCode == 422 && data is Map<String, dynamic>) {
      return ValidationException.fromBody(data);
    }

    // 404 — API returns `{ success: true, data: null }` for missing entities.
    // Treat any 404 as a NotFoundException regardless of `success` value.
    if (statusCode == 404) {
      final msg = (data is Map<String, dynamic>)
          ? (data['message'] as String?) ?? 'Data tidak ditemukan'
          : 'Data tidak ditemukan';
      return NotFoundException(message: msg);
    }

    switch (e.type) {
      case DioExceptionType.connectionTimeout:
        return ApiException(message: 'Koneksi timeout, coba lagi');
      case DioExceptionType.receiveTimeout:
        return ApiException(message: 'Server tidak merespons');
      case DioExceptionType.badResponse:
        return ApiException(
          message: data?['message'] ?? 'Terjadi kesalahan',
          statusCode: statusCode,
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

/// HTTP 404 — entity not found.
///
/// Separated from [ApiException] so callers can `catch (NotFoundException)`
/// and show contextual "not found" UI without inspecting status codes.
class NotFoundException extends ApiException {
  NotFoundException({required super.message}) : super(statusCode: 404);
}

/// HTTP 422 — Laravel validation error.
///
/// [fieldErrors] maps field names to their error messages, e.g.:
/// `{ "email": ["The email has already been taken."] }`
class ValidationException extends ApiException {
  final Map<String, List<String>> fieldErrors;

  ValidationException({
    required super.message,
    required this.fieldErrors,
  }) : super(statusCode: 422, errors: fieldErrors);

  factory ValidationException.fromBody(Map<String, dynamic> body) {
    final rawErrors = body['errors'];
    final Map<String, List<String>> parsed = {};

    if (rawErrors is Map<String, dynamic>) {
      for (final entry in rawErrors.entries) {
        final value = entry.value;
        if (value is List) {
          parsed[entry.key] = value.map((e) => e.toString()).toList();
        }
      }
    }

    return ValidationException(
      message: (body['message'] as String?) ?? 'Validasi gagal',
      fieldErrors: parsed,
    );
  }

  /// The first error message across all fields — useful for snackbars.
  String get firstError {
    for (final messages in fieldErrors.values) {
      if (messages.isNotEmpty) return messages.first;
    }
    return message;
  }
}
