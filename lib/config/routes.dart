import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:blukios_marketplace/features/address/models/address_model.dart';
import 'package:blukios_marketplace/features/address/screens/address_form_screen.dart';
import 'package:blukios_marketplace/features/address/screens/address_list_screen.dart';
import 'package:blukios_marketplace/features/auth/screens/login_screen.dart';
import 'package:blukios_marketplace/features/auth/screens/register_screen.dart';
import 'package:blukios_marketplace/features/auth/viewmodels/auth_viewmodel.dart';
import 'package:blukios_marketplace/features/cart/models/cart_model.dart';
import 'package:blukios_marketplace/features/checkout/screens/checkout_screen.dart';
import 'package:blukios_marketplace/features/checkout/screens/payment_webview_screen.dart';
import 'package:blukios_marketplace/features/home/screens/home_screen.dart';
import 'package:blukios_marketplace/features/product/screens/product_detail_screen.dart';
import 'package:blukios_marketplace/features/cart/screens/cart_screen.dart';
import 'package:blukios_marketplace/features/transaction/screens/transaction_list_screen.dart';
import 'package:blukios_marketplace/features/search/screens/search_screen.dart';

class AppRoutes {
  static const String login = '/login';
  static const String register = '/register';
  static const String home = '/';
  static const String productDetail = '/product/:slug';
  static const String cart = '/cart';
  static const String transactions = '/transactions';
  static const String checkout = '/checkout';
  static const String payment = '/payment/:transactionId';
  static const String addresses = '/addresses';
  static const String addressForm = '/addresses/form';
  static const String search = '/search';

  static String productDetailPath(String slug) => '/product/$slug';
  static String paymentPath(String transactionId) => '/payment/$transactionId';

  static GoRouter build(Ref ref) {
    return GoRouter(
      initialLocation: home,
      refreshListenable: _AuthRefreshListenable(ref),
      redirect: (context, state) {
        final auth = ref.read(authProvider);
        if (auth.state == AuthState.unknown) return null;

        final isAuthenticated = auth.state == AuthState.authenticated;
        final isAuthRoute = state.matchedLocation == login || state.matchedLocation == register;

        if (!isAuthenticated && !isAuthRoute) return login;
        if (isAuthenticated && isAuthRoute) return home;

        // Seller routes are not part of the buyer build yet. When
        // lib/features/seller/ lands, gate it here on auth.currentUser?.role.
        return null;
      },
      routes: [
        GoRoute(
          path: login,
          builder: (context, state) => const LoginScreen(),
        ),
        GoRoute(
          path: register,
          builder: (context, state) => const RegisterScreen(),
        ),
        GoRoute(
          path: home,
          builder: (context, state) => const HomeScreen(),
        ),
        GoRoute(
          path: productDetail,
          builder: (context, state) => ProductDetailScreen(
            slug: state.pathParameters['slug'] ?? '',
          ),
        ),
        GoRoute(
          path: cart,
          builder: (context, state) => const CartScreen(),
        ),
        GoRoute(
          path: transactions,
          builder: (context, state) => const TransactionListScreen(),
        ),
        GoRoute(
          path: checkout,
          builder: (context, state) => CheckoutScreen(
            group: state.extra as CartGroupModel,
          ),
        ),
        GoRoute(
          path: payment,
          builder: (context, state) => PaymentWebviewScreen(
            transactionId: state.pathParameters['transactionId'] ?? '',
            snapToken: state.extra as String,
          ),
        ),
        GoRoute(
          path: addresses,
          builder: (context, state) => const AddressListScreen(),
        ),
        GoRoute(
          path: addressForm,
          builder: (context, state) => AddressFormScreen(
            existing: state.extra as AddressModel?,
          ),
        ),
        GoRoute(
          path: search,
          builder: (context, state) => SearchScreen(
            initialQuery: state.uri.queryParameters['q'],
          ),
        ),
      ],
    );
  }
}

/// Bridges Riverpod's auth state onto the [Listenable] GoRouter expects,
/// so a login/logout re-runs the redirect.
class _AuthRefreshListenable extends ChangeNotifier {
  _AuthRefreshListenable(Ref ref) {
    ref.listen<AuthData>(
      authProvider,
      (previous, next) {
        if (previous?.state != next.state) notifyListeners();
      },
    );
  }
}

final routerProvider = Provider<GoRouter>((ref) => AppRoutes.build(ref));
