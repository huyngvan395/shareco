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
    super.rootId,
    super.replyToUsername,
    super.replyToDisplayName,
    super.replyToContent,
    required super.content,
    super.likeCount,
    super.replyCount,
    super.status,
    required super.createdAt,
    required super.updatedAt,
    super.isLiked,
    super.replies,
    super.loadedReplyPage,
    super.hasMoreReplies,
    super.isLoadingReplies,
    super.isRepliesCollapsed,
  });

  factory CommentModel.fromJson(
    Map<String, dynamic> json, {
    bool isLiked = false,
    String? rootId,
    String? replyToUsername,
    String? replyToDisplayName,
    String? replyToContent,
    int? overrideReplyCount,
    bool? hasMoreReplies,
  }) {
    final userJson = json['profiles'] as Map<String, dynamic>? ?? {};
    final parsedReplyCount =
        overrideReplyCount ?? ((json['reply_count'] as num?)?.toInt() ?? 0);
    return CommentModel(
      id: json['id'] as String,
      videoId: json['video_id'] as String,
      userId: json['user_id'] as String,
      user: ProfileStubModel.fromJson({'id': json['user_id'], ...userJson}),
      parentId: json['parent_id'] as String?,
      rootId: rootId,
      replyToUsername: replyToUsername,
      replyToDisplayName: replyToDisplayName,
      replyToContent: replyToContent,
      content: json['content'] as String,
      likeCount: (json['like_count'] as num?)?.toInt() ?? 0,
      replyCount: parsedReplyCount,
      status: (json['status'] as String?) ?? 'visible',
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      isLiked: isLiked,
      hasMoreReplies: hasMoreReplies ?? (parsedReplyCount > 0),
    );
  }
}
