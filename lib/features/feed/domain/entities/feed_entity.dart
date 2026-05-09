// features/feed/domain/entities/feed_entities.dart
// Pure domain entities — no dependency on Flutter or data layer

import 'package:equatable/equatable.dart';

// ─── User Entity ──────────────────────────────────────────────────────────────

class UserEntity extends Equatable {
  final String id;
  final String username;
  final String displayName;
  final String avatarUrl;
  final bool isVerified;

  const UserEntity({
    required this.id,
    required this.username,
    required this.displayName,
    required this.avatarUrl,
    this.isVerified = false,
  });

  @override
  List<Object?> get props => [id, username, displayName, avatarUrl, isVerified];
}

// ─── Feed Item Type ───────────────────────────────────────────────────────────

enum FeedItemType { video, post }

// ─── Video Post Entity ────────────────────────────────────────────────────────

class VideoPostEntity extends Equatable {
  final String id;
  final UserEntity user;
  final String videoUrl;
  final String thumbnailUrl;
  final String caption;
  final String musicTag;
  final int likes;
  final int comments;
  final int shares;
  final bool isLiked;

  const VideoPostEntity({
    required this.id,
    required this.user,
    required this.videoUrl,
    required this.thumbnailUrl,
    required this.caption,
    required this.musicTag,
    required this.likes,
    required this.comments,
    required this.shares,
    this.isLiked = false,
  });

  VideoPostEntity copyWith({bool? isLiked, int? likes}) => VideoPostEntity(
    id: id,
    user: user,
    videoUrl: videoUrl,
    thumbnailUrl: thumbnailUrl,
    caption: caption,
    musicTag: musicTag,
    likes: likes ?? this.likes,
    comments: comments,
    shares: shares,
    isLiked: isLiked ?? this.isLiked,
  );

  @override
  List<Object?> get props =>
      [id, user, videoUrl, thumbnailUrl, caption, musicTag, likes, comments, shares, isLiked];
}

// ─── Post Entity ──────────────────────────────────────────────────────────────

class PostEntity extends Equatable {
  final String id;
  final UserEntity user;
  final String content;
  final List<String> imageUrls;
  final int likes;
  final int comments;
  final int shares;
  final String timeAgo;
  final bool isLiked;

  const PostEntity({
    required this.id,
    required this.user,
    required this.content,
    required this.imageUrls,
    required this.likes,
    required this.comments,
    required this.shares,
    required this.timeAgo,
    this.isLiked = false,
  });

  PostEntity copyWith({bool? isLiked, int? likes}) => PostEntity(
    id: id,
    user: user,
    content: content,
    imageUrls: imageUrls,
    likes: likes ?? this.likes,
    comments: comments,
    shares: shares,
    timeAgo: timeAgo,
    isLiked: isLiked ?? this.isLiked,
  );

  @override
  List<Object?> get props =>
      [id, user, content, imageUrls, likes, comments, shares, timeAgo, isLiked];
}

// ─── Feed Item (discriminated union) ─────────────────────────────────────────

class FeedItemEntity extends Equatable {
  final FeedItemType type;
  final VideoPostEntity? videoPost;
  final PostEntity? post;

  const FeedItemEntity.video(VideoPostEntity video)
      : type = FeedItemType.video,
        videoPost = video,
        post = null;

  const FeedItemEntity.post(PostEntity p)
      : type = FeedItemType.post,
        videoPost = null,
        post = p;

  String get id => type == FeedItemType.video ? videoPost!.id : post!.id;

  @override
  List<Object?> get props => [type, videoPost, post];
}