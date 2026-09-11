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

    test('throws when a C1-contracted money field is missing', () {
      final json = _fixture()..remove('tax');
      expect(() => TransactionModel.fromJson(json), throwsA(isA<FormatException>()));
    });
  });
}
