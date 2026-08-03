import 'package:blukios_marketplace/core/utils/json.dart';

/// A chat message.
///
/// The API has no MessageResource — messages are serialized straight from
/// the Eloquent model, so field names come from the `messages` table.
class MessageModel {
  final String id;
  final String senderId;
  final String receiverId;
  final String message;
  final bool isRead;
  final bool isAiReply;
  final String? createdAt;

  MessageModel({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.message,
    required this.isRead,
    required this.isAiReply,
    this.createdAt,
  });

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    return MessageModel(
      id: json.asString('id'),
      senderId: json.asString('sender_id'),
      receiverId: json.asString('receiver_id'),
      message: json.asString('message'),
      isRead: json.asBool('is_read'),
      isAiReply: json.asBool('is_ai_reply'),
      createdAt: json.asStringOrNull('created_at'),
    );
  }
}

/// A conversation partner from `GET /chat/contacts`.
///
/// These are raw User models with `unread_count` and a partial
/// `last_message` injected — not a Resource, so extra keys are present
/// and ignored here.
class ChatContact {
  final String id;
  final String name;
  final String? profilePicture;
  final String? lastSeenAt;
  final int unreadCount;
  final String? lastMessage;
  final String? lastMessageAt;

  ChatContact({
    required this.id,
    required this.name,
    this.profilePicture,
    this.lastSeenAt,
    required this.unreadCount,
    this.lastMessage,
    this.lastMessageAt,
  });

  factory ChatContact.fromJson(Map<String, dynamic> json) {
    final last = json['last_message'];

    return ChatContact(
      id: json.asString('id'),
      name: json.asString('name', 'Pengguna'),
      profilePicture: json.asStringOrNull('profile_picture'),
      lastSeenAt: json.asStringOrNull('last_seen_at'),
      unreadCount: json.asInt('unread_count'),
      lastMessage: last is Map ? last['message']?.toString() : null,
      lastMessageAt: last is Map ? last['created_at']?.toString() : null,
    );
  }
}
