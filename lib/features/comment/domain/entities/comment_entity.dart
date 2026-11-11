// features/comment/domain/entities/comment_entity.dart

import 'package:equatable/equatable.dart';
import '../../../../shared/domain/entities/base_entity.dart';

class CommentEntity extends Equatable {
  final String id;
  final String videoId;
  final String userId;
  final ProfileStub user;
  final String? parentId;
  final String? rootId;
  final String? replyToUsername;
  final String? replyToDisplayName;
  final String? replyToContent;
  final String content;
  final int likeCount;
  final int replyCount;
  final String status; // visible | hidden | deleted
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isLiked;
  final List<CommentEntity> replies;
  final int loadedReplyPage;
  final bool hasMoreReplies;
  final bool isLoadingReplies;
  final bool isRepliesCollapsed;

  const CommentEntity({
    required this.id,
    required this.videoId,
    required this.userId,
    required this.user,
    this.parentId,
    this.rootId,
    this.replyToUsername,
    this.replyToDisplayName,
    this.replyToContent,
    required this.content,
    this.likeCount = 0,
    this.replyCount = 0,
    this.status = 'visible',
    required this.createdAt,
    required this.updatedAt,
    this.isLiked = false,
    this.replies = const [],
    this.loadedReplyPage = -1,
    this.hasMoreReplies = false,
    this.isLoadingReplies = false,
    this.isRepliesCollapsed = false,
  });

  CommentEntity copyWith({
    String? rootId,
    String? replyToUsername,
    String? replyToDisplayName,
    String? replyToContent,
    bool? isLiked,
    int? likeCount,
    int? replyCount,
    List<CommentEntity>? replies,
    int? loadedReplyPage,
    bool? hasMoreReplies,
    bool? isLoadingReplies,
    bool? isRepliesCollapsed,
  }) =>
      CommentEntity(
        id: id,
        videoId: videoId,
        userId: userId,
        user: user,
        parentId: parentId,
        rootId: rootId ?? this.rootId,
        replyToUsername: replyToUsername ?? this.replyToUsername,
        replyToDisplayName: replyToDisplayName ?? this.replyToDisplayName,
        replyToContent: replyToContent ?? this.replyToContent,
        content: content,
        likeCount: likeCount ?? this.likeCount,
        replyCount: replyCount ?? this.replyCount,
        status: status,
        createdAt: createdAt,
        updatedAt: updatedAt,
        isLiked: isLiked ?? this.isLiked,
        replies: replies ?? this.replies,
        loadedReplyPage: loadedReplyPage ?? this.loadedReplyPage,
        hasMoreReplies: hasMoreReplies ?? this.hasMoreReplies,
        isLoadingReplies: isLoadingReplies ?? this.isLoadingReplies,
        isRepliesCollapsed: isRepliesCollapsed ?? this.isRepliesCollapsed,
      );

  @override
  List<Object?> get props => [
        id,
        videoId,
        userId,
        parentId,
        rootId,
        replyToUsername,
        replyToContent,
        content,
        likeCount,
        replyCount,
        isLiked,
        replies,
        loadedReplyPage,
        hasMoreReplies,
        isLoadingReplies,
        isRepliesCollapsed,
      ];
}
