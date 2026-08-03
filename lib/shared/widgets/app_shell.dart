import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:blukios_marketplace/shared/widgets/app_bottom_nav.dart';
import 'package:blukios_marketplace/shared/widgets/app_icon.dart';

/// Hosts the five bottom-nav destinations.
///
/// Cart is deliberately not a tab — it lives as a header action with a
/// badge, which keeps the bar at five items.
class AppShell extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const AppShell({super.key, required this.navigationShell});

  static const _items = [
    BottomNavItem(
      icon: AppIcons.home,
      activeIcon: AppIcons.homeFilled,
      label: 'Home',
    ),
    BottomNavItem(
      icon: AppIcons.category,
      activeIcon: AppIcons.categoryFilled,
      label: 'Kategori',
    ),
    BottomNavItem(
      icon: AppIcons.transaction,
      activeIcon: AppIcons.transactionFilled,
      label: 'Transaksi',
    ),
    BottomNavItem(
      icon: AppIcons.heart,
      activeIcon: AppIcons.heartFilled,
      label: 'Wishlist',
    ),
    BottomNavItem(
      icon: AppIcons.user,
      activeIcon: AppIcons.userFilled,
      label: 'Akun',
    ),
  ];

  void _onTap(int index) {
    // `initialLocation: true` when re-tapping the active tab pops that
    // branch back to its root — the standard "tap the tab you're on to
    // go home" behaviour.
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: AppBottomNav(
        currentIndex: navigationShell.currentIndex,
        onTap: _onTap,
        items: _items,
      ),
    );
  }
}
