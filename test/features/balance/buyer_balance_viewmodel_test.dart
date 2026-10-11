import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:blukios_marketplace/config/api_config.dart';
import 'package:blukios_marketplace/core/network/api_client.dart';
import 'package:blukios_marketplace/core/network/api_exceptions.dart';
import 'package:blukios_marketplace/core/network/api_response.dart';
import 'package:blukios_marketplace/core/providers.dart';
import 'package:blukios_marketplace/features/auth/models/user_model.dart';
import 'package:blukios_marketplace/features/auth/viewmodels/auth_viewmodel.dart';
import 'package:blukios_marketplace/features/balance/data/buyer_balance_repository.dart';
import 'package:blukios_marketplace/features/balance/models/buyer_balance_model.dart';
import 'package:blukios_marketplace/features/balance/viewmodels/buyer_balance_viewmodel.dart';

class MockApiClient extends Mock implements ApiClient {}

class MockBuyerBalanceRepository extends Mock implements BuyerBalanceRepository {}

BuyerBalancePage _page(int page, {int lastPage = 2, int balance = 45000}) => BuyerBalancePage(
      balance: balance,
      histories: PaginatedResponse(
        items: [BuyerBalanceHistory(id: 'h$page', type: 'refund', amount: 1000 * page)],
        meta: PaginationMeta(currentPage: page, lastPage: lastPage, perPage: 20, total: 2),
      ),
    );

void main() {
  test('repository asks for the page and parses the envelope', () async {
    final api = MockApiClient();
    when(() => api.get(any(), queryParameters: any(named: 'queryParameters'))).thenAnswer(
      (_) async => Response(
        requestOptions: RequestOptions(),
        data: {
          'success': true,
          'data': {
            'balance': 5000,
            'histories': {
              'data': [],
              'meta': {'current_page': 2, 'last_page': 2, 'per_page': 20, 'total': 0},
            },
          },
        },
      ),
    );

    final page = await BuyerBalanceRepository(api).getBalance(page: 2);

    expect(page.balance, 5000);
    verify(() => api.get(ApiConfig.buyerBalance, queryParameters: {'page': 2, 'per_page': 20})).called(1);
  });

  group('BuyerBalanceNotifier', () {
    late MockBuyerBalanceRepository repository;
    late ProviderContainer container;

    setUp(() {
      repository = MockBuyerBalanceRepository();
      container = ProviderContainer(overrides: [
        buyerBalanceRepositoryProvider.overrideWithValue(repository),
      ]);
    });

    tearDown(() => container.dispose());

    test('load then loadMore appends the next page', () async {
      when(() => repository.getBalance()).thenAnswer((_) async => _page(1));
      when(() => repository.getBalance(page: 2)).thenAnswer((_) async => _page(2, balance: 40000));
      final notifier = container.read(buyerBalanceProvider.notifier);

      await notifier.load();
      expect(container.read(buyerBalanceProvider).balance, 45000);
      expect(container.read(buyerBalanceProvider).hasMore, isTrue);

      await notifier.loadMore();
      final state = container.read(buyerBalanceProvider);
      expect(state.histories.map((h) => h.id), ['h1', 'h2']);
      expect(state.balance, 40000);
      expect(state.hasMore, isFalse);

      await notifier.loadMore(); // nothing left: no request
      verify(() => repository.getBalance(page: 2)).called(1);
    });

    test('403 means not a buyer, not an error', () async {
      when(() => repository.getBalance())
          .thenThrow(ApiException(message: 'Unauthorized', statusCode: 403));

      await container.read(buyerBalanceProvider.notifier).load();

      final state = container.read(buyerBalanceProvider);
      expect(state.notBuyer, isTrue);
      expect(state.error, isNull);
      expect(state.balance, isNull);
    });

    test('other failures surface the server message', () async {
      when(() => repository.getBalance())
          .thenThrow(ApiException(message: 'Server tidak merespons', statusCode: 500));

      await container.read(buyerBalanceProvider.notifier).load();

      final state = container.read(buyerBalanceProvider);
      expect(state.notBuyer, isFalse);
      expect(state.error, 'Server tidak merespons');
      expect(state.isLoading, isFalse);
    });

    test('a failed refresh forgets the old balance, and load works again after', () async {
      when(() => repository.getBalance()).thenAnswer((_) async => _page(1));
      final notifier = container.read(buyerBalanceProvider.notifier);
      await notifier.load();

      when(() => repository.getBalance()).thenThrow(ApiException(message: 'x', statusCode: 500));
      await notifier.load();
      expect(container.read(buyerBalanceProvider).balance, isNull);

      when(() => repository.getBalance()).thenAnswer((_) async => _page(1, balance: 7000));
      await notifier.load();
      expect(container.read(buyerBalanceProvider).balance, 7000);
    });

    test('concurrent loads share one request', () async {
      final response = Completer<BuyerBalancePage>();
      when(() => repository.getBalance()).thenAnswer((_) => response.future);
      final notifier = container.read(buyerBalanceProvider.notifier);

      final a = notifier.load();
      final b = notifier.load();
      response.complete(_page(1));
      await Future.wait([a, b]);

      verify(() => repository.getBalance()).called(1);
    });

    test('a slow loadMore landing after a refresh is dropped', () async {
      when(() => repository.getBalance()).thenAnswer((_) async => _page(1));
      final more = Completer<BuyerBalancePage>();
      when(() => repository.getBalance(page: 2)).thenAnswer((_) => more.future);
      final notifier = container.read(buyerBalanceProvider.notifier);
      await notifier.load();

      final pending = notifier.loadMore();
      await notifier.load(); // pull-to-refresh
      more.complete(_page(2));
      await pending;

      expect(container.read(buyerBalanceProvider).histories.map((h) => h.id), ['h1']);
      expect(container.read(buyerBalanceProvider).isLoadingMore, isFalse);
    });

    test('loadMore does nothing while a load runs', () async {
      when(() => repository.getBalance()).thenAnswer((_) async => _page(1));
      final notifier = container.read(buyerBalanceProvider.notifier);
      await notifier.load();

      final refresh = notifier.load();
      await notifier.loadMore();
      await refresh;

      verifyNever(() => repository.getBalance(page: 2));
    });
  });

  test('a response for the previous account is dropped after switching', () async {
    final repository = MockBuyerBalanceRepository();
    final container = ProviderContainer(overrides: [
      buyerBalanceRepositoryProvider.overrideWithValue(repository),
      authProvider.overrideWith(_FakeAuth.new),
    ]);
    addTearDown(container.dispose);
    final first = Completer<BuyerBalancePage>();
    when(() => repository.getBalance()).thenAnswer((_) => first.future);
    container.listen(buyerBalanceProvider, (_, __) {});

    final stale = container.read(buyerBalanceProvider.notifier).load();
    (container.read(authProvider.notifier) as _FakeAuth).switchTo('user-2');
    container.read(buyerBalanceProvider); // rebuild for the new account
    first.complete(_page(1, balance: 99000));
    await stale;

    expect(container.read(buyerBalanceProvider).balance, isNull);

    when(() => repository.getBalance()).thenAnswer((_) async => _page(1, balance: 5000));
    await container.read(buyerBalanceProvider.notifier).load();
    expect(container.read(buyerBalanceProvider).balance, 5000);
  });
}

class _FakeAuth extends AuthNotifier {
  @override
  AuthData build() => AuthData(currentUser: _user('user-1'));

  void switchTo(String id) => state = AuthData(currentUser: _user(id));

  static UserModel _user(String id) => UserModel(id: id, name: 'U', email: 'u@x.id', role: 'buyer');
}
