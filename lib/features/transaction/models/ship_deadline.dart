import 'package:blukios_marketplace/features/transaction/models/transaction_model.dart';

/// What the UI shows for a paid order the seller has not shipped yet.
/// Port of fe-blue `resolveShipDeadline` (useTransactionStatus.js).
class ShipDeadline {
  /// "12 Okt 2026, 14:30" in the device's time zone.
  final String at;

  /// "Sisa 3 hari 0 jam." etc., same wording as the web.
  final String remaining;

  /// Under 24 hours left (or already past).
  final bool urgent;

  const ShipDeadline({required this.at, required this.remaining, required this.urgent});
}

// Indonesian month abbreviations (CLDR `id`, what luxon prints on the web).
// Hard-coded so the label never depends on intl locale data being loaded.
const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];

/// The seller's ship deadline, or null when it does not apply: the order is
/// not paid, is already past `pending|processing`, or the API sent no
/// `ship_deadline_at` (older responses). [now] is injectable for tests and
/// for a ticking clock.
ShipDeadline? resolveShipDeadline(TransactionModel order, {DateTime? now}) {
  final raw = order.shipDeadlineAt;
  if (raw == null ||
      order.paymentStatus != 'paid' ||
      !const ['pending', 'processing'].contains(order.deliveryStatus)) {
    return null;
  }
  final deadline = DateTime.tryParse(raw);
  if (deadline == null) return null;

  final hours = (deadline.difference(now ?? DateTime.now()).inMilliseconds / 3600000).floor();
  final days = hours ~/ 24;
  final remaining = hours < 0
      ? 'Batas waktu lewat, pesanan segera dibatalkan otomatis.'
      : hours < 1
          ? 'Sisa kurang dari 1 jam.'
          : days > 0
              ? 'Sisa $days hari ${hours % 24} jam.'
              : 'Sisa $hours jam.';

  final local = deadline.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return ShipDeadline(
    at: '${local.day} ${_months[local.month - 1]} ${local.year}, ${two(local.hour)}:${two(local.minute)}',
    remaining: remaining,
    urgent: hours < 24,
  );
}
