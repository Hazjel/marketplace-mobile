/// Balasan `GET /shipment/reverse-geocode`, diteruskan apa adanya dari
/// Nominatim lewat `NominatimGeocodingGateway::reverseGeocode()`.
class ReverseGeocodeResult {
  final String? displayName;
  final String? road;
  final String? suburb;
  final String? city;
  final String? postalCode;

  const ReverseGeocodeResult({
    this.displayName,
    this.road,
    this.suburb,
    this.city,
    this.postalCode,
  });

  /// Sama seperti web (`AddressForm.vue`): jalan + kelurahan lebih spesifik
  /// untuk alamat pengiriman daripada `display_name`, yang sering membawa
  /// nama negara/provinsi di ujungnya.
  String get streetAddress {
    final parts = [road, suburb].where((p) => p != null && p.isNotEmpty);
    if (parts.isNotEmpty) return parts.join(', ');
    return displayName ?? '';
  }

  factory ReverseGeocodeResult.fromJson(Map<String, dynamic> json) {
    return ReverseGeocodeResult(
      displayName: json['display_name']?.toString(),
      road: json['road']?.toString(),
      suburb: json['suburb']?.toString(),
      city: json['city']?.toString(),
      postalCode: json['postal_code']?.toString(),
    );
  }
}
