import 'package:blukios_marketplace/config/api_config.dart';
import 'package:blukios_marketplace/core/network/api_client.dart';
import 'package:blukios_marketplace/features/address/models/address_model.dart';

class AddressRepository {
  final ApiClient _apiClient;

  AddressRepository(this._apiClient);

  Future<List<AddressModel>> getAddresses() async {
    final response = await _apiClient.get(ApiConfig.address);
    final List data = response.data['data'];
    return data.map((e) => AddressModel.fromJson(e)).toList();
  }

  Future<AddressModel> createAddress(AddressModel address) async {
    final response = await _apiClient.post(ApiConfig.address, data: address.toJson());
    return AddressModel.fromJson(response.data['data']);
  }

  Future<AddressModel> updateAddress(String id, AddressModel address) async {
    final response = await _apiClient.put('${ApiConfig.address}/$id', data: address.toJson());
    return AddressModel.fromJson(response.data['data']);
  }

  Future<void> deleteAddress(String id) async {
    await _apiClient.delete('${ApiConfig.address}/$id');
  }
}
