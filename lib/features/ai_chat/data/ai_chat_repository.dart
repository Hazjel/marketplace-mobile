import 'package:dio/dio.dart';
import 'package:blukios_marketplace/config/api_config.dart';
import 'package:blukios_marketplace/core/network/api_exceptions.dart';
import 'package:blukios_marketplace/features/ai_chat/models/ai_chat_models.dart';

/// Client chat-service (chatbot RAG), dilayani di `/ai`, sejajar `/api`.
///
/// Dio sendiri seperti `RecommendationRepository`: `ApiClient` dipaku ke
/// `ApiConfig.baseUrl` dan memasang bearer token yang endpoint ini tidak butuh.
/// Berbeda dari rekomendasi, kegagalan di sini tidak boleh diam: pengguna
/// sedang menunggu jawaban pertanyaannya. Memakai `/predict` non-streaming,
/// sementara web memakai `/predict/stream`.
class AiChatRepository {
  final Dio _dio;

  AiChatRepository({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              baseUrl: ApiConfig.aiBaseUrl,
              connectTimeout: ApiConfig.connectTimeout,
              receiveTimeout: ApiConfig.aiReceiveTimeout,
              headers: {
                'Content-Type': 'application/json',
                'Accept': 'application/json',
              },
            ));

  /// Mengirim satu pertanyaan. [sessionId] null hanya pada pesan pertama;
  /// setelah itu id dari balasan harus dikirim balik supaya chat-service
  /// mengingat riwayat percakapan di Redis.
  Future<AiChatReply> ask({required String message, String? sessionId}) async {
    try {
      final response = await _dio.post(
        ApiConfig.aiPredict,
        data: {
          'message': message,
          if (sessionId != null) 'session_id': sessionId,
        },
      );
      final data = response.data;
      if (data is! Map<String, dynamic>) {
        throw ApiException(message: 'Balasan chatbot tidak dikenali.');
      }
      return AiChatReply.fromJson(data);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }
}
