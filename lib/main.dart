import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:blukios_marketplace/app.dart';
import 'package:blukios_marketplace/core/monitoring/analytics_service.dart';
import 'package:blukios_marketplace/core/monitoring/notification_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase isn't provisioned yet (no google-services.json /
  // GoogleService-Info.plist — see README.md). Firebase.initializeApp()
  // throws when those config files are missing; catching it here means the
  // app runs identically either way instead of failing to start. Once the
  // config files land, this same code activates crash reporting/analytics
  // automatically — no further changes needed.
  runZonedGuarded(() async {
    try {
      await Firebase.initializeApp();
      AnalyticsService.markInitialized();
      await NotificationService.initialize();

      FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
      PlatformDispatcher.instance.onError = (error, stack) {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
        return true;
      };
    } catch (e, st) {
      debugPrint('Firebase not configured yet — crash reporting/analytics disabled. $e');
      debugPrint('$st');
    }

    runApp(const ProviderScope(child: BlukiosApp()));
  }, (error, stack) {
    // Catches errors outside FlutterError's zone (e.g. from async gaps) —
    // AnalyticsService itself no-ops if Firebase never initialized, so this
    // is safe to call unconditionally.
    AnalyticsService.recordError(error, stack, fatal: true);
  });
}
