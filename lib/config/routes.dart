import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:blukios_marketplace/features/account/screens/account_screen.dart';
import 'package:blukios_marketplace/features/account/screens/edit_profile_screen.dart';
import 'package:blukios_marketplace/features/account/screens/settings_screen.dart';
import 'package:blukios_marketplace/features/address/models/address_model.dart';
import 'package:blukios_marketplace/features/address/screens/address_form_screen.dart';
import 'package:blukios_marketplace/features/address/screens/address_list_screen.dart';
import 'package:blukios_marketplace/features/auth/screens/login_screen.dart';
import 'package:blukios_marketplace/features/auth/screens/register_screen.dart';
import 'package:blukios_marketplace/features/auth/viewmodels/auth_viewmodel.dart';
import 'package:blukios_marketplace/features/cart/models/cart_model.dart';
import 'package:blukios_marketplace/features/cart/screens/cart_screen.dart';
import 'package:blukios_marketplace/features/category/screens/category_browse_screen.dart';
import 'package:blukios_marketplace/features/chat/screens/chat_list_screen.dart';
import 'package:blukios_marketplace/features/chat/screens/chat_thread_screen.dart';
import 'package:blukios_marketplace/features/dashboard/screens/dashboard_screen.dart';
import 'package:blukios_marketplace/features/checkout/screens/checkout_screen.dart';
import 'package:blukios_marketplace/features/checkout/screens/payment_webview_screen.dart';
import 'package:blukios_marketplace/features/home/screens/home_screen.dart';
import 'package:blukios_marketplace/features/product/screens/product_detail_screen.dart';
import 'package:blukios_marketplace/features/review/screens/review_form_screen.dart';
import 'package:blukios_marketplace/features/search/screens/search_screen.dart';
import 'package:blukios_marketplace/features/seller/dashboard/screens/seller_dashboard_screen.dart';
import 'package:blukios_marketplace/features/seller/orders/screens/seller_order_detail_screen.dart';
import 'package:blukios_marketplace/features/seller/orders/screens/seller_order_list_screen.dart';
import 'package:blukios_marketplace/features/seller/product/models/seller_product_model.dart';
import 'package:blukios_marketplace/features/seller/product/screens/seller_product_form_screen.dart';
import 'package:blukios_marketplace/features/seller/product/screens/seller_product_list_screen.dart';
import 'package:blukios_marketplace/features/seller/store/screens/seller_onboarding_screen.dart';
import 'package:blukios_marketplace/features/seller/store/screens/seller_store_profile_screen.dart';
import 'package:blukios_marketplace/features/seller/wallet/models/seller_wallet_model.dart';
import 'package:blukios_marketplace/features/seller/wallet/screens/seller_wallet_screen.dart';
import 'package:blukios_marketplace/features/seller/wallet/screens/withdrawal_form_screen.dart';
import 'package:blukios_marketplace/features/store/screens/store_detail_screen.dart';
import 'package:blukios_marketplace/features/transaction/screens/transaction_list_screen.dart';
import 'package:blukios_marketplace/features/wishlist/screens/wishlist_screen.dart';
import 'package:blukios_marketplace/shared/widgets/app_shell.dart';

class AppRoutes {
  // Auth (outside the shell)
  static const String login = '/login';
  static const String register = '/register';

  // Bottom-nav destinations
  static const String home = '/';
  static const String categories = '/categories';
  static const String transactions = '/transactions';
  static const String wishlist = '/wishlist';
  static const String account = '/account';

  // Pushed over the shell — deliberately full-screen so a bottom bar
  // can't invite mis-taps mid-checkout.
  static const String productDetail = '/product/:slug';
  static const String cart = '/cart';
  static const String checkout = '/checkout';
  static const String payment = '/payment/:transactionId';
  static const String addresses = '/addresses';
  static const String addressForm = '/addresses/form';
  static const String search = '/search';
  static const String editProfile = '/account/edit';
  static const String notificationSettings = '/account/notifications';
  static const String privacySettings = '/account/privacy';
  static const String storeDetail = '/store/:username';
  static const String dashboard = '/account/dashboard';
  static const String chatList = '/chat';
  static const String chatThread = '/chat/:partnerId';
  static const String reviewForm = '/review/:transactionId/:productId';

  // Seller Centre — full-screen pushes from the "Toko Saya"/"Jualan"
  // section on AccountScreen, gated by role in the redirect callback below.
  // Deliberately not a bottom-nav tab: a buyer can also be a seller, so
  // switching "modes" is a deliberate navigation, not a persistent tab.
  static const String sellerOnboarding = '/seller/onboarding';
  static const String sellerStoreProfile = '/seller/store';
  static const String sellerProducts = '/seller/products';
  static const String sellerProductForm = '/seller/products/form';
  static const String sellerOrders = '/seller/orders';
  static const String sellerOrderDetail = '/seller/orders/:id';
  static const String sellerDashboard = '/seller/dashboard';
  static const String sellerWallet = '/seller/wallet';
  static const String sellerWalletWithdraw = '/seller/wallet/withdraw';

  static String productDetailPath(String slug) => '/product/$slug';
  static String paymentPath(String transactionId) => '/payment/$transactionId';
  static String storeDetailPath(String username) => '/store/$username';
  static String chatThreadPath(String partnerId) => '/chat/$partnerId';
  static String reviewFormPath(String transactionId, String productId) =>
      '/review/$transactionId/$productId';
  static String sellerOrderDetailPath(String id) => '/seller/orders/$id';

  static final _rootNavigatorKey = GlobalKey<NavigatorState>();

  static GoRouter build(Ref ref) {
    return GoRouter(
      navigatorKey: _rootNavigatorKey,
      initialLocation: home,
      refreshListenable: _AuthRefreshListenable(ref),
      redirect: (context, state) {
        final auth = ref.read(authProvider);
        if (auth.state == AuthState.unknown) return null;

        final isAuthenticated = auth.state == AuthState.authenticated;
        final isAuthRoute =
            state.matchedLocation == login || state.matchedLocation == register;

        if (!isAuthenticated && !isAuthRoute) return login;
        if (isAuthenticated && isAuthRoute) return home;

        // Seller Centre: onboarding is for buyers becoming a seller, every
        // other /seller/* route needs an existing store. Cross-navigating
        // either way bounces to the right one instead of erroring.
        final isSellerRoute = state.matchedLocation.startsWith('/seller/');
        final isSeller = auth.currentUser?.role == 'store';
        if (isSellerRoute) {
          final isOnboarding = state.matchedLocation == sellerOnboarding;
          if (isOnboarding && isSeller) return sellerStoreProfile;
          if (!isOnboarding && !isSeller) return sellerOnboarding;
        }

        return null;
      },
      routes: [
        GoRoute(path: login, builder: (_, __) => const LoginScreen()),
        GoRoute(path: register, builder: (_, __) => const RegisterScreen()),

        // Five-tab shell. `indexedStack` keeps each branch's navigation
        // stack and scroll position alive across tab switches.
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) =>
              AppShell(navigationShell: navigationShell),
          branches: [
            StatefulShellBranch(
              routes: [GoRoute(path: home, builder: (_, __) => const HomeScreen())],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: categories,
                  builder: (_, __) => const CategoryBrowseScreen(),
                )
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: transactions,
                  builder: (_, __) => const TransactionListScreen(),
                )
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: wishlist,
                  builder: (_, __) => const WishlistScreen(),
                )
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: account,
                  builder: (_, __) => const AccountScreen(),
                )
              ],
            ),
          ],
        ),

        // Full-screen pushes — parentNavigatorKey lifts them above the
        // shell so the bottom bar is hidden.
        GoRoute(
          path: productDetail,
          parentNavigatorKey: _rootNavigatorKey,
          builder: (context, state) => ProductDetailScreen(
            slug: state.pathParameters['slug'] ?? '',
          ),
        ),
        GoRoute(
          path: cart,
          parentNavigatorKey: _rootNavigatorKey,
          builder: (_, __) => const CartScreen(),
        ),
        GoRoute(
          path: checkout,
          parentNavigatorKey: _rootNavigatorKey,
          builder: (context, state) =>
              CheckoutScreen(group: state.extra as CartGroupModel),
        ),
        GoRoute(
          path: payment,
          parentNavigatorKey: _rootNavigatorKey,
          builder: (context, state) => PaymentWebviewScreen(
            transactionId: state.pathParameters['transactionId'] ?? '',
            snapToken: state.extra as String,
          ),
        ),
        GoRoute(
          path: addresses,
          parentNavigatorKey: _rootNavigatorKey,
          builder: (_, __) => const AddressListScreen(),
        ),
        GoRoute(
          path: addressForm,
          parentNavigatorKey: _rootNavigatorKey,
          builder: (context, state) =>
              AddressFormScreen(existing: state.extra as AddressModel?),
        ),
        GoRoute(
          path: search,
          parentNavigatorKey: _rootNavigatorKey,
          builder: (context, state) {
            final extra = state.extra;
            final categoryArgs = extra is Map ? extra : const {};
            return SearchScreen(
              initialQuery: state.uri.queryParameters['q'],
              initialCategoryId: categoryArgs['categoryId'] as String?,
              initialCategoryName: categoryArgs['categoryName'] as String?,
            );
          },
        ),
        GoRoute(
          path: editProfile,
          parentNavigatorKey: _rootNavigatorKey,
          builder: (_, __) => const EditProfileScreen(),
        ),
        GoRoute(
          path: notificationSettings,
          parentNavigatorKey: _rootNavigatorKey,
          builder: (_, __) =>
              const SettingsScreen(group: SettingsGroup.notification),
        ),
        GoRoute(
          path: privacySettings,
          parentNavigatorKey: _rootNavigatorKey,
          builder: (_, __) =>
              const SettingsScreen(group: SettingsGroup.privacy),
        ),
        GoRoute(
          path: dashboard,
          parentNavigatorKey: _rootNavigatorKey,
          builder: (_, __) => const DashboardScreen(),
        ),
        GoRoute(
          path: storeDetail,
          parentNavigatorKey: _rootNavigatorKey,
          builder: (context, state) => StoreDetailScreen(
            username: state.pathParameters['username'] ?? '',
          ),
        ),
        // Declared before /chat/:partnerId so the literal list route
        // isn't swallowed by the parameterised one.
        GoRoute(
          path: chatList,
          parentNavigatorKey: _rootNavigatorKey,
          builder: (_, __) => const ChatListScreen(),
        ),
        GoRoute(
          path: chatThread,
          parentNavigatorKey: _rootNavigatorKey,
          builder: (context, state) => ChatThreadScreen(
            partnerId: state.pathParameters['partnerId'] ?? '',
          ),
        ),
        GoRoute(
          path: reviewForm,
          parentNavigatorKey: _rootNavigatorKey,
          builder: (context, state) {
            final extra = state.extra;
            final args = extra is Map ? extra : const {};
            return ReviewFormScreen(
              transactionId: state.pathParameters['transactionId'] ?? '',
              productId: state.pathParameters['productId'] ?? '',
              productName: args['productName'] as String? ?? 'Produk',
              productThumbnail: args['productThumbnail'] as String?,
            );
          },
        ),
        GoRoute(
          path: sellerOnboarding,
          parentNavigatorKey: _rootNavigatorKey,
          builder: (_, __) => const SellerOnboardingScreen(),
        ),
        GoRoute(
          path: sellerStoreProfile,
          parentNavigatorKey: _rootNavigatorKey,
          builder: (_, __) => const SellerStoreProfileScreen(),
        ),
        GoRoute(
          path: sellerProducts,
          parentNavigatorKey: _rootNavigatorKey,
          builder: (_, __) => const SellerProductListScreen(),
        ),
        GoRoute(
          path: sellerProductForm,
          parentNavigatorKey: _rootNavigatorKey,
          builder: (context, state) => SellerProductFormScreen(
            existing: state.extra as SellerProductModel?,
          ),
        ),
        // Seller order management — see the constants above for why these
        // aren't part of the bottom-nav shell yet.
        GoRoute(
          path: sellerOrders,
          parentNavigatorKey: _rootNavigatorKey,
          builder: (_, __) => const SellerOrderListScreen(),
        ),
        GoRoute(
          path: sellerOrderDetail,
          parentNavigatorKey: _rootNavigatorKey,
          builder: (context, state) => SellerOrderDetailScreen(
            orderId: state.pathParameters['id'] ?? '',
          ),
        ),

        // Seller centre — full-screen pushes, same as the rest above.
        // Not linked from anywhere yet (see the route constants' note).
        GoRoute(
          path: sellerDashboard,
          parentNavigatorKey: _rootNavigatorKey,
          builder: (_, __) => const SellerDashboardScreen(),
        ),
        GoRoute(
          path: sellerWallet,
          parentNavigatorKey: _rootNavigatorKey,
          builder: (_, __) => const SellerWalletScreen(),
        ),
        GoRoute(
          path: sellerWalletWithdraw,
          parentNavigatorKey: _rootNavigatorKey,
          builder: (context, state) =>
              WithdrawalFormScreen(balance: state.extra as StoreBalanceModel),
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
