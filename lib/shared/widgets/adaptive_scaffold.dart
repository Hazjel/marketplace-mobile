import 'package:flutter/material.dart';
import 'package:blukios_marketplace/core/utils/responsive.dart';
import 'package:blukios_marketplace/config/app_theme.dart';

class AdaptiveScaffold extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onIndexChanged;
  final List<Widget> pages;
  final List<AdaptiveDestination> destinations;

  const AdaptiveScaffold({
    super.key,
    required this.currentIndex,
    required this.onIndexChanged,
    required this.pages,
    required this.destinations,
  });

  @override
  Widget build(BuildContext context) {
    final isTablet = Responsive.isTablet(context);

    if (isTablet) {
      // Tablet: NavigationRail + Content
      return Scaffold(
        body: SafeArea(
          child: Row(
            children: [
              NavigationRail(
                selectedIndex: currentIndex,
                onDestinationSelected: onIndexChanged,
                labelType: NavigationRailLabelType.all,
                backgroundColor: Theme.of(context).cardColor,
                indicatorColor: AppTheme.primary.withOpacity(0.1),
                destinations: destinations
                    .map((d) => NavigationRailDestination(
                          icon: Icon(d.icon),
                          selectedIcon: Icon(d.selectedIcon ?? d.icon),
                          label: Text(d.label),
                        ))
                    .toList(),
              ),
              const VerticalDivider(width: 1, thickness: 1),
              Expanded(child: pages[currentIndex]),
            ],
          ),
        ),
      );
    }

    // Phone: BottomNavigationBar
    return Scaffold(
      body: pages[currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: onIndexChanged,
        destinations: destinations
            .map((d) => NavigationDestination(
                  icon: Icon(d.icon),
                  selectedIcon: Icon(d.selectedIcon ?? d.icon),
                  label: d.label,
                ))
            .toList(),
      ),
    );
  }
}

class AdaptiveDestination {
  final IconData icon;
  final IconData? selectedIcon;
  final String label;

  const AdaptiveDestination({
    required this.icon,
    this.selectedIcon,
    required this.label,
  });
}
