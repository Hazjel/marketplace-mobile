class AddressModel {
  final String id;
  final String label;
  final String recipientName;
  final String phone;
  final String address;
  final String city;
  final String cityId;
  final String postalCode;
  final double? latitude;
  final double? longitude;
  final bool isPrimary;

  AddressModel({
    required this.id,
    required this.label,
    required this.recipientName,
    required this.phone,
    required this.address,
    required this.city,
    required this.cityId,
    required this.postalCode,
    this.latitude,
    this.longitude,
    required this.isPrimary,
  });

  factory AddressModel.fromJson(Map<String, dynamic> json) {
    return AddressModel(
      id: json['id'].toString(),
      label: json['label'] ?? '',
      recipientName: json['recipient_name'] ?? '',
      phone: json['phone'] ?? '',
      address: json['address'] ?? '',
      city: json['city'] ?? '',
      cityId: (json['city_id'] ?? '').toString(),
      postalCode: json['postal_code'] ?? '',
      latitude: json['latitude'] != null ? (json['latitude'] as num).toDouble() : null,
      longitude: json['longitude'] != null ? (json['longitude'] as num).toDouble() : null,
      isPrimary: json['is_primary'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'label': label,
      'recipient_name': recipientName,
      'phone': phone,
      'address': address,
      'city': city,
      'city_id': cityId,
      'postal_code': postalCode,
      'latitude': latitude,
      'longitude': longitude,
      'is_primary': isPrimary,
    };
  }
}
