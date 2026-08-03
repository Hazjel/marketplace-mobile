import 'package:blukios_marketplace/core/utils/json.dart';

class ReviewAttachment {
  final String id;
  final String filePath;
  final String fileType; // "image" | "video"

  ReviewAttachment({
    required this.id,
    required this.filePath,
    required this.fileType,
  });

  bool get isVideo => fileType == 'video';

  factory ReviewAttachment.fromJson(Map<String, dynamic> json) {
    return ReviewAttachment(
      id: json.asString('id'),
      filePath: json.asString('file_path'),
      fileType: json.asString('file_type', 'image'),
    );
  }
}

class ReviewModel {
  final String id;
  final String productId;
  final int rating;
  final String? review;
  final bool isAnonymous;
  final String userName;
  final String? userAvatar;
  final String? createdAt;
  final List<ReviewAttachment> attachments;

  ReviewModel({
    required this.id,
    required this.productId,
    required this.rating,
    this.review,
    required this.isAnonymous,
    required this.userName,
    this.userAvatar,
    this.createdAt,
    this.attachments = const [],
  });

  factory ReviewModel.fromJson(Map<String, dynamic> json) {
    final user = json['user'];
    final rawAttachments = json['attachments'];

    // When is_anonymous the API masks the name ("F***h") and sends the
    // literal string "default-avatar-url" rather than a real URL.
    final avatar = user is Map ? user['avatar']?.toString() : null;

    return ReviewModel(
      id: json.asString('id'),
      productId: json.asString('product_id'),
      rating: json.asInt('rating'),
      review: json.asStringOrNull('review'),
      isAnonymous: json.asBool('is_anonymous'),
      userName: user is Map ? (user['name']?.toString() ?? 'Pengguna') : 'Pengguna',
      userAvatar: (avatar == null || avatar == 'default-avatar-url') ? null : avatar,
      createdAt: json.asStringOrNull('created_at'),
      attachments: rawAttachments is List
          ? rawAttachments
              .whereType<Map<String, dynamic>>()
              .map(ReviewAttachment.fromJson)
              .toList()
          : const [],
    );
  }
}
