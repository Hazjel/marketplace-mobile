import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:blukios_marketplace/core/network/api_client.dart';
import 'package:blukios_marketplace/features/address/data/address_repository.dart';
import 'package:blukios_marketplace/features/auth/data/auth_repository.dart';
import 'package:blukios_marketplace/features/cart/data/cart_repository.dart';
import 'package:blukios_marketplace/features/home/data/product_repository.dart';
import 'package:blukios_marketplace/features/review/data/review_repository.dart';
import 'package:blukios_marketplace/features/seller/dashboard/data/seller_dashboard_repository.dart';
import 'package:blukios_marketplace/features/seller/product/data/seller_product_repository.dart';
import 'package:blukios_marketplace/features/seller/store/data/seller_store_repository.dart';
import 'package:blukios_marketplace/features/seller/wallet/data/seller_wallet_repository.dart';
import 'package:blukios_marketplace/features/shipment/data/shipment_repository.dart';
import 'package:blukios_marketplace/features/transaction/data/transaction_repository.dart';

/// Root dependency graph.
///
/// Repositories are stateless wrappers over [ApiClient], so they are plain
/// `Provider`s. Feature state lives in `NotifierProvider`s declared next to
/// each feature's notifier.

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(ref.watch(apiClientProvider)),
);

final productRepositoryProvider = Provider<ProductRepository>(
  (ref) => ProductRepository(ref.watch(apiClientProvider)),
);

final cartRepositoryProvider = Provider<CartRepository>(
  (ref) => CartRepository(ref.watch(apiClientProvider)),
);

final transactionRepositoryProvider = Provider<TransactionRepository>(
  (ref) => TransactionRepository(ref.watch(apiClientProvider)),
);

final addressRepositoryProvider = Provider<AddressRepository>(
  (ref) => AddressRepository(ref.watch(apiClientProvider)),
);

final shipmentRepositoryProvider = Provider<ShipmentRepository>(
  (ref) => ShipmentRepository(ref.watch(apiClientProvider)),
);

final reviewRepositoryProvider = Provider<ReviewRepository>(
  (ref) => ReviewRepository(ref.watch(apiClientProvider)),
);

final sellerStoreRepositoryProvider = Provider<SellerStoreRepository>(
  (ref) => SellerStoreRepository(ref.watch(apiClientProvider)),
);

final sellerProductRepositoryProvider = Provider<SellerProductRepository>(
  (ref) => SellerProductRepository(ref.watch(apiClientProvider)),
);

final sellerDashboardRepositoryProvider = Provider<SellerDashboardRepository>(
  (ref) => SellerDashboardRepository(ref.watch(apiClientProvider)),
);

final sellerWalletRepositoryProvider = Provider<SellerWalletRepository>(
  (ref) => SellerWalletRepository(ref.watch(apiClientProvider)),
);
