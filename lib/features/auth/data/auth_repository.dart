import 'package:blukios_marketplace/config/api_config.dart';
import 'package:blukios_marketplace/core/network/api_client.dart';
import 'package:blukios_marketplace/core/storage/secure_storage.dart';
import 'package:blukios_marketplace/features/auth/models/user_model.dart';

class AuthRepository {
  final ApiClient _apiClient;

  AuthRepository(this._apiClient);

  Future<UserModel> login(String email, String password) async {
    final response = await _apiClient.post(ApiConfig.login, data: {
      'email': email,
      'password': password,
    });

    final user = UserModel.fromJson(response.data['data']);
    await SecureStorage.saveToken(user.token!);
    return user;
  }

  Future<UserModel> register({
    required String name,
    required String email,
    required String password,
    required String phoneNumber,
    required String role,
  }) async {
    final response = await _apiClient.post(ApiConfig.register, data: {
      'name': name,
      'email': email,
      'password': password,
      'phone_number': phoneNumber,
      'role': role,
    });

    final user = UserModel.fromJson(response.data['data']);
    await SecureStorage.saveToken(user.token!);
    return user;
  }

  Future<UserModel> getProfile() async {
    final response = await _apiClient.get(ApiConfig.me);
    return UserModel.fromJson(response.data['data']);
  }

  Future<void> logout() async {
    await _apiClient.post(ApiConfig.logout);
    await SecureStorage.clearAll();
  }
}
