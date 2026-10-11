import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:blukios_marketplace/config/app_theme.dart';
import 'package:blukios_marketplace/features/transaction/viewmodels/transaction_viewmodel.dart';
import 'package:blukios_marketplace/features/transaction/widgets/complaint_details.dart';
import 'package:blukios_marketplace/shared/widgets/app_scaffold.dart';
import 'package:blukios_marketplace/shared/widgets/state_views.dart';

/// Buyer's view of the complaint on one order, read from the transaction
/// list so it follows live updates. The buyer can withdraw it while it is
/// open or escalated.
class ComplaintScreen extends ConsumerStatefulWidget {
  final String transactionId;

  const ComplaintScreen({super.key, required this.transactionId});

  @override
  ConsumerState<ComplaintScreen> createState() => _ComplaintScreenState();
}

class _ComplaintScreenState extends ConsumerState<ComplaintScreen> {
  bool _sending = false;

  Future<void> _withdraw(String complaintId) async {
    if (_sending) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tarik Komplain?'),
        content: const Text(
          'Komplain untuk pesanan ini tidak bisa diajukan lagi, dan pesanan bisa diselesaikan seperti biasa.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.error),
            child: const Text('Tarik Komplain'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _sending = true);
    final error = await ref
        .read(transactionProvider.notifier)
        .withdrawComplaint(widget.transactionId, complaintId);
    if (!mounted) return;
    setState(() => _sending = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error ?? 'Komplain ditarik'),
        backgroundColor: error != null ? AppTheme.error : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final trx = ref
        .watch(transactionProvider)
        .transactions
        .where((t) => t.id == widget.transactionId)
        .firstOrNull;
    final complaint = trx?.complaint;

    return AppScaffold(
      title: 'Komplain Pesanan',
      body: complaint == null
          ? const ErrorState(message: 'Komplain tidak ditemukan')
          : ListView(
              padding: const EdgeInsets.all(AppTheme.spacingLG),
              children: [
                Text(trx!.code, style: AppTheme.titleSm),
                const SizedBox(height: AppTheme.spacingMD),
                ComplaintDetails(complaint: complaint),
                if (complaint.isActive) ...[
                  const SizedBox(height: AppTheme.spacingLG),
                  Text(
                    'Pesanan belum bisa diselesaikan selama komplain berjalan.',
                    style: AppTheme.bodySm.copyWith(color: const Color(0xFFB45309)),
                  ),
                  const SizedBox(height: AppTheme.spacingMD),
                  OutlinedButton(
                    onPressed: _sending ? null : () => _withdraw(complaint.id),
                    style: OutlinedButton.styleFrom(foregroundColor: AppTheme.error),
                    child: Text(_sending ? 'Menarik...' : 'Tarik Komplain'),
                  ),
                ],
              ],
            ),
    );
  }
}
