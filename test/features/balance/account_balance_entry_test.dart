import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:blukios_marketplace/core/network/api_exceptions.dart';
import 'package:blukios_marketplace/core/network/api_response.dart';
import 'package:blukios_marketplace/core/providers.dart';
import 'package:blukios_marketplace/features/account/data/profile_repository.dart';
import 'package:blukios_marketplace/features/account/screens/account_screen.dart';
import 'package:blukios_marketplace/features/account/viewmodels/account_viewmodel.dart';
import 'package:blukios_marketplace/features/balance/data/buyer_balance_repository.dart';
import 'package:blukios_marketplace/features/balance/models/buyer_balance_model.dart';

class MockProfileRepository extends Mock implements ProfileRepository {}

class MockBuyerBalanceRepository extends Mock implements BuyerBalanceRepository {}

void main() {
  late MockProfileRepository profile;
  late MockBuyerBalanceRepository balance;

  setUp(() {
    profile = MockProfileRepository();
    balance = MockBuyerBalanceRepository();
    when(() => profile.getProfile()).thenThrow(ApiException(message: 'offline'));
  });

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        profileRepositoryProvider.overrideWithValue(profile),
        buyerBalanceRepositoryProvider.overrideWithValue(balance),
      ],
      child: const MaterialApp(home: AccountScreen()),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('a buyer sees Saldo Blukios with the balance', (tester) async {
    when(() => balance.getBalance()).thenAnswer((_) async => const BuyerBalancePage(
          balance: 45000,
          histories: PaginatedResponse(
            items: [],
            meta: PaginationMeta(currentPage: 1, lastPage: 1, perPage: 20, total: 0),
          ),
        ));

    await pump(tester);

    expect(find.text('Saldo Blukios'), findsOneWidget);
    expect(find.textContaining('45.000'), findsOneWidget);
  });

  testWidgets('no entry when the account is not a buyer (403)', (tester) async {
    when(() => balance.getBalance())
        .thenThrow(ApiException(message: 'Unauthorized', statusCode: 403));

    await pump(tester);

    expect(find.text('Saldo Blukios'), findsNothing);
    expect(find.text('Transaksi Saya'), findsOneWidget);
  });
}
