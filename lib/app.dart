import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:blukios_marketplace/config/app_theme.dart';
import 'package:blukios_marketplace/config/routes.dart';
import 'package:blukios_marketplace/core/monitoring/client_error_reporter.dart';
import 'package:blukios_marketplace/core/monitoring/notification_providers.dart';
import 'package:blukios_marketplace/core/monitoring/notification_service.dart';
import 'package:blukios_marketplace/core/monitoring/push_route.dart';
import 'package:blukios_marketplace/core/providers.dart';
import 'package:blukios_marketplace/features/auth/viewmodels/auth_viewmodel.dart';
import 'package:blukios_marketplace/features/chat/viewmodels/chat_viewmodel.dart';
import 'package:blukios_marketplace/features/wishlist/viewmodels/wishlist_viewmodel.dart';

class BlukiosApp extends ConsumerStatefulWidget {
  const BlukiosApp({super.key});

  @override
  ConsumerState<BlukiosApp> createState() => _BlukiosAppState();
}

class _BlukiosAppState extends ConsumerState<BlukiosApp> {
  @override
  void initState() {
    super.initState();
    // Restore the session before the first redirect runs; until this
    // resolves the router sees AuthState.unknown and holds its decision.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(authProvider.notifier).checkAuthStatus();
      final initialTap = NotificationService.takeInitialTap();
      if (initialTap != null) _openPush(initialTap);
    });

    // Preload wishlist membership once per session as soon as we know the
    // user is authenticated, so heart icons on product cards render correct
    // state on first paint instead of only after visiting the wishlist tab.
    ref.listenManual<AuthData>(authProvider, (previous, next) {
      final justAuthenticated = previous?.state != AuthState.authenticated &&
          next.state == AuthState.authenticated;
      if (justAuthenticated) {
        ref.read(wishlistProvider.notifier).loadWishlist();
      }
    });

    // Push taps while the app runs (foreground or background); the
    // cold-start tap is picked up above once the first frame is out.
    NotificationService.onNotificationTap.listen(_openPush);
  }

  /// Routes by the backend's `type` field (see SendPushOnMessageSent /
  /// SendPushOnTransactionStatusUpdated) via [pushTarget]. Never throws:
  /// it runs unawaited from the tap stream and the cold-start callback.
  Future<void> _openPush(Map<String, dynamic> data) async {
    try {
      final route = await pushTarget(
        data,
        settledAuth: _settledAuth,
        currentAuth: () => ref.read(authProvider),
        transactionStoreId: (id) async =>
            (await ref.read(transactionRepositoryProvider).getTransactionDetail(id)).storeId,
        // A `store`-role user with no store, or a failed fetch, lands on
        // the buyer list — intentional (see transactionPushRoute).
        myStoreId: () async => (await ref.read(sellerStoreRepositoryProvider).getMyStore())?.id,
      );
      if (route != null && mounted) ref.read(routerProvider).go(route);
    } catch (e, st) {
      ClientErrorReporter.report(e, st, context: 'push tap');
    }
  }

  /// On a cold start the session is still being restored when the tap
  /// arrives; where it may go is only known after that.
  Future<AuthData> _settledAuth() async {
    final current = ref.read(authProvider);
    if (current.state != AuthState.unknown) return current;
    final settled = Completer<AuthData>();
    final sub = ref.listenManual<AuthData>(authProvider, (_, next) {
      if (next.state != AuthState.unknown && !settled.isCompleted) settled.complete(next);
    });
    try {
      return await settled.future;
    } finally {
      sub.close();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Keeps the chat websocket alive for the app's lifetime; it connects
    // and tears itself down as auth state changes.
    ref.watch(chatRealtimeProvider);
    // Keeps the backend's device_tokens table in sync with sign-in/sign-out.
    ref.watch(pushNotificationRealtimeProvider);

    return MaterialApp.router(
      title: 'Blukios Marketplace',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      routerConfig: ref.watch(routerProvider),
    );
  }
}
