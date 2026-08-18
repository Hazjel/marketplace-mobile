import 'package:blukios_marketplace/config/api_config.dart';
import 'package:blukios_marketplace/core/network/api_client.dart';

/// Registers/unregisters this device's FCM token with the backend so it has
/// somewhere to send pushes to. Deliberately thin — [NotificationService]
/// owns all the Firebase Messaging specifics, this is just the HTTP call.
class DeviceTokenRepository {
  final ApiClient _apiClient;

  DeviceTokenRepository(this._apiClient);

  Future<void> register(String token, {String platform = 'android'}) async {
    await _apiClient.post(
      ApiConfig.deviceToken,
      data: {'token': token, 'platform': platform},
    );
  }

  Future<void> unregister(String token) async {
    await _apiClient.delete(
      ApiConfig.deviceToken,
      queryParameters: {'token': token},
    );
  }
}
