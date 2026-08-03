import 'package:blukios_marketplace/core/utils/json.dart';

class StoreModel {
  final String id;
  final String name;
  final String username;
  final String? logo;
  final String? about;
  final String? phone;
  final String? city;
  final String? address;
  final String? postalCode;
  final bool isVerified;
  final int productCount;
  final int transactionCount;

  /// Metres from the query point. Absent unless `lat`/`lng` were sent —
  /// the API omits the key entirely rather than sending null.
  final double? distanceM;

  StoreModel({
    required this.id,
    required this.name,
    required this.username,
    this.logo,
    this.about,
    this.phone,
    this.city,
    this.address,
    this.postalCode,
    required this.isVerified,
    required this.productCount,
    required this.transactionCount,
    this.distanceM,
  });

  factory StoreModel.fromJson(Map<String, dynamic> json) {
    return StoreModel(
      id: json.asString('id'),
      name: json.asString('name'),
      username: json.asString('username'),
      logo: json.asStringOrNull('logo'),
      about: json.asStringOrNull('about'),
      phone: json.asStringOrNull('phone'),
      city: json.asStringOrNull('city'),
      address: json.asStringOrNull('address'),
      postalCode: json.asStringOrNull('postal_code'),
      isVerified: json.asBool('is_verified'),
      productCount: json.asInt('product_count'),
      transactionCount: json.asInt('transaction_count'),
      distanceM: json.containsKey('distance_m') ? json.asDouble('distance_m') : null,
    );
  }

  /// Human-readable distance, or null when the store wasn't fetched with
  /// coordinates.
  String? get distanceLabel {
    final metres = distanceM;
    if (metres == null) return null;
    if (metres < 1000) return '${metres.round()} m';
    return '${(metres / 1000).toStringAsFixed(1)} km';
  }
}
