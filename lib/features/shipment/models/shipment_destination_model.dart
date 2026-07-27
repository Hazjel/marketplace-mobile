class ShipmentDestinationModel {
  final String id;
  final String label;
  final String cityName;
  final String zipCode;

  ShipmentDestinationModel({
    required this.id,
    required this.label,
    required this.cityName,
    required this.zipCode,
  });

  factory ShipmentDestinationModel.fromJson(Map<String, dynamic> json) {
    return ShipmentDestinationModel(
      id: (json['id'] ?? '').toString(),
      label: json['label'] ?? '',
      cityName: json['city_name'] ?? '',
      zipCode: (json['zip_code'] ?? '').toString(),
    );
  }
}
