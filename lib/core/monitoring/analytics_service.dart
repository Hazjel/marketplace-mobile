import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

/// Thin wrapper around Firebase Analytics + Crashlytics so feature code
/// never imports the Firebase SDK directly.
///
/// Firebase isn't provisioned yet — there's no `google-services.json` /
/// `GoogleService-Info.plist` in this repo (that needs an interactive
/// `flutterfire configure` run, a manual step outside this codebase's
/// control). Until that happens, [initialize] fails to set up Firebase and
/// every method here becomes a safe no-op instead of throwing — the app
/// must run identically with or without monitoring wired up. See
/// README.md's "Crash reporting & analytics" section for what's still
/// needed to actually activate this.
class AnalyticsService {
  static bool _initialized = false;

  /// Marks Firebase as available. Called once from `main.dart` after
  /// `Firebase.initializeApp()` succeeds — never call this directly.
  static void markInitialized() => _initialized = true;

  static Future<void> logEvent(String name, {Map<String, Object>? parameters}) async {
    if (!_initialized) return;
    try {
      await FirebaseAnalytics.instance.logEvent(name: name, parameters: parameters);
    } catch (e, st) {
      debugPrint('AnalyticsService.logEvent($name) failed: $e\n$st');
    }
  }

  static Future<void> logScreenView(String screenName) async {
    if (!_initialized) return;
    try {
      await FirebaseAnalytics.instance.logScreenView(screenName: screenName);
    } catch (e, st) {
      debugPrint('AnalyticsService.logScreenView($screenName) failed: $e\n$st');
    }
  }

  /// Records a non-fatal or fatal error to Crashlytics. Safe to call from
  /// anywhere — no-ops if Firebase never initialized.
  static void recordError(Object error, StackTrace? stack, {bool fatal = false}) {
    if (!_initialized) return;
    try {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: fatal);
    } catch (e, st) {
      debugPrint('AnalyticsService.recordError failed: $e\n$st');
    }
  }
}
