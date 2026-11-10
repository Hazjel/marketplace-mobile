import 'package:flutter_test/flutter_test.dart';
import 'package:blukios_marketplace/features/transaction/models/ship_deadline.dart';
import 'package:blukios_marketplace/features/transaction/models/transaction_model.dart';

// Ported from fe-blue useTransactionStatus.test.js `resolveShipDeadline`.
void main() {
  final now = DateTime.utc(2026, 11, 2, 9);

  TransactionModel order({
    String paymentStatus = 'paid',
    String deliveryStatus = 'pending',
    String? shipDeadlineAt = '2026-11-05T09:00:00Z',
  }) =>
      TransactionModel(
        id: 't1',
        code: 'TRX-1',
        shippingCost: 0,
        deliveryStatus: deliveryStatus,
        tax: 0,
        grandTotal: 1000,
        paymentStatus: paymentStatus,
        shipDeadlineAt: shipDeadlineAt,
        transactionDetails: const [],
      );

  ShipDeadline? resolve(TransactionModel o) => resolveShipDeadline(o, now: now);

  test('only applies to paid orders that are not shipped yet', () {
    expect(resolve(order(deliveryStatus: 'processing')), isNotNull);
    expect(resolve(order(deliveryStatus: 'delivering')), isNull);
    expect(resolve(order(deliveryStatus: 'cancelled')), isNull);
    expect(resolve(order(paymentStatus: 'unpaid')), isNull);
    expect(resolve(order(shipDeadlineAt: null)), isNull);
  });

  test('counts down and turns urgent in the last day', () {
    final days = resolve(order())!;
    expect(days.remaining, 'Sisa 3 hari 0 jam.');
    expect(days.urgent, isFalse);

    final hours = resolve(order(shipDeadlineAt: '2026-11-02T14:30:00Z'))!;
    expect(hours.remaining, 'Sisa 5 jam.');
    expect(hours.urgent, isTrue);

    expect(resolve(order(shipDeadlineAt: '2026-11-02T09:30:00Z'))!.remaining,
        'Sisa kurang dari 1 jam.');
    final late = resolve(order(shipDeadlineAt: '2026-11-02T08:00:00Z'))!;
    expect(late.remaining, 'Batas waktu lewat, pesanan segera dibatalkan otomatis.');
    expect(late.urgent, isTrue);
  });

  test('boundaries: 24 h is not urgent, 1 h is "Sisa 1 jam", 0 is under an hour', () {
    final day = resolve(order(shipDeadlineAt: '2026-11-03T09:00:00Z'))!;
    expect(day.remaining, 'Sisa 1 hari 0 jam.');
    expect(day.urgent, isFalse);
    expect(resolve(order(shipDeadlineAt: '2026-11-03T08:59:00Z'))!.urgent, isTrue);
    expect(resolve(order(shipDeadlineAt: '2026-11-02T10:00:00Z'))!.remaining, 'Sisa 1 jam.');
    expect(resolve(order(shipDeadlineAt: '2026-11-02T09:00:00Z'))!.remaining,
        'Sisa kurang dari 1 jam.');
    // A deadline 30 minutes ago floors to -1 h, like the web.
    expect(resolve(order(shipDeadlineAt: '2026-11-02T08:30:00Z'))!.remaining,
        startsWith('Batas waktu lewat'));
  });

  test('label is "d MMM yyyy, HH:mm" in the device time zone with Indonesian months', () {
    String two(int n) => n.toString().padLeft(2, '0');
    String expected(DateTime utc, String month) {
      final l = utc.toLocal();
      return '${l.day} $month ${l.year}, ${two(l.hour)}:${two(l.minute)}';
    }

    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
    // Mid-month at noon UTC: the same calendar month in every time zone.
    for (var m = 1; m <= 12; m++) {
      final d = DateTime.utc(2027, m, 15, 12, 5);
      expect(resolve(order(shipDeadlineAt: d.toIso8601String()))!.at, expected(d, months[m - 1]));
    }
  });

  test('an unparsable deadline hides the block instead of throwing', () {
    expect(resolve(order(shipDeadlineAt: 'soon')), isNull);
  });
}
