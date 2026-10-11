import 'package:flutter_test/flutter_test.dart';
import 'package:blukios_marketplace/config/routes.dart';
import 'package:blukios_marketplace/core/monitoring/notification_service.dart';
import 'package:blukios_marketplace/core/monitoring/push_route.dart';
import 'package:blukios_marketplace/features/auth/models/user_model.dart';
import 'package:blukios_marketplace/features/auth/viewmodels/auth_viewmodel.dart';

void main() {
  Future<String> route(
    String? id, {
    bool isSeller = true,
    Future<String?> Function(String)? orderStore,
    Future<String?> Function()? ownStore,
  }) =>
      transactionPushRoute(
        id,
        isSeller: isSeller,
        transactionStoreId: orderStore ?? (_) async => 's1',
        myStoreId: ownStore ?? () async => 's1',
      );

  test("a seller's own order opens the seller order detail", () async {
    expect(await route('t1'), AppRoutes.sellerOrderDetailPath('t1'));
  });

  test("another store's order opens the buyer list", () async {
    expect(await route('t1', ownStore: () async => 's2'), AppRoutes.transactions);
  });

  test('a buyer opens the buyer list without fetching anything', () async {
    expect(
      await route('t1', isSeller: false, orderStore: (_) => throw StateError('no fetch')),
      AppRoutes.transactions,
    );
  });

  test('a failed fetch falls back to the buyer list', () async {
    expect(await route('t1', orderStore: (_) async => throw Exception('404')), AppRoutes.transactions);
    expect(await route('t1', ownStore: () async => null), AppRoutes.transactions);
  });

  test('no transaction id opens the buyer list', () async {
    expect(await route(null), AppRoutes.transactions);
  });

  group('pushTarget', () {
    final seller = AuthData(
      state: AuthState.authenticated,
      currentUser: UserModel(id: 'u1', name: 'U', email: 'u@x.id', role: 'store'),
    );
    const signedOut = AuthData(state: AuthState.unauthenticated);
    const chat = {'type': 'chat', 'sender_id': 'u2'};
    const order = {'type': 'transaction', 'transaction_id': 't1'};

    Future<String?> target(
      Map<String, dynamic> data, {
      required AuthData settled,
      AuthData Function()? current,
      Future<String?> Function(String)? orderStore,
    }) =>
        pushTarget(
          data,
          settledAuth: () async => settled,
          currentAuth: current ?? () => settled,
          transactionStoreId: orderStore ?? (_) async => 's1',
          myStoreId: () async => 's1',
        );

    test('signed in: chat and transaction pushes deep-link', () async {
      expect(await target(chat, settled: seller), AppRoutes.chatThreadPath('u2'));
      expect(await target(order, settled: seller), AppRoutes.sellerOrderDetailPath('t1'));
    });

    test('signed out once auth settles: no deep link for any push', () async {
      expect(await target(chat, settled: signedOut), isNull);
      expect(await target(order, settled: signedOut), isNull);
    });

    test('logout while the order is being fetched: no navigation', () async {
      var auth = seller;
      final result = await target(
        order,
        settled: seller,
        current: () => auth,
        orderStore: (_) async {
          auth = signedOut;
          return 's1';
        },
      );
      expect(result, isNull);
    });
  });

  test('takeInitialTap hands out the cold-start tap exactly once', () {
    NotificationService.initialTapForTest = {'type': 'chat', 'sender_id': 'u2'};
    expect(NotificationService.takeInitialTap(), {'type': 'chat', 'sender_id': 'u2'});
    expect(NotificationService.takeInitialTap(), isNull);
  });
}
