import 'package:flutter_test/flutter_test.dart';
import 'package:blukios_marketplace/features/seller/voucher/models/seller_voucher_model.dart';

Map<String, dynamic> _fixed({Object? value = 20000}) => {
      'id': 'v1',
      'code': 'FIX',
      'store_id': 's1',
      'type': 'fixed',
      'value': value,
      'min_purchase': 50000,
    };

Map<String, dynamic> _percentage({Object? value = 10.5}) => {
      'id': 'v2',
      'code': 'PCT',
      'store_id': 's1',
      'type': 'percentage',
      'value': value,
      'max_discount': 5000,
    };

void main() {
  group('SellerVoucherModel.fromJson', () {
    // money-json-contract.md: a fixed voucher's `value`, `min_purchase`
    // and `max_discount` are always whole-rupiah JSON integers.
    test('parses a fixed voucher as integer money', () {
      final v = SellerVoucherModel.fromJson(_fixed());
      expect(v.value, 20000.0);
      expect(v.minPurchase, 50000.0);
      expect(v.maxDiscount, isNull);
    });

    // A percentage voucher's `value` is a rate (e.g. 10.5 = 10.5%), the
    // documented exception -- never narrowed to int.
    test('parses a percentage voucher value as a decimal rate', () {
      final v = SellerVoucherModel.fromJson(_percentage());
      expect(v.value, closeTo(10.5, 0.001));
      expect(v.maxDiscount, 5000.0);
    });

    test('throws on a legacy decimal-string fixed value instead of truncating', () {
      expect(
        () => SellerVoucherModel.fromJson(_fixed(value: '20000.00')),
        throwsA(isA<FormatException>()),
      );
    });

    // Review fix: a fixed voucher's `value` must reject a fractional
    // *numeric* value too, not just a decimal string -- money-json-contract.md
    // says fixed `value` is a JSON integer, so 20000.5 is a contract
    // violation the same way "20000.00" is.
    test('throws on a fractional numeric fixed value instead of accepting it', () {
      expect(
        () => SellerVoucherModel.fromJson(_fixed(value: 20000.5)),
        throwsA(isA<FormatException>()),
      );
    });

    // A whole-valued double for a fixed voucher is also a wire-contract
    // regression (JSON integer, never float) and must throw, mirroring
    // moneyInt's own strictness.
    test('throws on a whole-valued double fixed value instead of coercing it', () {
      expect(
        () => SellerVoucherModel.fromJson(_fixed(value: 20000.0)),
        throwsA(isA<FormatException>()),
      );
    });

    test('a percentage rate may be a whole number, still not narrowed to int', () {
      final v = SellerVoucherModel.fromJson(_percentage(value: 10));
      expect(v.value, 10.0);
    });

    test('throws on a fractional min_purchase/max_discount instead of truncating', () {
      final json = _fixed()..['min_purchase'] = '50000.50';
      expect(() => SellerVoucherModel.fromJson(json), throwsA(isA<FormatException>()));
    });

    test('null min_purchase/max_discount stay null, not a thrown error', () {
      final json = _fixed()..remove('min_purchase');
      final v = SellerVoucherModel.fromJson(json);
      expect(v.minPurchase, isNull);
    });
  });
}
