// features/video/data/models/video_model.dart

import '../../../../shared/data/models/profile_stub_model.dart';
import '../../domain/entities/video_entity.dart';

class VideoModel extends VideoEntity {
  const VideoModel({
    required super.id,
    required super.createdAt,
    required super.updatedAt,
    required super.authorId,
    required super.author,
    super.caption,
    super.status,
    super.visibility,
    required super.videoPath,
    super.thumbnailPath,
    super.durationMs,
    super.width,
    super.height,
    super.allowComment,
    super.allowDuet,
    super.allowStitch,
    super.viewCount,
    super.likeCount,
    super.commentCount,
    super.shareCount,
    super.productTagCount,
    super.publishedAt,
    super.isLiked,
    super.isFollowingAuthor,
  });

  factory VideoModel.fromJson(Map<String, dynamic> json,
      {bool isLiked = false, bool isFollowingAuthor = false}) {
    // Supabase join: profiles nested hoặc flat
    final authorJson = json['profiles'] as Map<String, dynamic>? ?? {};
    return VideoModel(
      id: json['id'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      authorId: json['author_id'] as String,
      author: ProfileStubModel.fromJson({
        'id': json['author_id'],
        ...authorJson,
      }),
      caption: json['caption'] as String?,
      status: (json['status'] as String?) ?? 'published',
      visibility: (json['visibility'] as String?) ?? 'public',
      videoPath: json['video_path'] as String,
      thumbnailPath: json['thumbnail_path'] as String?,
      durationMs: (json['duration_ms'] as num?)?.toInt(),
      width: (json['width'] as num?)?.toInt(),
      height: (json['height'] as num?)?.toInt(),
      allowComment: (json['allow_comment'] as bool?) ?? true,
      allowDuet: (json['allow_duet'] as bool?) ?? true,
      allowStitch: (json['allow_stitch'] as bool?) ?? true,
      viewCount: (json['view_count'] as num?)?.toInt() ?? 0,
      likeCount: (json['like_count'] as num?)?.toInt() ?? 0,
      commentCount: (json['comment_count'] as num?)?.toInt() ?? 0,
      shareCount: (json['share_count'] as num?)?.toInt() ?? 0,
      productTagCount: (json['product_tag_count'] as num?)?.toInt() ?? 0,
      publishedAt: json['published_at'] != null
          ? DateTime.parse(json['published_at'] as String)
          : null,
      isLiked: isLiked,
      isFollowingAuthor: isFollowingAuthor,
    );
  }

  Map<String, dynamic> toInsertJson() => {
    'author_id': authorId,
    'caption': caption,
    'status': status,
    'visibility': visibility,
    'video_path': videoPath,
    'thumbnail_path': thumbnailPath,
    'duration_ms': durationMs,
    'width': width,
    'height': height,
    'allow_comment': allowComment,
    'allow_duet': allowDuet,
    'allow_stitch': allowStitch,
    'published_at': status == 'published' ? DateTime.now().toIso8601String() : null,
  };
}