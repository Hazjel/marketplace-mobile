import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:blukios_marketplace/app.dart';
import 'package:blukios_marketplace/core/monitoring/analytics_service.dart';
import 'package:blukios_marketplace/core/monitoring/client_error_reporter.dart';
import 'package:blukios_marketplace/core/monitoring/notification_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  runZonedGuarded(() async {
    // Crash handlers go in first and do not depend on Firebase: every crash
    // reaches the API (ops:check emails it) and, when Firebase is set up,
    // Crashlytics too.
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      ClientErrorReporter.report(
        details.exception,
        details.stack,
        context: details.context?.toDescription(),
      );
      AnalyticsService.recordFlutterError(details);
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      ClientErrorReporter.report(error, stack);
      AnalyticsService.recordError(error, stack, fatal: true);
      return true;
    };

    // Firebase.initializeApp() throws when google-services.json /
    // GoogleService-Info.plist is missing (iOS has none yet); the app must
    // run identically either way. AnalyticsService no-ops until it is up.
    try {
      await Firebase.initializeApp();
      AnalyticsService.markInitialized();
      await NotificationService.initialize();
    } catch (e, st) {
      debugPrint('Firebase not configured — Crashlytics/analytics disabled. $e');
      debugPrint('$st');
    }

    runApp(const ProviderScope(child: BlukiosApp()));
  }, (error, stack) {
    // Errors outside FlutterError's zone (e.g. from async gaps).
    ClientErrorReporter.report(error, stack);
    AnalyticsService.recordError(error, stack, fatal: true);
  });
}
