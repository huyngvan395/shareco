// features/comment/data/models/comment_model.dart

import '../../../../shared/data/models/profile_stub_model.dart';
import '../../domain/entities/comment_entity.dart';

class CommentModel extends CommentEntity {
  const CommentModel({
    required super.id,
    required super.videoId,
    required super.userId,
    required super.user,
    super.parentId,
    required super.content,
    super.likeCount,
    super.replyCount,
    super.status,
    required super.createdAt,
    required super.updatedAt,
    super.isLiked,
    super.replies,
  });

  factory CommentModel.fromJson(Map<String, dynamic> json,
      {bool isLiked = false}) {
    final userJson = json['profiles'] as Map<String, dynamic>? ?? {};
    return CommentModel(
      id: json['id'] as String,
      videoId: json['video_id'] as String,
      userId: json['user_id'] as String,
      user: ProfileStubModel.fromJson({'id': json['user_id'], ...userJson}),
      parentId: json['parent_id'] as String?,
      content: json['content'] as String,
      likeCount: (json['like_count'] as num?)?.toInt() ?? 0,
      replyCount: (json['reply_count'] as num?)?.toInt() ?? 0,
      status: (json['status'] as String?) ?? 'visible',
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      isLiked: isLiked,
    );
  }
}