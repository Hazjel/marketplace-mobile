import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:blukios_marketplace/core/providers.dart';
import 'package:blukios_marketplace/features/dashboard/data/dashboard_repository.dart';
import 'package:blukios_marketplace/features/dashboard/screens/dashboard_screen.dart';
import 'package:blukios_marketplace/features/dashboard/viewmodels/dashboard_viewmodel.dart';
import 'package:blukios_marketplace/features/seller/dashboard/data/seller_dashboard_repository.dart';
import 'package:blukios_marketplace/features/seller/dashboard/models/seller_dashboard_model.dart';
import 'package:blukios_marketplace/features/seller/dashboard/screens/seller_dashboard_screen.dart';

class MockDashboardRepository extends Mock implements DashboardRepository {}

class MockSellerDashboardRepository extends Mock implements SellerDashboardRepository {}

// The same payment wording as the order lists (fe-blue PAYMENT_LABELS);
// 'pending' stays the dashboards' own delivery label.
const _breakdown = {'unpaid': 1, 'paid': 2, 'failed': 3, 'pending': 4};

void _tall(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 4000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

// AppScaffold reads the GoRouter from context.
Widget _app(Widget screen) => MaterialApp.router(
      routerConfig: GoRouter(routes: [GoRoute(path: '/', builder: (_, __) => screen)]),
    );

void _expectLabels() {
  expect(find.text('Belum Bayar'), findsOneWidget);
  expect(find.text('Lunas'), findsOneWidget);
  expect(find.text('Gagal'), findsOneWidget);
  expect(find.text('Menunggu'), findsOneWidget);
  expect(find.text('Dibayar'), findsNothing);
}

void main() {
  testWidgets('buyer dashboard labels payment statuses like the order lists', (tester) async {
    _tall(tester);
    final repository = MockDashboardRepository();
    when(() => repository.getBuyerSummary(days: any(named: 'days'))).thenAnswer(
      (_) async => BuyerSummary(totalExpense: 0, statusBreakdown: _breakdown, chart: const []),
    );

    await tester.pumpWidget(ProviderScope(
      overrides: [dashboardRepositoryProvider.overrideWithValue(repository)],
      child: _app(const DashboardScreen()),
    ));
    await tester.pumpAndSettle();

    _expectLabels();
  });

  testWidgets('seller dashboard labels payment statuses like the order lists', (tester) async {
    _tall(tester);
    final repository = MockSellerDashboardRepository();
    when(() => repository.getSummary(days: any(named: 'days'))).thenAnswer(
      (_) async => SellerDashboardSummary(
        balance: 0,
        pendingBalance: 0,
        totalOrders: 10,
        statusBreakdown: _breakdown,
        totalReviews: 0,
        averageRating: 0,
        totalProducts: 0,
        topProducts: const [],
        chart: const [],
        trend: SellerTrend(),
      ),
    );

    await tester.pumpWidget(ProviderScope(
      overrides: [sellerDashboardRepositoryProvider.overrideWithValue(repository)],
      child: _app(const SellerDashboardScreen()),
    ));
    await tester.pumpAndSettle();

    _expectLabels();
  });
}
