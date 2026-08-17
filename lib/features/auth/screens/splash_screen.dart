import 'package:flutter/material.dart';
import 'package:blukios_marketplace/config/app_theme.dart';
import 'package:blukios_marketplace/shared/widgets/app_icon.dart';

/// Shown at startup while the saved session is still being validated
/// (`AuthState.unknown`), so the router never lets a real screen flash
/// underneath before it knows whether to redirect to `/login`. Transient —
/// normally visible for well under a second — so kept intentionally minimal.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const AppIcon(
              AppIcons.store,
              size: 56,
              color: AppTheme.primary,
            ),
            const SizedBox(height: 16),
            const Text(
              'Blukios',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
