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

  // Sprint C1's money-json-contract.md guarantees these fields are already
  // a JSON integer, never a float -- unlike asInt (above), which exists
  // precisely because the API *used* to leak decimal-cast strings.
  // moneyInt must NOT repeat that leniency: a missing/fractional/string/
  // float-typed value there is now a contract violation and has to
  // surface, not silently become 0 or get coerced away.
  group('JsonCast.moneyInt', () {
    test('accepts a JSON integer', () {
      expect({'v': 150000}.moneyInt('v'), 150000);
    });

    // A whole-valued double (150000.0) is still a wire-contract regression
    // -- the contract is "JSON integer, never float" -- so it must throw,
    // not get silently coerced to int.
    test('throws on a whole-valued double instead of coercing it', () {
      expect(() => {'v': 150000.0}.moneyInt('v'), throwsFormatException);
    });

    test('throws on a fractional double instead of truncating', () {
      expect(() => {'v': 150000.5}.moneyInt('v'), throwsFormatException);
    });

    test('throws on a decimal string instead of parsing it', () {
      expect(() => {'v': '150000.00'}.moneyInt('v'), throwsFormatException);
    });

    test('throws on an integer-looking string instead of parsing it', () {
      expect(() => {'v': '150000'}.moneyInt('v'), throwsFormatException);
    });

    test('throws when the key is missing', () {
      expect(() => <String, dynamic>{}.moneyInt('v'), throwsFormatException);
    });

    test('throws when the value is null', () {
      expect(() => {'v': null}.moneyInt('v'), throwsFormatException);
    });
  });

  group('JsonCast.moneyIntOrNull', () {
    test('returns null when the key is missing', () {
      expect(<String, dynamic>{}.moneyIntOrNull('v'), isNull);
    });

    test('returns null when the value is JSON null', () {
      expect({'v': null}.moneyIntOrNull('v'), isNull);
    });

    test('still throws when present with a decimal-string value', () {
      expect(() => {'v': '5000.50'}.moneyIntOrNull('v'), throwsFormatException);
    });

    test('still throws when present with a whole-valued double', () {
      expect(() => {'v': 5000.0}.moneyIntOrNull('v'), throwsFormatException);
    });

    test('returns the value when present and valid', () {
      expect({'v': 5000}.moneyIntOrNull('v'), 5000);
    });
  });

  group('JsonCast.moneyNum', () {
    test('accepts an int', () {
      expect({'v': 20000}.moneyNum('v'), 20000.0);
    });

    test('accepts a decimal rate', () {
      expect({'v': 10.5}.moneyNum('v'), 10.5);
    });

    test('throws on a numeric string instead of parsing it', () {
      expect(() => {'v': '10.5'}.moneyNum('v'), throwsFormatException);
    });

    test('throws when missing', () {
      expect(() => <String, dynamic>{}.moneyNum('v'), throwsFormatException);
    });
  });
}
