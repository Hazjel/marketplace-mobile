import 'package:blukios_marketplace/core/utils/json.dart';

/// Store shape returned by the seller-facing endpoints (`/register-store`,
/// `/my-store`, `PUT /store/{id}`) — i.e. `StoreResource` from the API.
///
/// Deliberately separate from `features/store/models/store_model.dart`
/// (the buyer-facing public store shape): this one carries fields buyers
/// never see (`addressId`, `aiAssistantEnabled`) and is missing fields the
/// public resource has no use for.
///
/// IMPORTANT: [addressId] is NOT a foreign key to an `addresses` row —
/// it's a Komerce shipping-destination id, used directly as
/// `shipper_destination_id` when buyers calculate shipping
/// (see `CheckoutNotifier.calculateShipping`). Always populate/update it
/// via the destination search (`/shipment/destination`), never free text.
class SellerStoreModel {
  final String id;
  final String name;
  final String username;
  final String? logo;
  final String? about;
  final String? phone;
  final String? addressId;
  final String? city;
  final String? address;
  final String? postalCode;
  final double? latitude;
  final double? longitude;
  final bool isVerified;
  final bool aiAssistantEnabled;
  final int productCount;
  final int transactionCount;
  final DateTime? createdAt;

  SellerStoreModel({
    required this.id,
    required this.name,
    required this.username,
    this.logo,
    this.about,
    this.phone,
    this.addressId,
    this.city,
    this.address,
    this.postalCode,
    this.latitude,
    this.longitude,
    required this.isVerified,
    required this.aiAssistantEnabled,
    required this.productCount,
    required this.transactionCount,
    this.createdAt,
  });

  factory SellerStoreModel.fromJson(Map<String, dynamic> json) {
    return SellerStoreModel(
      id: json.asString('id'),
      name: json.asString('name'),
      username: json.asString('username'),
      logo: json.asStringOrNull('logo'),
      about: json.asStringOrNull('about'),
      phone: json.asStringOrNull('phone'),
      addressId: json.asStringOrNull('address_id'),
      city: json.asStringOrNull('city'),
      address: json.asStringOrNull('address'),
      postalCode: json.asStringOrNull('postal_code'),
      latitude: json['latitude'] != null ? (json['latitude'] as num).toDouble() : null,
      longitude: json['longitude'] != null ? (json['longitude'] as num).toDouble() : null,
      isVerified: json.asBool('is_verified'),
      aiAssistantEnabled: json.asBool('ai_assistant_enabled'),
      productCount: json.asInt('product_count'),
      transactionCount: json.asInt('transaction_count'),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
    );
  }
}
