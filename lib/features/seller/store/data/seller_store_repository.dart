import 'package:dio/dio.dart';
import 'package:blukios_marketplace/config/api_config.dart';
import 'package:blukios_marketplace/core/network/api_client.dart';
import 'package:blukios_marketplace/features/seller/store/models/seller_store_model.dart';

class SellerStoreRepository {
  final ApiClient _apiClient;

  SellerStoreRepository(this._apiClient);

  /// `POST /register-store` — upgrades the authenticated user's role to
  /// `store` server-side. Caller must refresh session via
  /// `authProvider.notifier.checkAuthStatus()` afterwards.
  Future<SellerStoreModel> registerStore({
    required String name,
    required String phone,
    String? city,
    String? address,
    String? postalCode,
    double? latitude,
    double? longitude,
  }) async {
    final response = await _apiClient.post(
      ApiConfig.registerStore,
      data: {
        'name': name,
        'phone': phone,
        if (city != null) 'city': city,
        if (address != null) 'address': address,
        if (postalCode != null) 'postal_code': postalCode,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
      },
    );
    return SellerStoreModel.fromJson(response.data['data'] as Map<String, dynamic>);
  }

  /// `GET /my-store` — returns null when the user hasn't registered a
  /// store yet (API responds `success: true, data: null`).
  Future<SellerStoreModel?> getMyStore() async {
    final response = await _apiClient.get(ApiConfig.myStore);
    final data = response.data['data'];
    if (data == null) return null;
    return SellerStoreModel.fromJson(data as Map<String, dynamic>);
  }

  /// `PUT /store/{id}` — sent as `POST` with Laravel's `_method` spoofing
  /// field, matching the web app (`fe-blue/src/stores/store.js`). Laravel
  /// cannot parse a multipart body on a real PUT request (a PHP
  /// limitation), so a genuine PUT here would silently drop the `logo`
  /// file and any other fields.
  ///
  /// [addressId] must come from the `/shipment/destination` search — see
  /// the class doc on [SellerStoreModel.addressId].
  Future<SellerStoreModel> updateStore({
    required String id,
    required String name,
    required String about,
    required String phone,
    required String addressId,
    required String city,
    required String address,
    required String postalCode,
    double? latitude,
    double? longitude,
    bool? aiAssistantEnabled,
    String? logoPath,
  }) async {
    final form = FormData.fromMap({
      'name': name,
      'about': about,
      'phone': phone,
      'address_id': addressId,
      'city': city,
      'address': address,
      'postal_code': postalCode,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (aiAssistantEnabled != null)
        'ai_assistant_enabled': aiAssistantEnabled ? 1 : 0,
      '_method': 'PUT',
      if (logoPath != null) 'logo': await MultipartFile.fromFile(logoPath),
    });

    final response = await _apiClient.post(ApiConfig.storeById(id), data: form);
    return SellerStoreModel.fromJson(response.data['data'] as Map<String, dynamic>);
  }
}
