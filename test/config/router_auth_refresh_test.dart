import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:blukios_marketplace/config/routes.dart';
import 'package:blukios_marketplace/core/providers.dart';
import 'package:blukios_marketplace/core/storage/secure_storage.dart';
import 'package:blukios_marketplace/features/auth/data/auth_repository.dart';
import 'package:blukios_marketplace/features/auth/models/user_model.dart';
import 'package:blukios_marketplace/features/auth/screens/login_screen.dart';
import 'package:blukios_marketplace/features/auth/screens/splash_screen.dart';
import 'package:blukios_marketplace/features/auth/viewmodels/auth_viewmodel.dart';

import '../helpers/fake_secure_storage_platform.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

/// Regression test for the app being reported stuck on the splash screen
/// forever on a real device, across three separate "fixes" that all only
/// hardened `checkAuthStatus()` itself. Those fixes guarantee the auth
/// *state* resolves — this test checks the half nobody had verified: that
/// the router actually reacts to it and stops rendering [SplashScreen].
void main() {
  setUp(() {
    FlutterSecureStoragePlatform.instance = FakeSecureStoragePlatform();
  });

  testWidgets(
    'router leaves the splash screen once auth resolves to unauthenticated',
    (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: container.read(routerProvider),
          ),
        ),
      );
      await tester.pump();

      // Nothing has resolved the session yet -> splash, by design.
      expect(find.byType(SplashScreen), findsOneWidget);

      // No saved token, so this resolves synchronously to unauthenticated —
      // the exact state the retry/timeout fallbacks land on when the network
      // or the server is unreachable.
      await container.read(authProvider.notifier).checkAuthStatus();
      expect(container.read(authProvider).state, AuthState.unauthenticated);

      await tester.pumpAndSettle();

      // The router must have redirected to /login. If it hasn't, the app is
      // stuck on the splash screen regardless of the auth state being
      // correct — which is exactly the reported bug.
      expect(find.byType(SplashScreen), findsNothing);
      expect(find.byType(LoginScreen), findsOneWidget);
    },
  );

  testWidgets(
    'router leaves the splash screen once auth resolves to authenticated',
    (tester) async {
      final repo = MockAuthRepository();
      when(() => repo.getProfile()).thenAnswer(
        (_) async => UserModel(
          id: '1',
          name: 'Budi',
          email: 'budi@test.com',
          role: 'buyer',
        ),
      );

      final container = ProviderContainer(
        overrides: [authRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);

      await SecureStorage.saveToken('a-valid-token');

      // HomeScreen fires its own real Dio calls once it mounts; runAsync
      // lets those fail for real (connection refused) instead of leaving a
      // pending timer behind at teardown — same reasoning as widget_test.
      await tester.runAsync(() async {
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp.router(
              routerConfig: container.read(routerProvider),
            ),
          ),
        );
        await tester.pump();
        expect(find.byType(SplashScreen), findsOneWidget);

        await container.read(authProvider.notifier).checkAuthStatus();
        expect(container.read(authProvider).state, AuthState.authenticated);

        await tester.pump();
        await tester.pump();

        // Unlike the unauthenticated case there is no redirect here — the
        // user is already on the right route — so nothing *navigates*. If
        // the shell simply keeps the page it built on the first frame, the
        // splash screen stays on screen forever even though auth resolved
        // fine. This is the path a valid saved session takes, i.e. every
        // relaunch after a successful login.
        expect(find.byType(SplashScreen), findsNothing);
      });
    },
  );
}
