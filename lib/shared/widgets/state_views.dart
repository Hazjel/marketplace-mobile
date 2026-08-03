import 'package:flutter/material.dart';
import 'package:blukios_marketplace/config/app_theme.dart';
import 'package:blukios_marketplace/shared/widgets/app_icon.dart';

/// Shown when a request succeeded but returned nothing.
///
/// Replaces the near-identical empty blocks that were copy-pasted across
/// the wishlist, search and category screens (each had drifted slightly).
class EmptyState extends StatelessWidget {
  final String icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingXL),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: isDark
                    ? AppTheme.darkIconBackground
                    : AppTheme.iconBackground,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: AppIcon(
                  icon,
                  size: 36,
                  color: isDark ? AppTheme.darkPrimary : AppTheme.primary,
                ),
              ),
            ),
            const SizedBox(height: AppTheme.spacingLG),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTheme.titleMd,
            ),
            if (message != null) ...[
              const SizedBox(height: AppTheme.spacingXS),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: AppTheme.bodyMd.copyWith(
                  color: isDark
                      ? AppTheme.darkTextSecondary
                      : AppTheme.textSecondary,
                ),
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: AppTheme.spacingLG),
              FilledButton(
                onPressed: onAction,
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Shown when a request failed. Always offers a retry — an error with no
/// recovery path is a dead end.
class ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const ErrorState({
    super.key,
    required this.message,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingXL),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AppIcon(
              AppIcons.alert,
              size: 44,
              color: AppTheme.error,
            ),
            const SizedBox(height: AppTheme.spacingMD),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTheme.bodyMd.copyWith(
                color:
                    isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: AppTheme.spacingLG),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const AppIcon(AppIcons.refresh, size: AppIconSize.md),
                label: const Text('Coba Lagi'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
