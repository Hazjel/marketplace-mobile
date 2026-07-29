import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:blukios_marketplace/core/utils/currency_formatter.dart';
import 'package:blukios_marketplace/core/utils/date_formatter.dart';
import 'package:blukios_marketplace/features/transaction/models/transaction_model.dart';
import 'package:blukios_marketplace/features/transaction/viewmodels/transaction_viewmodel.dart';
import 'package:blukios_marketplace/shared/widgets/loading_widget.dart';

class TransactionListScreen extends ConsumerStatefulWidget {
  const TransactionListScreen({super.key});

  @override
  ConsumerState<TransactionListScreen> createState() => _TransactionListScreenState();
}

class _TransactionListScreenState extends ConsumerState<TransactionListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(transactionProvider.notifier).loadTransactions();
    });
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = ref.watch(transactionProvider);
    final notifier = ref.read(transactionProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transaksi'),
      ),
      body: viewModel.isLoading
          ? const LoadingWidget()
          : viewModel.error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: Color(0xFFEF4444)),
                      const SizedBox(height: 16),
                      Text(viewModel.error!),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: notifier.loadTransactions,
                        child: const Text('Coba Lagi'),
                      ),
                    ],
                  ),
                )
              : viewModel.transactions.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.receipt_long_outlined, size: 64, color: Color(0xFF9CA3AF)),
                          SizedBox(height: 16),
                          Text(
                            'Belum ada transaksi',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Transaksi Anda akan muncul di sini',
                            style: TextStyle(color: Color(0xFF6B7280)),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: notifier.loadTransactions,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: viewModel.transactions.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final trx = viewModel.transactions[index];
                          return _buildTransactionCard(trx);
                        },
                      ),
                    ),
    );
  }

  Future<void> _refreshStatus(TransactionModel trx) async {
    final error = await ref.read(transactionProvider.notifier).refreshStatus(trx.id);
    if (!mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: const Color(0xFFEF4444)),
      );
    }
  }

  Widget _buildTransactionCard(TransactionModel trx) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  trx.code,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                _buildStatusBadge(trx.paymentStatus, trx.paymentStatusLabel),
              ],
            ),
            const SizedBox(height: 4),
            if (trx.storeName != null)
              Text(
                trx.storeName!,
                style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
              ),
            const SizedBox(height: 2),
            Text(
              DateFormatter.format(trx.createdAt),
              style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),

            // Total
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total Pembayaran',
                  style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
                ),
                Text(
                  CurrencyFormatter.formatRupiah(trx.grandTotal),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF2563EB),
                  ),
                ),
              ],
            ),
            if (trx.paymentStatus == 'pending') ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => _refreshStatus(trx),
                  child: const Text('Cek Status Pembayaran'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status, String label) {
    Color bgColor;
    Color textColor;

    switch (status) {
      case 'paid':
        bgColor = const Color(0xFFDCFCE7);
        textColor = const Color(0xFF16A34A);
        break;
      case 'failed':
      case 'cancelled':
      case 'expired':
        bgColor = const Color(0xFFFEE2E2);
        textColor = const Color(0xFFDC2626);
        break;
      default:
        bgColor = const Color(0xFFFEF9C3);
        textColor = const Color(0xFFCA8A04);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: textColor),
      ),
    );
  }
}
