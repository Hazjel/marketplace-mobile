import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:blukios_marketplace/config/app_theme.dart';
import 'package:blukios_marketplace/shared/widgets/app_icon.dart';

/// Standard screen chrome.
///
/// Screens used to each hand-roll their own `Scaffold` + `AppBar`, which
/// drifted (different title weights, some centered, some not). This owns
/// that decision once.
///
/// Set [isTabRoot] on bottom-nav destinations — they get no back button,
/// since there is nothing to pop back to.
class AppScaffold extends StatelessWidget {
  final String? title;
  final Widget? titleWidget;
  final List<Widget>? actions;
  final Widget body;
  final Widget? bottomBar;
  final Widget? floatingActionButton;
  final bool isTabRoot;
  final bool showAppBar;
  final Color? backgroundColor;

  const AppScaffold({
    super.key,
    this.title,
    this.titleWidget,
    this.actions,
    required this.body,
    this.bottomBar,
    this.floatingActionButton,
    this.isTabRoot = false,
    this.showAppBar = true,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final canPop = !isTabRoot && context.canPop();

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: !showAppBar
          ? null
          : AppBar(
              centerTitle: false,
              titleSpacing: canPop ? 0 : 20,
              automaticallyImplyLeading: false,
              leading: canPop
                  ? IconButton(
                      onPressed: () => context.pop(),
                      icon: const AppIcon(
                        AppIcons.chevronLeft,
                        size: AppIconSize.lg,
                        semanticsLabel: 'Kembali',
                      ),
                    )
                  : null,
              title: titleWidget ??
                  (title == null ? null : Text(title!, style: AppTheme.titleLg)),
              actions: actions,
            ),
      body: body,
      bottomNavigationBar: bottomBar,
      floatingActionButton: floatingActionButton,
    );
  }
}
