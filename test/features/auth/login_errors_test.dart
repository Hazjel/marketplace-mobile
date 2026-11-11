import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:blukios_marketplace/core/network/api_client.dart';
import 'package:blukios_marketplace/core/network/api_exceptions.dart';
import 'package:blukios_marketplace/core/providers.dart';
import 'package:blukios_marketplace/features/auth/data/auth_repository.dart';
import 'package:blukios_marketplace/features/auth/screens/login_screen.dart';

class MockApiClient extends Mock implements ApiClient {}

/// What `ApiClient` throws when Dio fails: the same mapping, without a server.
ApiException _failure(DioExceptionType type, {int? status, Object? body}) {
  final options = RequestOptions(path: '/login');
  return ApiException.fromDioError(DioException(
    requestOptions: options,
    type: type,
    response: status == null
        ? null
        : Response(requestOptions: options, statusCode: status, data: body),
  ));
}

void main() {
  late MockApiClient api;

  setUp(() => api = MockApiClient());

  Future<void> submitLogin(WidgetTester tester, ApiException failure) async {
    when(() => api.post(any(), data: any(named: 'data'))).thenThrow(failure);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [authRepositoryProvider.overrideWithValue(AuthRepository(api))],
        child: const MaterialApp(home: LoginScreen()),
      ),
    );
    await tester.enterText(find.widgetWithText(TextFormField, 'Email'), 'buyer@example.test');
    await tester.enterText(find.widgetWithText(TextFormField, 'Password'), 'wrong-password');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Masuk'));
    await tester.pumpAndSettle();
  }

  testWidgets('401 shows the API message', (tester) async {
    await submitLogin(
      tester,
      _failure(DioExceptionType.badResponse,
          status: 401, body: {'success': false, 'message': 'Email atau password salah.'}),
    );

    expect(find.text('Email atau password salah.'), findsOneWidget);
  });

  testWidgets('422 shows the first field error, not the generic "Validasi gagal"', (tester) async {
    await submitLogin(
      tester,
      _failure(DioExceptionType.badResponse, status: 422, body: {
        'success': false,
        'message': 'Validasi gagal',
        'errors': {
          'email': ['Email wajib diisi.'],
          'password': ['Kata Sandi wajib diisi.'],
        },
      }),
    );

    expect(find.text('Email wajib diisi.'), findsOneWidget);
    expect(find.text('Validasi gagal'), findsNothing);
  });

  testWidgets('a connection error shows the connection message', (tester) async {
    await submitLogin(tester, _failure(DioExceptionType.connectionError));

    expect(find.text('Tidak ada koneksi internet'), findsOneWidget);
  });

  testWidgets('a 5xx keeps the server message', (tester) async {
    await submitLogin(
      tester,
      _failure(DioExceptionType.badResponse,
          status: 500, body: {'success': false, 'message': 'Terjadi kesalahan pada server.'}),
    );

    expect(find.text('Terjadi kesalahan pada server.'), findsOneWidget);
  });
}
