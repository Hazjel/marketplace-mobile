import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:blukios_marketplace/core/network/api_exceptions.dart';
import 'package:blukios_marketplace/core/providers.dart';
import 'package:blukios_marketplace/core/storage/secure_storage.dart';
import 'package:blukios_marketplace/features/auth/data/auth_repository.dart';
import 'package:blukios_marketplace/features/auth/models/user_model.dart';
import 'package:blukios_marketplace/features/auth/viewmodels/auth_viewmodel.dart';

import '../../helpers/fake_secure_storage_platform.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late MockAuthRepository authRepository;
  late ProviderContainer container;

  final testUser = UserModel(id: '1', name: 'Budi', email: 'budi@test.com', role: 'buyer');

  setUp(() {
    FlutterSecureStoragePlatform.instance = FakeSecureStoragePlatform();
    authRepository = MockAuthRepository();
    container = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(authRepository)],
    );
  });

  tearDown(() => container.dispose());

  group('login', () {
    test('success updates state to authenticated with the returned user', () async {
      when(() => authRepository.login('budi@test.com', 'password123'))
          .thenAnswer((_) async => testUser);

      final ok = await container.read(authProvider.notifier).login('budi@test.com', 'password123');

      expect(ok, isTrue);
      final state = container.read(authProvider);
      expect(state.state, AuthState.authenticated);
      expect(state.currentUser, testUser);
      expect(state.isLoading, isFalse);
    });

    test('ApiException failure surfaces the message and stays unauthenticated', () async {
      when(() => authRepository.login('budi@test.com', 'wrong'))
          .thenThrow(ApiException(message: 'Email atau password salah'));

      final ok = await container.read(authProvider.notifier).login('budi@test.com', 'wrong');

      expect(ok, isFalse);
      final state = container.read(authProvider);
      expect(state.state, isNot(AuthState.authenticated));
      expect(state.errorMessage, 'Email atau password salah');
      expect(state.isLoading, isFalse);
    });
  });

  group('checkAuthStatus', () {
    test('no saved token -> unauthenticated', () async {
      await container.read(authProvider.notifier).checkAuthStatus();

      expect(container.read(authProvider).state, AuthState.unauthenticated);
    });

    test('saved token + successful /me -> authenticated', () async {
      await SecureStorage.saveToken('a-valid-token');
      when(() => authRepository.getProfile()).thenAnswer((_) async => testUser);

      await container.read(authProvider.notifier).checkAuthStatus();

      final state = container.read(authProvider);
      expect(state.state, AuthState.authenticated);
      expect(state.currentUser, testUser);
    });

    test('saved token + 401 from /me -> clears token, unauthenticated', () async {
      await SecureStorage.saveToken('an-expired-token');
      when(() => authRepository.getProfile())
          .thenThrow(ApiException(message: 'Unauthenticated', statusCode: 401));

      await container.read(authProvider.notifier).checkAuthStatus();

      expect(container.read(authProvider).state, AuthState.unauthenticated);
      expect(await SecureStorage.getToken(), isNull);
    });

    test(
      'saved token + non-401 error (e.g. timeout) does NOT clear the '
      'session or force unauthenticated — regression test for the '
      'network-hiccup-shouldn\'t-log-out fix',
      () async {
        await SecureStorage.saveToken('a-valid-token');
        when(() => authRepository.getProfile())
            .thenThrow(ApiException(message: 'Koneksi timeout, coba lagi'));

        await container.read(authProvider.notifier).checkAuthStatus();

        // Must NOT have been flipped to unauthenticated by a transient error.
        expect(container.read(authProvider).state, isNot(AuthState.unauthenticated));
        // The token must survive — a real bug this fix addressed was that
        // ANY exception used to wipe it, forcing a full re-login on the
        // next successful network attempt even though the session was
        // never actually invalid.
        expect(await SecureStorage.getToken(), 'a-valid-token');
      },
    );
  });

  group('logout', () {
    test('clears state', () async {
      when(() => authRepository.login(any(), any())).thenAnswer((_) async => testUser);
      await container.read(authProvider.notifier).login('budi@test.com', 'password123');
      when(() => authRepository.logout()).thenAnswer((_) async {});

      await container.read(authProvider.notifier).logout();

      final state = container.read(authProvider);
      expect(state.state, AuthState.unauthenticated);
      expect(state.currentUser, isNull);
    });
  });
}
