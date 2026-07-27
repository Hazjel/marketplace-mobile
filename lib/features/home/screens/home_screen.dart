import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:blukios_marketplace/config/routes.dart';
import 'package:blukios_marketplace/core/utils/responsive.dart';
import 'package:blukios_marketplace/features/home/viewmodels/home_viewmodel.dart';
import 'package:blukios_marketplace/shared/widgets/product_card.dart';
import 'package:blukios_marketplace/shared/widgets/loading_widget.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<HomeViewModel>().loadData();
    });
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<HomeViewModel>();

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.storefront_rounded, color: Color(0xFF2563EB), size: 28),
            SizedBox(width: 8),
            Text(
              'Blukios',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.shopping_cart_outlined),
            onPressed: () => context.push(AppRoutes.cart),
          ),
          IconButton(
            icon: const Icon(Icons.receipt_long_outlined),
            onPressed: () => context.push(AppRoutes.transactions),
          ),
        ],
      ),
      body: viewModel.isLoading
          ? const LoadingWidget()
          : viewModel.error != null
              ? _buildError(viewModel)
              : RefreshIndicator(
                  onRefresh: viewModel.loadData,
                  child: CustomScrollView(
                    slivers: [
                      // Search Bar
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: TextField(
                            decoration: InputDecoration(
                              hintText: 'Cari produk...',
                              prefixIcon: const Icon(Icons.search),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            onSubmitted: (query) => viewModel.search(query.trim()),
                          ),
                        ),
                      ),

                      // Categories
                      if (viewModel.categories.isNotEmpty) ...[
                        const SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              'Kategori',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                        SliverToBoxAdapter(
                          child: SizedBox(
                            height: 110,
                            child: ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              scrollDirection: Axis.horizontal,
                              itemCount: viewModel.categories.length,
                              itemBuilder: (context, index) {
                                final cat = viewModel.categories[index];
                                return Container(
                                  width: 80,
                                  margin: const EdgeInsets.symmetric(horizontal: 4),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 48,
                                        height: 48,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFEFF6FF),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: const Icon(
                                          Icons.category_outlined,
                                          color: Color(0xFF2563EB),
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Flexible(
                                        child: Text(
                                          cat.name,
                                          textAlign: TextAlign.center,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontSize: 11),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ],

                      // Products header
                      const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(16, 8, 16, 12),
                          child: Text(
                            'Produk Terbaru',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),

                      // Products Grid (responsive)
                      SliverPadding(
                        padding: Responsive.getScreenPadding(context),
                        sliver: SliverGrid(
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: Responsive.getGridCrossAxisCount(context),
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            childAspectRatio: 0.68,
                          ),
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final product = viewModel.products[index];
                              return ProductCard(
                                product: product,
                                onTap: () => context.push(AppRoutes.productDetailPath(product.slug)),
                              );
                            },
                            childCount: viewModel.products.length,
                          ),
                        ),
                      ),

                      // Bottom spacing
                      const SliverToBoxAdapter(child: SizedBox(height: 24)),
                    ],
                  ),
                ),
    );
  }

  Widget _buildError(HomeViewModel viewModel) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Color(0xFFEF4444)),
            const SizedBox(height: 16),
            Text(
              viewModel.error ?? 'Terjadi kesalahan',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: viewModel.loadData,
              child: const Text('Coba Lagi'),
            ),
          ],
        ),
      ),
    );
  }
}
