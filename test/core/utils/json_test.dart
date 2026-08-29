import 'package:flutter_test/flutter_test.dart';
import 'package:blukios_marketplace/core/utils/json.dart';

void main() {
  group('JsonCast.asInt', () {
    test('parses a plain integer string', () {
      expect({'v': '7'}.asInt('v'), 7);
    });

    // Laravel's 'decimal:2' cast (e.g. ProductVariantMongo::price) always
    // serializes as a string with two decimal places, even before the
    // ProductVariantResource normalization fix -- int.tryParse('150000.00')
    // returns null (it doesn't accept a decimal point), which silently fell
    // back to 0. This is the real API contract shape, not a hypothetical.
    test('parses a decimal-string like Laravel decimal-cast fields ("150000.00")', () {
      expect({'v': '150000.00'}.asInt('v'), 150000);
    });

    test('falls back on a genuinely unparseable string', () {
      expect({'v': 'not-a-number'}.asInt('v', 99), 99);
    });

    test('passes through an int as-is', () {
      expect({'v': 7}.asInt('v'), 7);
    });

    test('truncates a double', () {
      expect({'v': 7.9}.asInt('v'), 7);
    });

    test('falls back when the key is absent', () {
      expect(<String, dynamic>{}.asInt('v', 42), 42);
    });
  });
}
