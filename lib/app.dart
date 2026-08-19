import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:blukios_marketplace/config/app_theme.dart';
import 'package:blukios_marketplace/config/routes.dart';
import 'package:blukios_marketplace/core/monitoring/notification_providers.dart';
import 'package:blukios_marketplace/core/monitoring/notification_service.dart';
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

    // A push notification tap (foreground, background, or cold-start) lands
    // here regardless of which screen the app happens to open on. Routes by
    // the backend's `type` field (see SendPushOnMessageSent /
    // SendPushOnTransactionStatusUpdated) — chat opens the sender's thread
    // directly, everything else falls back to the transaction list (no
    // per-transaction deep link yet, but it already shows live status via
    // Reverb so landing there is still useful).
    NotificationService.onNotificationTap.listen((data) {
      final router = ref.read(routerProvider);
      final senderId = data['sender_id'] as String?;
      if (data['type'] == 'chat' && senderId != null) {
        router.go(AppRoutes.chatThreadPath(senderId));
      } else {
        router.go(AppRoutes.transactions);
      }
    });
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
