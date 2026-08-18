import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:blukios_marketplace/core/monitoring/notification_service.dart';
import 'package:blukios_marketplace/core/providers.dart';
import 'package:blukios_marketplace/features/auth/viewmodels/auth_viewmodel.dart';

/// Keeps the backend's device_tokens table in sync with auth state — same
/// shape as `chatRealtimeProvider`: watched once from app.dart for the
/// app's whole lifetime, reacts to sign-in/sign-out rather than being
/// called explicitly from login/logout screens.
///
/// On sign-in: fetches the FCM token (null if notifications were never
/// initialized/permitted — silently skipped, not retried in a loop) and
/// registers it. On sign-out: unregisters that same token, so a shared or
/// reused device doesn't keep receiving another account's pushes.
final pushNotificationRealtimeProvider = Provider<void>((ref) {
  ref.listen<AuthData>(authProvider, (previous, next) async {
    final repo = ref.read(deviceTokenRepositoryProvider);

    if (next.state == AuthState.authenticated &&
        previous?.state != AuthState.authenticated) {
      final token = await NotificationService.getToken();
      if (token == null) return;
      try {
        await repo.register(token);
      } catch (e) {
        debugPrint('Failed to register device token: $e');
      }
      return;
    }

    if (next.state == AuthState.unauthenticated &&
        previous?.state == AuthState.authenticated) {
      final token = await NotificationService.getToken();
      if (token == null) return;
      try {
        await repo.unregister(token);
      } catch (e) {
        debugPrint('Failed to unregister device token: $e');
      }
    }
  });

  // A token can rotate at any time (app reinstall, OS-level refresh) —
  // re-register on the same active session so pushes don't silently die.
  NotificationService.onTokenRefresh.listen((token) async {
    if (ref.read(authProvider).state != AuthState.authenticated) return;
    try {
      await ref.read(deviceTokenRepositoryProvider).register(token);
    } catch (e) {
      debugPrint('Failed to re-register refreshed device token: $e');
    }
  });
});
