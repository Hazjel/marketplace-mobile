import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:blukios_marketplace/core/network/api_response.dart';
import 'package:blukios_marketplace/core/providers.dart';
import 'package:blukios_marketplace/features/cart/data/cart_repository.dart';
import 'package:blukios_marketplace/features/home/data/product_repository.dart';
import 'package:blukios_marketplace/features/home/models/category_model.dart';
import 'package:blukios_marketplace/features/home/models/product_model.dart';
import 'package:blukios_marketplace/features/home/screens/home_screen.dart';
import 'package:blukios_marketplace/features/search/data/search_repository.dart';
import 'package:blukios_marketplace/features/search/models/search_filters.dart';
import 'package:blukios_marketplace/features/search/viewmodels/search_viewmodel.dart'
    show searchRepositoryProvider;
import 'package:blukios_marketplace/shared/widgets/skeletons.dart';

class MockProductRepository extends Mock implements ProductRepository {}

class MockSearchRepository extends Mock implements SearchRepository {}

class MockCartRepository extends Mock implements CartRepository {}

ProductModel _product({String id = 'p1', String name = 'Test Product'}) {
  return ProductModel(
    id: id,
    name: name,
    slug: 'test-product-$id',
    price: 10000,
    stock: 5,
    weight: 1.0,
    condition: 'new',
    totalSold: 0,
  );
}

void main() {
  late MockProductRepository productRepository;
  late MockSearchRepository searchRepository;
  late MockCartRepository cartRepository;

  setUpAll(() {
    registerFallbackValue(SearchFilters.empty);
  });

  setUp(() {
    productRepository = MockProductRepository();
    searchRepository = MockSearchRepository();
    cartRepository = MockCartRepository();
    when(() => cartRepository.getCart()).thenAnswer((_) async => []);
  });

  Widget buildApp() {
    return ProviderScope(
      overrides: [
        productRepositoryProvider.overrideWithValue(productRepository),
        searchRepositoryProvider.overrideWithValue(searchRepository),
        cartRepositoryProvider.overrideWithValue(cartRepository),
      ],
      child: const MaterialApp(home: HomeScreen()),
    );
  }

  testWidgets('shows a loading skeleton before data arrives', (tester) async {
    // Never-completing futures — asserts the state right after the first
    // frame, before anything resolves.
    when(() => productRepository.getCategories()).thenAnswer((_) => Completer<List<CategoryModel>>().future);
    when(() => searchRepository.searchProducts(filters: any(named: 'filters'), page: any(named: 'page')))
        .thenAnswer((_) => Completer<PaginatedResponse<ProductModel>>().future);

    await tester.pumpWidget(buildApp());
    await tester.pump(); // let the postFrameCallback fire and kick off loading

    expect(find.byType(ProductGridSkeleton), findsOneWidget);
    expect(find.text('Belum ada produk'), findsNothing);
  });

  testWidgets('renders categories and products once loaded', (tester) async {
    when(() => productRepository.getCategories()).thenAnswer(
      (_) async => [CategoryModel(id: 'c1', name: 'Elektronik', slug: 'elektronik', productCount: 3)],
    );
    when(() => searchRepository.searchProducts(filters: any(named: 'filters'), page: any(named: 'page')))
        .thenAnswer((_) async => PaginatedResponse(
              items: [_product(id: 'p1', name: 'Kabel USB-C'), _product(id: 'p2', name: 'Charger 20W')],
              meta: const PaginationMeta(currentPage: 1, lastPage: 1, perPage: 12, total: 2),
            ));

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    expect(find.text('Elektronik'), findsOneWidget);
    expect(find.text('Kabel USB-C'), findsOneWidget);
    expect(find.text('Charger 20W'), findsOneWidget);
    expect(find.text('Belum ada produk'), findsNothing);
  });

  testWidgets('shows the empty state when there are no products', (tester) async {
    when(() => productRepository.getCategories()).thenAnswer((_) async => []);
    when(() => searchRepository.searchProducts(filters: any(named: 'filters'), page: any(named: 'page')))
        .thenAnswer((_) async => const PaginatedResponse(
              items: [],
              meta: PaginationMeta(currentPage: 1, lastPage: 1, perPage: 12, total: 0),
            ));

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    expect(find.text('Belum ada produk'), findsOneWidget);
  });
}
