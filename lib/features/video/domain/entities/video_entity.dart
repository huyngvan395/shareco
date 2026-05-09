// features/video/domain/entities/video_entity.dart

import '../../../../shared/domain/entities/base_entity.dart';

class VideoEntity extends BaseEntity {
  final String authorId;
  final ProfileStub author;
  final String? caption;
  final String status;       // draft | published | blocked | deleted
  final String visibility;   // public | followers | private
  final String videoPath;    // Supabase Storage path
  final String? thumbnailPath;
  final int? durationMs;
  final int? width;
  final int? height;
  final bool allowComment;
  final bool allowDuet;
  final bool allowStitch;
  final int viewCount;
  final int likeCount;
  final int commentCount;
  final int shareCount;
  final int productTagCount;
  final DateTime? publishedAt;

  // Client-side computed
  final bool isLiked;
  final bool isFollowingAuthor;

  const VideoEntity({
    required super.id,
    required super.createdAt,
    required super.updatedAt,
    required this.authorId,
    required this.author,
    this.caption,
    this.status = 'published',
    this.visibility = 'public',
    required this.videoPath,
    this.thumbnailPath,
    this.durationMs,
    this.width,
    this.height,
    this.allowComment = true,
    this.allowDuet = true,
    this.allowStitch = true,
    this.viewCount = 0,
    this.likeCount = 0,
    this.commentCount = 0,
    this.shareCount = 0,
    this.productTagCount = 0,
    this.publishedAt,
    this.isLiked = false,
    this.isFollowingAuthor = false,
  });

  VideoEntity copyWith({
    bool? isLiked,
    int? likeCount,
    int? commentCount,
    bool? isFollowingAuthor,
  }) =>
      VideoEntity(
        id: id,
        createdAt: createdAt,
        updatedAt: updatedAt,
        authorId: authorId,
        author: author,
        caption: caption,
        status: status,
        visibility: visibility,
        videoPath: videoPath,
        thumbnailPath: thumbnailPath,
        durationMs: durationMs,
        width: width,
        height: height,
        allowComment: allowComment,
        allowDuet: allowDuet,
        allowStitch: allowStitch,
        viewCount: viewCount,
        likeCount: likeCount ?? this.likeCount,
        commentCount: commentCount ?? this.commentCount,
        shareCount: shareCount,
        productTagCount: productTagCount,
        publishedAt: publishedAt,
        isLiked: isLiked ?? this.isLiked,
        isFollowingAuthor: isFollowingAuthor ?? this.isFollowingAuthor,
      );

  @override
  List<Object?> get props => [
    ...super.props,
    authorId,
    videoPath,
    likeCount,
    commentCount,
    isLiked,
    isFollowingAuthor,
  ];
}