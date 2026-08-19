import 'dart:async';
import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Must be top-level (not a class method) — firebase_messaging invokes this
/// in a separate isolate when a push arrives while the app is backgrounded
/// or terminated. It doesn't need to do anything: Android already shows the
/// system tray notification for a message that has a "notification" block
/// (which is all the backend can send today, since push-sending itself
/// isn't wired up yet — see DeviceTokenController's doc comment). This
/// handler only needs to exist because firebase_messaging requires one to
/// be registered before pushes work at all.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('FCM background message: ${message.messageId}');
}

/// Thin wrapper around Firebase Messaging + local-notifications display, so
/// feature code never touches either SDK directly.
///
/// Same tolerance pattern as [AnalyticsService]: every step here is
/// try/caught and gated behind [_initialized], so a platform without a
/// Firebase config file (iOS has none yet — see README.md) or a device that
/// denies notification permission degrades to a safe no-op rather than
/// crashing anything.
class NotificationService {
  static bool _initialized = false;
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'high_importance_channel', // must match AndroidManifest.xml's default_notification_channel_id
    'Notifikasi Penting',
    description: 'Update pesanan, pesan chat, dan info penting lainnya',
    importance: Importance.high,
  );

  /// Broadcasts the `data` payload of a push whenever the user taps it —
  /// whether the app was in the foreground, backgrounded, or launched fresh
  /// from a terminated state by the tap. Feature code (app.dart) listens to
  /// this to decide where to navigate, rather than NotificationService
  /// knowing about routes itself.
  static final StreamController<Map<String, dynamic>> _tapController =
      StreamController<Map<String, dynamic>>.broadcast();
  static Stream<Map<String, dynamic>> get onNotificationTap => _tapController.stream;

  static bool get isInitialized => _initialized;

  /// Call once from main.dart, after `Firebase.initializeApp()` succeeds.
  static Future<void> initialize() async {
    try {
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_channel);

      await _localNotifications.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        ),
        onDidReceiveNotificationResponse: (response) {
          final payload = response.payload;
          if (payload == null || payload.isEmpty) return;
          try {
            final decoded = jsonDecode(payload);
            if (decoded is Map) {
              _tapController.add(Map<String, dynamic>.from(decoded));
            }
          } catch (e) {
            debugPrint('NotificationService: failed to decode tap payload: $e');
          }
        },
      );

      // Without this, Android silently drops in-foreground pushes (no
      // system tray banner) since the app is assumed to handle them itself
      // — which onMessage.listen below now does via _showForegroundNotification.
      await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      FirebaseMessaging.onMessage.listen(_showForegroundNotification);
      FirebaseMessaging.onMessageOpenedApp.listen((message) {
        _tapController.add(message.data);
      });

      // Cold-start case: app was fully closed, user tapped the push to open it.
      final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
      if (initialMessage != null) {
        _tapController.add(initialMessage.data);
      }

      _initialized = true;
    } catch (e, st) {
      debugPrint('NotificationService.initialize failed: $e\n$st');
    }
  }

  static void _showForegroundNotification(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;

    _localNotifications.show(
      notification.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      // Whole data payload, not just one field — the tap handler above
      // needs `type` to know whether this is a chat or transaction push
      // before it can decide which id field is even relevant.
      payload: message.data.isEmpty ? null : jsonEncode(message.data),
    );
  }

  /// Null if not initialized, permission was denied, or the platform has no
  /// Firebase config — callers must handle null gracefully (skip
  /// registering with the backend, don't retry in a loop).
  static Future<String?> getToken() async {
    if (!_initialized) return null;
    try {
      return await FirebaseMessaging.instance.getToken();
    } catch (e) {
      debugPrint('NotificationService.getToken failed: $e');
      return null;
    }
  }

  /// Empty (never-emitting) stream when not initialized — matches every
  /// other method here in never touching the Firebase plugin channel
  /// unless [initialize] actually succeeded (e.g. widget tests, where no
  /// platform channels are registered at all).
  static Stream<String> get onTokenRefresh {
    if (!_initialized) return const Stream.empty();
    try {
      return FirebaseMessaging.instance.onTokenRefresh;
    } catch (e) {
      debugPrint('NotificationService.onTokenRefresh failed: $e');
      return const Stream.empty();
    }
  }
}
