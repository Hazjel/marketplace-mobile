import 'package:flutter_test/flutter_test.dart';
import 'package:blukios_marketplace/features/checkout/models/voucher_model.dart';

void main() {
  group('VoucherModel.fromJson (POST /voucher/validate response)', () {
    test('parses the integer discount_amount the C1 contract guarantees', () {
      final v = VoucherModel.fromJson({
        'voucher_id': 'v1',
        'code': 'HEMAT',
        'discount_amount': 5000,
      });

      expect(v.discountAmount, 5000.0);
    });

    test('throws instead of defaulting to 0 when discount_amount is missing', () {
      expect(
        () => VoucherModel.fromJson({'voucher_id': 'v1', 'code': 'HEMAT'}),
        throwsA(isA<FormatException>()),
      );
    });

    test('throws on a decimal-string discount_amount instead of truncating', () {
      expect(
        () => VoucherModel.fromJson({
          'voucher_id': 'v1',
          'code': 'HEMAT',
          'discount_amount': '5000.00',
        }),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
