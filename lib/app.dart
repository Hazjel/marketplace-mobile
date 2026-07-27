import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:blukios_marketplace/config/app_theme.dart';
import 'package:blukios_marketplace/config/routes.dart';
import 'package:blukios_marketplace/core/network/api_client.dart';
import 'package:blukios_marketplace/features/address/data/address_repository.dart';
import 'package:blukios_marketplace/features/address/viewmodels/address_viewmodel.dart';
import 'package:blukios_marketplace/features/auth/data/auth_repository.dart';
import 'package:blukios_marketplace/features/auth/viewmodels/auth_viewmodel.dart';
import 'package:blukios_marketplace/features/cart/data/cart_repository.dart';
import 'package:blukios_marketplace/features/cart/viewmodels/cart_viewmodel.dart';
import 'package:blukios_marketplace/features/home/data/product_repository.dart';
import 'package:blukios_marketplace/features/home/viewmodels/home_viewmodel.dart';
import 'package:blukios_marketplace/features/transaction/data/transaction_repository.dart';
import 'package:blukios_marketplace/features/transaction/viewmodels/transaction_viewmodel.dart';

class BlukiosApp extends StatelessWidget {
  const BlukiosApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<ApiClient>(create: (_) => ApiClient()),
        ChangeNotifierProvider<AuthViewModel>(
          create: (ctx) => AuthViewModel(AuthRepository(ctx.read<ApiClient>()))..checkAuthStatus(),
        ),
        ChangeNotifierProvider<HomeViewModel>(
          create: (ctx) => HomeViewModel(ProductRepository(ctx.read<ApiClient>())),
        ),
        ChangeNotifierProvider<CartViewModel>(
          create: (ctx) => CartViewModel(CartRepository(ctx.read<ApiClient>())),
        ),
        ChangeNotifierProvider<TransactionViewModel>(
          create: (ctx) => TransactionViewModel(TransactionRepository(ctx.read<ApiClient>())),
        ),
        ChangeNotifierProvider<AddressViewModel>(
          create: (ctx) => AddressViewModel(AddressRepository(ctx.read<ApiClient>())),
        ),
      ],
      child: const _AppRouterView(),
    );
  }
}

class _AppRouterView extends StatefulWidget {
  const _AppRouterView();

  @override
  State<_AppRouterView> createState() => _AppRouterViewState();
}

class _AppRouterViewState extends State<_AppRouterView> {
  late final GoRouter _router = AppRoutes.build(context.read<AuthViewModel>());

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Blukios Marketplace',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      routerConfig: _router,
    );
  }
}
