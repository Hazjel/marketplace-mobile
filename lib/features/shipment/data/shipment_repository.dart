import 'package:blukios_marketplace/config/api_config.dart';
import 'package:blukios_marketplace/core/network/api_client.dart';
import 'package:blukios_marketplace/features/shipment/models/courier_option_model.dart';
import 'package:blukios_marketplace/features/shipment/models/reverse_geocode_result_model.dart';
import 'package:blukios_marketplace/features/shipment/models/shipment_destination_model.dart';

class ShipmentRepository {
  final ApiClient _apiClient;

  ShipmentRepository(this._apiClient);

  Future<List<ShipmentDestinationModel>> searchDestination(String keyword) async {
    final response = await _apiClient.get(ApiConfig.shipmentDestination, queryParameters: {
      'keyword': keyword,
    });
    final List data = response.data['data'];
    return data.map((e) => ShipmentDestinationModel.fromJson(e)).toList();
  }

  Future<List<CourierOptionModel>> calculate({
    required String shipperDestinationId,
    required String receiverDestinationId,
    required double itemValue,
    required double weight,
    String? receiverCityName,
  }) async {
    final response = await _apiClient.get(ApiConfig.shipmentCalculate, queryParameters: {
      'shipper_destination_id': shipperDestinationId,
      'receiver_destination_id': receiverDestinationId,
      'item_value': itemValue,
      'weight': weight,
      if (receiverCityName != null) 'receiver_city_name': receiverCityName,
    });
    final List data = response.data['data']['calculate_reguler'];
    return data.map((e) => CourierOptionModel.fromJson(e)).toList();
  }

  /// Null saat lokasinya tidak dikenali (backend membalas 404) atau saat
  /// panggilan gagal -- pemanggil (tombol GPS di form alamat) memperlakukan
  /// keduanya sama: biarkan pengguna mengisi manual.
  Future<ReverseGeocodeResult?> reverseGeocode(double lat, double lon) async {
    try {
      final response = await _apiClient.get(ApiConfig.shipmentReverseGeocode, queryParameters: {
        'lat': lat,
        'lon': lon,
      });
      final data = response.data['data'];
      if (data is! Map<String, dynamic>) return null;
      return ReverseGeocodeResult.fromJson(data);
    } catch (_) {
      return null;
    }
  }
}
