import 'dart:async';

import 'package:flutter/material.dart';
import 'package:blukios_marketplace/config/app_theme.dart';
import 'package:blukios_marketplace/features/transaction/models/ship_deadline.dart';
import 'package:blukios_marketplace/features/transaction/models/transaction_model.dart';

/// Deadline block for a paid, unshipped order; renders nothing when
/// [resolveShipDeadline] says it does not apply. Red when under 24 h left.
/// Wording follows fe-blue TransactionDetail.vue for [forBuyer] and seller.
/// Re-evaluates every minute while mounted, like the web, so the remaining
/// time and the red state do not go stale on an open screen.
class ShipDeadlineNotice extends StatefulWidget {
  final TransactionModel order;
  final bool forBuyer;

  /// The clock; injectable because tests cannot fake `DateTime.now()`.
  final DateTime Function() now;

  const ShipDeadlineNotice({
    super.key,
    required this.order,
    this.forBuyer = false,
    this.now = DateTime.now,
  });

  @override
  State<ShipDeadlineNotice> createState() => _ShipDeadlineNoticeState();
}

class _ShipDeadlineNoticeState extends State<ShipDeadlineNotice> {
  late final Timer _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(minutes: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _ticker.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final forBuyer = widget.forBuyer;
    final deadline = resolveShipDeadline(order, now: widget.now());
    if (deadline == null) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary;
    final urgent = deadline.urgent;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTheme.spacingMD),
      decoration: BoxDecoration(
        color: urgent ? AppTheme.error.withValues(alpha: 0.08) : null,
        borderRadius: BorderRadius.circular(AppTheme.radiusLG),
        border: Border.all(
          color: urgent
              ? AppTheme.error.withValues(alpha: 0.3)
              : (isDark ? AppTheme.darkBorder : AppTheme.border),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${forBuyer ? 'Penjual wajib mengirim sebelum' : 'Kirim sebelum'} ${deadline.at}',
            style: AppTheme.labelMd.copyWith(color: urgent ? AppTheme.error : null),
          ),
          const SizedBox(height: 2),
          Text(
            '${deadline.remaining} ${forBuyer ? 'Jika belum dikirim, pesanan dibatalkan dan dana dikembalikan otomatis.' : 'Lewat batas ini, pesanan dibatalkan otomatis dan dana dikembalikan ke pembeli.'}',
            style: AppTheme.bodySm.copyWith(color: urgent ? AppTheme.error : muted),
          ),
        ],
      ),
    );
  }
}
