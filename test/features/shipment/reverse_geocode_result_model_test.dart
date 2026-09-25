import 'package:flutter_test/flutter_test.dart';
import 'package:blukios_marketplace/features/shipment/models/reverse_geocode_result_model.dart';

void main() {
  group('ReverseGeocodeResult.streetAddress', () {
    test('prefers road + suburb over display_name', () {
      final result = ReverseGeocodeResult.fromJson({
        'display_name': 'Jl. Merdeka, Menteng, Jakarta Pusat, DKI Jakarta, Indonesia',
        'road': 'Jl. Merdeka',
        'suburb': 'Menteng',
        'city': 'Jakarta Pusat',
        'postal_code': '10310',
      });

      expect(result.streetAddress, 'Jl. Merdeka, Menteng');
    });

    test('falls back to display_name when road and suburb are absent', () {
      final result = ReverseGeocodeResult.fromJson({
        'display_name': 'Lokasi tanpa detail jalan',
      });

      expect(result.streetAddress, 'Lokasi tanpa detail jalan');
    });

    test('empty when nothing is available', () {
      final result = ReverseGeocodeResult.fromJson({});

      expect(result.streetAddress, '');
    });
  });
}
