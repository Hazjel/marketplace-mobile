import 'package:flutter_test/flutter_test.dart';
import 'package:blukios_marketplace/features/transaction/models/transaction_model.dart';

Map<String, dynamic> _fixture({Object? discountAmount = 5000}) => {
      'id': 't1',
      'code': 'INV-1',
      'delivery_status': 'delivering',
      'shipping_cost': 15000,
      'tax': 11006,
      'grand_total': 121006,
      'discount_amount': discountAmount,
      'payment_status': 'paid',
      'transaction_details': [
        {'id': 'd1', 'product_id': 'p1', 'qty': 1, 'subtotal': 100000},
      ],
    };

void main() {
  group('TransactionModel.fromJson', () {
    // Sprint C1 (money-json-contract.md): shipping_cost/tax/grand_total/
    // discount_amount/subtotal are always a JSON integer now, never a
    // decimal:2 string or a float.
    test('parses the C1 integer money contract', () {
      final t = TransactionModel.fromJson(_fixture());

      expect(t.shippingCost, 15000.0);
      expect(t.tax, 11006.0);
      expect(t.grandTotal, 121006.0);
      expect(t.discountAmount, 5000.0);
      expect(t.transactionDetails.single.subtotal, 100000.0);
    });

    test('a zero discount is still a valid integer, not treated as missing', () {
      final t = TransactionModel.fromJson(_fixture(discountAmount: 0));
      expect(t.discountAmount, 0.0);
    });

    // Review fix on the backend (PR #19): pre-B3.2c a percentage voucher's
    // discount was `round($discount, 2)`, so a legacy transaction can carry
    // a fractional discount_amount ("10000.50"). TransactionResource now
    // throws on it rather than truncating -- the mobile client must fail
    // the same way, not silently show the wrong (truncated) amount.
    test('throws on a legacy fractional discount_amount instead of truncating', () {
      expect(
        () => TransactionModel.fromJson(_fixture(discountAmount: '10000.50')),
        throwsA(isA<FormatException>()),
      );
    });

    test('parses the service fee and refund state', () {
      final t = TransactionModel.fromJson(_fixture()
        ..['tax'] = 0
        ..['service_fee'] = 1000
        ..['delivery_status'] = 'cancelled'
        ..['payment_status'] = 'failed'
        ..['refund_status'] = 'manual_required'
        ..['refund_amount'] = 121006
        ..['refund_reason'] = 'Stok habis'
        ..['refund_account'] = {'bank_name': 'BCA', 'account_number': '1234567890', 'account_name': 'Budi'});

      expect(t.serviceFee, 1000.0);
      expect(t.refundAmount, 121006.0);
      expect(t.refundStatusLabel, 'Menunggu Refund');
      expect(t.awaitsManualRefund, isTrue);
      expect(t.refundAccount?.accountNumber, '1234567890');
      // The refund is still moving: keep listening for live updates.
      expect(t.isTerminal, isFalse);
    });

    test('orders without refund fields parse as before', () {
      final t = TransactionModel.fromJson(_fixture());

      expect(t.serviceFee, 0.0);
      expect(t.refundStatus, isNull);
      expect(t.refundAmount, isNull);
      expect(t.refundAccount, isNull);
    });

    test('throws when a C1-contracted money field is missing', () {
      final json = _fixture()..remove('tax');
      expect(() => TransactionModel.fromJson(json), throwsA(isA<FormatException>()));
    });

    test('parses balance_used, defaulting to 0 when absent', () {
      expect(TransactionModel.fromJson(_fixture()..['balance_used'] = 20000).balanceUsed, 20000.0);
      expect(TransactionModel.fromJson(_fixture()).balanceUsed, 0.0);
    });

    test('parses the complaint when present, null when absent', () {
      final t = TransactionModel.fromJson(_fixture()
        ..['complaint'] = {'id': 'c1', 'status': 'escalated', 'reason': 'damaged'});
      expect(t.complaint?.id, 'c1');
      expect(t.complaint?.status, 'escalated');
      expect(t.hasActiveComplaint, isTrue);

      final resolved = TransactionModel.fromJson(_fixture()
        ..['complaint'] = {'id': 'c1', 'status': 'resolved_refund'});
      expect(resolved.hasActiveComplaint, isFalse);

      final none = TransactionModel.fromJson(_fixture()..['complaint'] = null);
      expect(none.complaint, isNull);
      expect(none.hasActiveComplaint, isFalse);
    });
  });

  // Mirrors api-blue App\Support\RefundMessage.
  group('TransactionModel.refundMessage', () {
    TransactionModel refund(String? status, {String? method, double? amount, double balance = 0}) =>
        TransactionModel(
          id: 't1',
          code: 'INV-1',
          shippingCost: 0,
          deliveryStatus: 'cancelled',
          tax: 0,
          grandTotal: 50000,
          paymentStatus: 'failed',
          transactionDetails: const [],
          refundStatus: status,
          refundMethod: method,
          refundAmount: amount,
          balanceUsed: balance,
        );

    test('no refund status, no message', () {
      expect(refund(null, amount: 30000).refundMessage, isNull);
    });

    test('processing', () {
      expect(refund('processing', amount: 30000).refundMessage,
          'Pesananmu dibatalkan. Pengembalian Rp 30.000 ke metode pembayaranmu sedang diproses.');
    });

    test('processing with a partial saldo payment names both parts', () {
      expect(
          refund('processing', amount: 30000, balance: 20000).refundMessage,
          'Pesananmu dibatalkan. Pengembalian Rp 30.000 ke metode pembayaranmu sedang diproses. '
          'Rp 20.000 sudah kembali ke Saldo Blukios.');
    });

    test('refunded through Midtrans', () {
      expect(
          refund('refunded', method: 'midtrans', amount: 30000).refundMessage,
          'Rp 30.000 sudah dikembalikan ke metode pembayaranmu. '
          'Waktu dana masuk mengikuti bank atau penyedia e-wallet.');
    });

    test('refunded to saldo sums both parts', () {
      expect(refund('refunded', method: 'balance', amount: 30000, balance: 20000).refundMessage,
          'Rp 50.000 sudah masuk ke Saldo Blukios dan bisa dipakai untuk belanja.');
    });

    test('refunded by manual transfer', () {
      expect(refund('refunded', method: 'manual', amount: 30000).refundMessage,
          'Rp 30.000 sudah ditransfer ke rekening yang kamu isi.');
    });

    test('manual_required', () {
      expect(
          refund('manual_required', amount: 30000, balance: 20000).refundMessage,
          'Pengembalian dana Rp 30.000 sedang kami periksa dan akan segera diselesaikan. '
          'Rp 20.000 sudah kembali ke Saldo Blukios.');
    });

    test('paid fully with saldo: only the saldo part is mentioned', () {
      expect(refund('processing', amount: 0, balance: 20000).refundMessage,
          'Pesananmu dibatalkan. Rp 20.000 sudah kembali ke Saldo Blukios.');
    });

    test('both parts zero, no message', () {
      expect(refund('processing', amount: 0).refundMessage, isNull);
    });
  });
}
