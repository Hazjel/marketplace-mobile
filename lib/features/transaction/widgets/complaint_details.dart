import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:blukios_marketplace/config/app_theme.dart';
import 'package:blukios_marketplace/core/utils/date_formatter.dart';
import 'package:blukios_marketplace/features/transaction/models/transaction_model.dart';

/// Read-only view of a complaint, shared by the buyer's complaint screen and
/// the seller's order detail. Mirrors fe-blue ComplaintPanel.vue.
class ComplaintDetails extends StatelessWidget {
  final TransactionComplaint complaint;

  const ComplaintDetails({super.key, required this.complaint});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary;
    final deadline = complaint.deadlineAt;

    Widget field(String label, String value) => Padding(
          padding: const EdgeInsets.only(top: AppTheme.spacingMD),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: AppTheme.labelSm.copyWith(color: muted)),
              const SizedBox(height: 2),
              Text(value, style: AppTheme.bodyMd),
            ],
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Status:', style: AppTheme.labelMd),
            const SizedBox(width: AppTheme.spacingSM),
            Flexible(child: ComplaintStatusBadge(complaint: complaint)),
          ],
        ),
        if (complaint.status == 'open' && deadline != null) ...[
          const SizedBox(height: AppTheme.spacingSM),
          Text(
            'Batas tanggapan penjual: ${_localDateTime(deadline)}. ${_remaining(deadline)}',
            style: AppTheme.bodySm.copyWith(color: muted),
          ),
        ],
        if (complaint.status == 'escalated' && complaint.sellerResponse == null) ...[
          const SizedBox(height: AppTheme.spacingSM),
          Text(
            'Penjual tidak menanggapi sebelum batas waktu.',
            style: AppTheme.bodySm.copyWith(color: muted),
          ),
        ],
        field('Alasan', complaint.reasonLabel),
        if (complaint.createdAt case final created?) field('Diajukan', _localDateTime(created)),
        field('Keterangan pembeli', complaint.description),
        if (complaint.photos.isNotEmpty) ...[
          const SizedBox(height: AppTheme.spacingMD),
          Text('Foto', style: AppTheme.labelSm.copyWith(color: muted)),
          const SizedBox(height: AppTheme.spacingXS),
          Wrap(
            spacing: AppTheme.spacingSM,
            runSpacing: AppTheme.spacingSM,
            children: [
              for (final (i, url) in complaint.photos.indexed)
                Semantics(
                  button: true,
                  label: 'Foto komplain ${i + 1} (buka ukuran penuh)',
                  child: GestureDetector(
                    onTap: () => _openPhoto(context, url),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppTheme.radiusLG),
                      child: CachedNetworkImage(
                        imageUrl: url,
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => const SizedBox(
                          width: 80,
                          height: 80,
                          child: Icon(Icons.broken_image_outlined),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
        if (complaint.sellerResponse case final response?) field('Tanggapan penjual', response),
        if (complaint.adminNote case final note?) field('Catatan admin', note),
      ],
    );
  }

  void _openPhoto(BuildContext context, String url) {
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog.fullscreen(
        backgroundColor: Colors.black,
        child: Stack(
          children: [
            Positioned.fill(
              child: InteractiveViewer(
                child: CachedNetworkImage(imageUrl: url, fit: BoxFit.contain),
              ),
            ),
            Positioned(
              top: AppTheme.spacingLG,
              right: AppTheme.spacingLG,
              child: SafeArea(
                child: IconButton(
                  tooltip: 'Tutup',
                  onPressed: () => Navigator.pop(ctx),
                  icon: const Icon(Icons.close, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ComplaintStatusBadge extends StatelessWidget {
  final TransactionComplaint complaint;

  const ComplaintStatusBadge({super.key, required this.complaint});

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (complaint.status) {
      'open' => (const Color(0xFFFEF9C3), const Color(0xFFCA8A04)),
      'escalated' => (const Color(0xFFDBEAFE), const Color(0xFF2563EB)),
      'approved' => (const Color(0xFFDCFCE7), const Color(0xFF16A34A)),
      'rejected' => (const Color(0xFFFEE2E2), const Color(0xFFDC2626)),
      _ => (const Color(0xFFF3F4F6), const Color(0xFF6B7280)),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppTheme.radiusFull),
      ),
      child: Text(
        complaint.statusLabel,
        style: AppTheme.labelSm.copyWith(color: fg, fontWeight: FontWeight.w600),
      ),
    );
  }
}

/// "12 Okt 2026, 14:30" in the device's time zone (the API sends UTC).
String _localDateTime(String iso) {
  final local = DateTime.tryParse(iso)?.toLocal();
  if (local == null) return iso;
  return DateFormatter.format(local.toIso8601String(), pattern: 'd MMM yyyy, HH:mm');
}

/// Same wording as the web. Computed when built; the screen rebuilds often
/// enough that a ticking clock is not worth it.
String _remaining(String iso) {
  final deadline = DateTime.tryParse(iso);
  return deadline == null ? '' : complaintTimeLeft(deadline, DateTime.now());
}

String complaintTimeLeft(DateTime deadline, DateTime now) {
  final left = deadline.difference(now);
  if (left.isNegative) return 'Batas waktu lewat, komplain segera diteruskan ke admin.';
  if (left.inMinutes < 60) return 'Sisa kurang dari 1 jam.';
  final hours = left.inHours;
  final days = hours ~/ 24;
  return days > 0 ? 'Sisa $days hari ${hours % 24} jam.' : 'Sisa $hours jam.';
}
