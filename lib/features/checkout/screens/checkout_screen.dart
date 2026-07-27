import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:blukios_marketplace/config/routes.dart';
import 'package:blukios_marketplace/core/network/api_client.dart';
import 'package:blukios_marketplace/core/utils/currency_formatter.dart';
import 'package:blukios_marketplace/features/address/data/address_repository.dart';
import 'package:blukios_marketplace/features/address/models/address_model.dart';
import 'package:blukios_marketplace/features/auth/viewmodels/auth_viewmodel.dart';
import 'package:blukios_marketplace/features/cart/models/cart_model.dart';
import 'package:blukios_marketplace/features/cart/viewmodels/cart_viewmodel.dart';
import 'package:blukios_marketplace/features/checkout/viewmodels/checkout_viewmodel.dart';
import 'package:blukios_marketplace/features/shipment/data/shipment_repository.dart';
import 'package:blukios_marketplace/features/shipment/models/courier_option_model.dart';
import 'package:blukios_marketplace/features/transaction/data/transaction_repository.dart';

class CheckoutScreen extends StatelessWidget {
  final CartGroupModel group;

  const CheckoutScreen({super.key, required this.group});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<CheckoutViewModel>(
      create: (ctx) {
        final apiClient = ctx.read<ApiClient>();
        return CheckoutViewModel(
          group,
          AddressRepository(apiClient),
          ShipmentRepository(apiClient),
          TransactionRepository(apiClient),
        )..loadSavedAddresses();
      },
      child: const _CheckoutView(),
    );
  }
}

class _CheckoutView extends StatelessWidget {
  const _CheckoutView();

  Future<void> _pickCourier(BuildContext context, CheckoutViewModel viewModel) async {
    if (viewModel.selectedAddress == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih alamat terlebih dahulu')),
      );
      return;
    }

    await viewModel.calculateShipping();
    if (!context.mounted) return;

    if (viewModel.shippingError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(viewModel.shippingError!), backgroundColor: const Color(0xFFEF4444)),
      );
      return;
    }

    if (!context.mounted) return;
    await showModalBottomSheet(
      context: context,
      builder: (_) => _CourierSheet(viewModel: viewModel),
    );
  }

  Future<void> _submit(BuildContext context, CheckoutViewModel viewModel) async {
    final authViewModel = context.read<AuthViewModel>();
    final buyerId = authViewModel.currentUser?.buyer?.id;

    if (buyerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Akun pembeli tidak ditemukan')),
      );
      return;
    }

    final transaction = await viewModel.submit(buyerId: buyerId);
    if (!context.mounted) return;

    if (transaction == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(viewModel.submitError ?? 'Gagal membuat transaksi'),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
      return;
    }

    // Transaction is committed server-side; drop this store's cart items now
    // to avoid double-ordering, matching the web checkout's behavior.
    context.read<CartViewModel>().removeGroup(viewModel.group.storeId);

    if (transaction.snapToken == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pesanan dibuat, namun gagal memuat halaman pembayaran')),
      );
      context.go(AppRoutes.transactions);
      return;
    }

    context.push(AppRoutes.paymentPath(transaction.id), extra: transaction.snapToken);
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<CheckoutViewModel>();
    final group = viewModel.group;

    return Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildSectionCard(
              title: 'Alamat Pengiriman',
              child: viewModel.isLoadingAddresses
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : viewModel.savedAddresses.isEmpty
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Belum ada alamat tersimpan', style: TextStyle(fontSize: 13)),
                            const SizedBox(height: 8),
                            OutlinedButton(
                              onPressed: () async {
                                await context.push(AppRoutes.addressForm);
                                if (context.mounted) viewModel.loadSavedAddresses();
                              },
                              child: const Text('Tambah Alamat'),
                            ),
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: viewModel.savedAddresses
                              .map((addr) => _buildAddressTile(context, viewModel, addr))
                              .toList(),
                        ),
            ),
            const SizedBox(height: 12),

            _buildSectionCard(
              title: 'Pesanan (${group.itemCount} produk) — ${group.storeName}',
              child: Column(
                children: group.items
                    .map((item) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  item.productName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),
                              Text(
                                'x${item.quantity}',
                                style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                              ),
                            ],
                          ),
                        ))
                    .toList(),
              ),
            ),
            const SizedBox(height: 12),

            _buildSectionCard(
              title: 'Pengiriman',
              child: InkWell(
                onTap: viewModel.isCalculatingShipping ? null : () => _pickCourier(context, viewModel),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: viewModel.isCalculatingShipping
                            ? const Text('Menghitung ongkir...', style: TextStyle(fontSize: 13))
                            : viewModel.selectedCourier == null
                                ? const Text('Pilih Kurir', style: TextStyle(fontSize: 13))
                                : Text(
                                    '${viewModel.selectedCourier!.shippingName} - ${viewModel.selectedCourier!.serviceName}',
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                  ),
                      ),
                      if (viewModel.selectedCourier != null)
                        Text(
                          CurrencyFormatter.formatRupiah(viewModel.selectedCourier!.shippingCostNet),
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF2563EB)),
                        ),
                      const SizedBox(width: 8),
                      const Icon(Icons.chevron_right, size: 20),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            _buildSectionCard(
              title: 'Ringkasan Belanja',
              child: Column(
                children: [
                  _buildSummaryRow('Subtotal', viewModel.subtotal),
                  _buildSummaryRow('Ongkos Kirim', viewModel.shippingCost),
                  _buildSummaryRow('PPN 11%', viewModel.tax),
                  const Divider(),
                  _buildSummaryRow('Total Tagihan', viewModel.grandTotal, isBold: true),
                ],
              ),
            ),
            const SizedBox(height: 24),

            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: viewModel.isSubmitting ? null : () => _submit(context, viewModel),
                child: viewModel.isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Bayar Sekarang'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddressTile(BuildContext context, CheckoutViewModel viewModel, AddressModel addr) {
    final isSelected = viewModel.selectedAddress?.id == addr.id;
    return InkWell(
      onTap: () => viewModel.selectAddress(addr),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          border: Border.all(color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFE5E7EB), width: isSelected ? 2 : 1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(addr.label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                if (addr.isPrimary) ...[
                  const SizedBox(width: 6),
                  const Text('UTAMA', style: TextStyle(fontSize: 10, color: Color(0xFF2563EB))),
                ],
              ],
            ),
            const SizedBox(height: 2),
            Text('${addr.recipientName} (${addr.phone})', style: const TextStyle(fontSize: 12)),
            Text('${addr.address}, ${addr.city}', style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, double value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: isBold ? 14 : 13, fontWeight: isBold ? FontWeight.w700 : FontWeight.normal)),
          Text(
            CurrencyFormatter.formatRupiah(value),
            style: TextStyle(
              fontSize: isBold ? 15 : 13,
              fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
              color: isBold ? const Color(0xFF2563EB) : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({required String title, required Widget child}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }
}

class _CourierSheet extends StatelessWidget {
  final CheckoutViewModel viewModel;

  const _CourierSheet({required this.viewModel});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Pilih Kurir', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 400),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: viewModel.couriers.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final courier = viewModel.couriers[index];
                  return _buildCourierTile(context, courier);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCourierTile(BuildContext context, CourierOptionModel courier) {
    return ListTile(
      title: Text(courier.shippingName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      subtitle: Text(courier.serviceName, style: const TextStyle(fontSize: 12)),
      trailing: Text(
        CurrencyFormatter.formatRupiah(courier.shippingCostNet),
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF2563EB)),
      ),
      onTap: () {
        viewModel.selectCourier(courier);
        Navigator.of(context).pop();
      },
    );
  }
}
