import 'package:blukios_marketplace/config/api_config.dart';
import 'package:blukios_marketplace/core/network/api_client.dart';
import 'package:blukios_marketplace/features/chat/models/chat_models.dart';

class ChatRepository {
  final ApiClient _apiClient;

  ChatRepository(this._apiClient);

  Future<List<ChatContact>> getContacts() async {
    final response = await _apiClient.get(ApiConfig.chatContacts);
    final List data = response.data['data'] ?? [];
    return data
        .whereType<Map<String, dynamic>>()
        .map(ChatContact.fromJson)
        .toList();
  }

  /// Fetches the thread with [userId], oldest first. Side effect: the
  /// server marks incoming messages in this thread as read.
  Future<List<MessageModel>> getMessages(String userId) async {
    final response = await _apiClient.get(ApiConfig.chatMessages(userId));
    final List data = response.data['data'] ?? [];
    return data
        .whereType<Map<String, dynamic>>()
        .map(MessageModel.fromJson)
        .toList();
  }

  /// Sends a message.
  ///
  /// [socketId] should be the live websocket's id when one exists: the
  /// backend broadcasts with `->toOthers()`, so passing it stops our own
  /// message coming back over the socket and appearing twice.
  Future<MessageModel> sendMessage({
    required String receiverId,
    required String message,
    String? socketId,
  }) async {
    final response = await _apiClient.post(
      ApiConfig.chatSend,
      data: {'receiver_id': receiverId, 'message': message},
      headers: socketId == null ? null : {'X-Socket-ID': socketId},
    );
    return MessageModel.fromJson(response.data['data'] as Map<String, dynamic>);
  }

  /// Basic profile for a chat partner — used when opening a thread from
  /// a product or store page, where we have an id but no contact entry.
  Future<ChatContact?> getUserInfo(String userId) async {
    final response = await _apiClient.get(ApiConfig.chatUser(userId));
    final data = response.data['data'];
    if (data == null) return null;
    return ChatContact.fromJson(data as Map<String, dynamic>);
  }
}
