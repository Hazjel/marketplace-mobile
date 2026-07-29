import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:blukios_marketplace/config/routes.dart';
import 'package:blukios_marketplace/core/utils/currency_formatter.dart';
import 'package:blukios_marketplace/features/cart/models/cart_model.dart';
import 'package:blukios_marketplace/features/cart/viewmodels/cart_viewmodel.dart';
import 'package:blukios_marketplace/shared/widgets/loading_widget.dart';

class CartScreen extends ConsumerStatefulWidget {
  const CartScreen({super.key});

  @override
  ConsumerState<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends ConsumerState<CartScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(cartProvider.notifier).loadCart();
    });
  }

  Future<void> _removeItem(CartItemModel item) async {
    final error = await ref
        .read(cartProvider.notifier)
        .removeItem(item.productId, variantId: item.variantId);
    if (!mounted) return;
    if (error == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Produk dihapus dari keranjang')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: const Color(0xFFEF4444)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = ref.watch(cartProvider);
    final notifier = ref.read(cartProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Keranjang'),
      ),
      body: viewModel.isLoading
          ? const LoadingWidget()
          : viewModel.error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(viewModel.error!),
                      const SizedBox(height: 16),
                      ElevatedButton(onPressed: notifier.loadCart, child: const Text('Coba Lagi')),
                    ],
                  ),
                )
              : viewModel.groups.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.shopping_cart_outlined, size: 64, color: Color(0xFF9CA3AF)),
                          SizedBox(height: 16),
                          Text(
                            'Keranjang kosong',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Yuk mulai belanja!',
                            style: TextStyle(color: Color(0xFF6B7280)),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: notifier.loadCart,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: viewModel.groups.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 16),
                        itemBuilder: (context, index) {
                          final group = viewModel.groups[index];
                          return _buildStoreGroup(group);
                        },
                      ),
                    ),
    );
  }

  Widget _buildStoreGroup(CartGroupModel group) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Store header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            color: const Color(0xFFF9FAFB),
            child: Row(
              children: [
                const Icon(Icons.storefront_outlined, size: 16, color: Color(0xFF6B7280)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    group.storeName,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),

          // Items
          ...group.items.map((item) => Padding(
                padding: const EdgeInsets.all(12),
                child: _buildCartItem(item),
              )),

          const Divider(height: 1),

          // Group subtotal + checkout
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Subtotal', style: TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
                    Text(
                      CurrencyFormatter.formatRupiah(group.subtotal),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF2563EB),
                      ),
                    ),
                  ],
                ),
                ElevatedButton(
                  onPressed: () => context.push(AppRoutes.checkout, extra: group),
                  child: const Text('Checkout'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCartItem(CartItemModel item) {
    return Row(
      children: [
        // Product image
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: 64,
            height: 64,
            child: item.productThumbnail != null
                ? CachedNetworkImage(
                    imageUrl: item.productThumbnail!,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => Container(
                      color: const Color(0xFFF3F4F6),
                      child: const Icon(Icons.image_outlined, size: 24),
                    ),
                  )
                : Container(
                    color: const Color(0xFFF3F4F6),
                    child: const Icon(Icons.image_outlined, size: 24, color: Color(0xFF9CA3AF)),
                  ),
          ),
        ),
        const SizedBox(width: 12),

        // Product info
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.productName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 4),
              Text(
                CurrencyFormatter.formatRupiah(item.price),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF2563EB),
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(
                    'Qty: ${item.quantity}',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => _removeItem(item),
                    child: const Icon(Icons.delete_outline, size: 20, color: Color(0xFFEF4444)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
