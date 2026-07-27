import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:blukios_marketplace/config/routes.dart';
import 'package:blukios_marketplace/features/address/models/address_model.dart';
import 'package:blukios_marketplace/features/address/viewmodels/address_viewmodel.dart';
import 'package:blukios_marketplace/shared/widgets/loading_widget.dart';

class AddressListScreen extends StatefulWidget {
  const AddressListScreen({super.key});

  @override
  State<AddressListScreen> createState() => _AddressListScreenState();
}

class _AddressListScreenState extends State<AddressListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AddressViewModel>().loadAddresses();
    });
  }

  Future<void> _delete(AddressViewModel viewModel, AddressModel address) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Hapus Alamat'),
        content: Text('Hapus alamat "${address.label}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Hapus')),
        ],
      ),
    );
    if (confirmed != true) return;

    final error = await viewModel.deleteAddress(address.id);
    if (!mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: const Color(0xFFEF4444)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<AddressViewModel>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Alamat Saya'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push(AppRoutes.addressForm),
        child: const Icon(Icons.add),
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
                      ElevatedButton(onPressed: viewModel.loadAddresses, child: const Text('Coba Lagi')),
                    ],
                  ),
                )
              : viewModel.addresses.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.location_off_outlined, size: 64, color: Color(0xFF9CA3AF)),
                          SizedBox(height: 16),
                          Text(
                            'Belum ada alamat tersimpan',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: viewModel.addresses.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final addr = viewModel.addresses[index];
                        return _buildAddressCard(viewModel, addr);
                      },
                    ),
    );
  }

  Widget _buildAddressCard(AddressViewModel viewModel, AddressModel addr) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(addr.label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                if (addr.isPrimary) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'UTAMA',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF2563EB)),
                    ),
                  ),
                ],
                const Spacer(),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit') {
                      context.push(AppRoutes.addressForm, extra: addr);
                    } else if (value == 'delete') {
                      _delete(viewModel, addr);
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('Edit')),
                    PopupMenuItem(value: 'delete', child: Text('Hapus')),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${addr.recipientName} (${addr.phone})',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 4),
            Text(
              '${addr.address}, ${addr.city} ${addr.postalCode}',
              style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
            ),
          ],
        ),
      ),
    );
  }
}
