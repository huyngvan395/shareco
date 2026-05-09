// features/comment/domain/entities/comment_entity.dart

import 'package:equatable/equatable.dart';
import '../../../../shared/domain/entities/base_entity.dart';

class CommentEntity extends Equatable {
  final String id;
  final String videoId;
  final String userId;
  final ProfileStub user;
  final String? parentId;
  final String content;
  final int likeCount;
  final int replyCount;
  final String status; // visible | hidden | deleted
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isLiked;
  final List<CommentEntity> replies; // chỉ load khi expand

  const CommentEntity({
    required this.id,
    required this.videoId,
    required this.userId,
    required this.user,
    this.parentId,
    required this.content,
    this.likeCount = 0,
    this.replyCount = 0,
    this.status = 'visible',
    required this.createdAt,
    required this.updatedAt,
    this.isLiked = false,
    this.replies = const [],
  });

  CommentEntity copyWith({
    bool? isLiked,
    int? likeCount,
    List<CommentEntity>? replies,
  }) =>
      CommentEntity(
        id: id,
        videoId: videoId,
        userId: userId,
        user: user,
        parentId: parentId,
        content: content,
        likeCount: likeCount ?? this.likeCount,
        replyCount: replyCount,
        status: status,
        createdAt: createdAt,
        updatedAt: updatedAt,
        isLiked: isLiked ?? this.isLiked,
        replies: replies ?? this.replies,
      );

  @override
  List<Object?> get props =>
      [id, videoId, userId, content, likeCount, isLiked, replies];
}