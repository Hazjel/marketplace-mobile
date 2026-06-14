import 'package:flutter/material.dart';
import 'package:blukios_marketplace/core/utils/responsive.dart';

class ResponsiveBuilder extends StatelessWidget {
  final Widget phone;
  final Widget? tablet;
  final Widget? desktop;

  const ResponsiveBuilder({
    super.key,
    required this.phone,
    this.tablet,
    this.desktop,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= Responsive.desktopBreakpoint) {
          return desktop ?? tablet ?? phone;
        }
        if (constraints.maxWidth >= Responsive.phoneBreakpoint) {
          return tablet ?? phone;
        }
        return phone;
      },
    );
  }
}
