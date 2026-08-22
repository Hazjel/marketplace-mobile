import 'dart:async';

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

import '../helpers/fake_secure_storage_platform.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

/// The reported bug is "app sits on the splash screen forever". The splash
/// screen is shown for exactly one reason: `AuthState.unknown`. So the only
/// thing that can cause it is `checkAuthStatus()` never resolving the state.
///
/// These tests pin down that it always resolves, including under the
/// pathological case the earlier fixes were aimed at: a `/me` call that
/// hangs forever rather than failing.
void main() {
  setUp(() {
    FlutterSecureStoragePlatform.instance = FakeSecureStoragePlatform();
  });

  testWidgets(
    'a /me request that never completes still resolves auth state',
    (tester) async {
      final repo = MockAuthRepository();
      // Never completes — no error, no value. This is what a stalled
      // connection looks like to Dart, and what every earlier "fix" assumed
      // could not happen.
      when(() => repo.getProfile()).thenAnswer((_) => Completer<UserModel>().future);

      final container = ProviderContainer(
        overrides: [authRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);

      await SecureStorage.saveToken('a-saved-token');

      unawaited(container.read(authProvider.notifier).checkAuthStatus());

      expect(container.read(authProvider).state, AuthState.unknown);

      // Total bound: 3 attempts x 10s timeout + 0.4s + 0.8s backoff.
      await tester.pump(const Duration(seconds: 40));
      await tester.pump();

      expect(
        container.read(authProvider).state,
        AuthState.unauthenticated,
        reason: 'state must resolve even when the request never completes; '
            'staying `unknown` is what pins the app to the splash screen',
      );
    },
  );

  testWidgets(
    'a secure-storage read that never completes still resolves auth state',
    (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      FlutterSecureStoragePlatform.instance = _HangingSecureStoragePlatform();

      unawaited(container.read(authProvider.notifier).checkAuthStatus());
      expect(container.read(authProvider).state, AuthState.unknown);

      await tester.pump(const Duration(seconds: 10));
      await tester.pump();

      expect(
        container.read(authProvider).state,
        AuthState.unauthenticated,
        reason: 'a hung keystore read must not pin the app to the splash '
            'screen either',
      );
    },
  );

  testWidgets(
    'a 401 whose token wipe never completes still resolves auth state',
    (tester) async {
      final repo = MockAuthRepository();
      // An expired/revoked saved token — the single most likely thing to
      // happen to a session that has been sitting on a device for weeks,
      // and the branch that calls SecureStorage.clearAll().
      when(() => repo.getProfile())
          .thenThrow(ApiException(message: 'Unauthenticated', statusCode: 401));

      final container = ProviderContainer(
        overrides: [authRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);

      // Only the *wipe* hangs; the read that precedes it works fine — so
      // install the platform first, then seed the token through it.
      FlutterSecureStoragePlatform.instance = _HangingDeleteAllPlatform();
      await SecureStorage.saveToken('an-expired-token');
      expect(await SecureStorage.getToken(), 'an-expired-token');

      unawaited(container.read(authProvider.notifier).checkAuthStatus());
      await tester.pump(const Duration(seconds: 40));
      await tester.pump();

      expect(
        container.read(authProvider).state,
        AuthState.unauthenticated,
        reason: 'SecureStorage.clearAll() swallows errors but can still '
            'never complete — awaiting it unbounded on the 401 path leaves '
            'the state at `unknown`, i.e. splash screen forever',
      );
    },
  );
}

/// Simulates the Android keystore deadlock class of bug: the platform
/// channel call is made and simply never comes back.
class _HangingSecureStoragePlatform extends FakeSecureStoragePlatform {
  @override
  Future<String?> read({
    required String key,
    required Map<String, String> options,
  }) =>
      Completer<String?>().future;
}

class _HangingDeleteAllPlatform extends FakeSecureStoragePlatform {
  @override
  Future<void> deleteAll({required Map<String, String> options}) =>
      Completer<void>().future;
}
