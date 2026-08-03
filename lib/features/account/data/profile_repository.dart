import 'package:dio/dio.dart';
import 'package:blukios_marketplace/config/api_config.dart';
import 'package:blukios_marketplace/core/network/api_client.dart';
import 'package:blukios_marketplace/features/auth/models/user_model.dart';

class ProfileRepository {
  final ApiClient _apiClient;

  ProfileRepository(this._apiClient);

  Future<UserModel> getProfile() async {
    final response = await _apiClient.get(ApiConfig.me);
    return UserModel.fromJson(response.data['data']);
  }

  /// Updates name / phone / password.
  ///
  /// Sent as multipart `POST` with `_method=PUT` because Laravel cannot
  /// parse a file (or reliably parse fields) out of a raw PUT body —
  /// this is required as soon as [avatarPath] is present, and harmless
  /// otherwise, so we use one code path for both.
  Future<UserModel> updateProfile({
    required String name,
    String? phoneNumber,
    String? currentPassword,
    String? newPassword,
    String? avatarPath,
  }) async {
    final form = FormData.fromMap({
      '_method': 'PUT',
      'name': name,
      if (phoneNumber != null && phoneNumber.isNotEmpty)
        'phone_number': phoneNumber,
      if (newPassword != null && newPassword.isNotEmpty) ...{
        'password': newPassword,
        'current_password': currentPassword ?? '',
      },
      if (avatarPath != null)
        'profile_picture': await MultipartFile.fromFile(avatarPath),
    });

    final response = await _apiClient.post(ApiConfig.profile, data: form);
    return UserModel.fromJson(response.data['data']);
  }

  /// Partial update — the API merges against existing prefs and drops
  /// unknown keys, so sending only the changed group is safe.
  Future<UserModel> updateSettings({
    Map<String, bool>? notificationPrefs,
    Map<String, bool>? privacyPrefs,
  }) async {
    final response = await _apiClient.put(
      ApiConfig.profileSettings,
      data: {
        if (notificationPrefs != null) 'notification_prefs': notificationPrefs,
        if (privacyPrefs != null) 'privacy_prefs': privacyPrefs,
      },
    );
    return UserModel.fromJson(response.data['data']);
  }
}
