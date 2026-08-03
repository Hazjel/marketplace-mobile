import 'package:flutter/material.dart';
import 'package:blukios_marketplace/config/app_theme.dart';
import 'package:blukios_marketplace/shared/widgets/app_icon.dart';

class BottomNavItem {
  final String icon;
  final String activeIcon;
  final String label;

  const BottomNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}

/// Marketplace-style bottom navigation.
///
/// Hand-rolled rather than using M3 `NavigationBar` for two reasons: the
/// theme's `bottomNavigationBarTheme` doesn't apply to `NavigationBar`,
/// and we need outline→filled icon swapping per tab, which neither
/// built-in bar does with SVG assets.
///
/// Every item carries an icon *and* a text label — icon-only navigation
/// hurts discoverability.
class AppBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<BottomNavItem> items;

  /// Badge counts keyed by item index. Absent or zero renders nothing.
  final Map<int, int> badges;

  const AppBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
    this.badges = const {},
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final background = isDark ? AppTheme.darkCard : AppTheme.cardWhite;
    final activeColor = isDark ? AppTheme.darkPrimary : AppTheme.primary;
    final inactiveColor =
        isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary;

    return Container(
      decoration: BoxDecoration(
        color: background,
        border: Border(
          top: BorderSide(
            color: isDark ? AppTheme.darkBorder : AppTheme.border,
          ),
        ),
      ),
      // SafeArea keeps the bar clear of the gesture handle / home indicator.
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 60,
          child: Row(
            children: List.generate(items.length, (index) {
              final item = items[index];
              final isActive = index == currentIndex;
              final badgeCount = badges[index] ?? 0;

              return Expanded(
                child: _NavButton(
                  item: item,
                  isActive: isActive,
                  activeColor: activeColor,
                  inactiveColor: inactiveColor,
                  badgeCount: badgeCount,
                  onTap: () => onTap(index),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final BottomNavItem item;
  final bool isActive;
  final Color activeColor;
  final Color inactiveColor;
  final int badgeCount;
  final VoidCallback onTap;

  const _NavButton({
    required this.item,
    required this.isActive,
    required this.activeColor,
    required this.inactiveColor,
    required this.badgeCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isActive ? activeColor : inactiveColor;

    return Semantics(
      button: true,
      selected: isActive,
      label: item.label,
      child: InkWell(
        onTap: onTap,
        // Ripple is bounded to the item so it doesn't bleed across tabs.
        borderRadius: BorderRadius.circular(AppTheme.radiusLG),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                AppIcon(
                  isActive ? item.activeIcon : item.icon,
                  size: AppIconSize.lg,
                  color: color,
                ),
                if (badgeCount > 0)
                  Positioned(
                    top: -4,
                    right: -8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1,
                      ),
                      constraints: const BoxConstraints(minWidth: 17),
                      decoration: BoxDecoration(
                        color: AppTheme.error,
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusFull),
                      ),
                      child: Text(
                        badgeCount > 99 ? '99+' : '$badgeCount',
                        textAlign: TextAlign.center,
                        style: AppTheme.labelSm.copyWith(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              item.label,
              style: AppTheme.labelSm.copyWith(
                color: color,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
