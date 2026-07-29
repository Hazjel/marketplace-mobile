import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:blukios_marketplace/config/app_theme.dart';
import 'package:blukios_marketplace/config/routes.dart';
import 'package:blukios_marketplace/features/auth/viewmodels/auth_viewmodel.dart';

class BlukiosApp extends ConsumerStatefulWidget {
  const BlukiosApp({super.key});

  @override
  ConsumerState<BlukiosApp> createState() => _BlukiosAppState();
}

class _BlukiosAppState extends ConsumerState<BlukiosApp> {
  @override
  void initState() {
    super.initState();
    // Restore the session before the first redirect runs; until this
    // resolves the router sees AuthState.unknown and holds its decision.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(authProvider.notifier).checkAuthStatus();
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Blukios Marketplace',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      routerConfig: ref.watch(routerProvider),
    );
  }
}
