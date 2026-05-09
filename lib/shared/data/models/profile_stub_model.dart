// shared/data/models/profile_stub_model.dart
// DTO dùng để parse profile từ Supabase join queries

import '../../domain/entities/base_entity.dart';

class ProfileStubModel extends ProfileStub {
  const ProfileStubModel({
    required super.id,
    required super.username,
    required super.displayName,
    super.avatarUrl,
    super.isVerified,
    super.followerCount,
    super.followingCount,
    super.likeReceivedCount,
  });

  factory ProfileStubModel.fromJson(Map<String, dynamic> json) =>
      ProfileStubModel(
        id: json['id'] as String,
        username: json['username'] as String,
        displayName: (json['display_name'] as String?) ?? '',
        avatarUrl: json['avatar_url'] as String?,
        isVerified: (json['is_verified'] as bool?) ?? false,
        followerCount: (json['follower_count'] as num?)?.toInt() ?? 0,
        followingCount: (json['following_count'] as num?)?.toInt() ?? 0,
        likeReceivedCount:
        (json['like_received_count'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'username': username,
    'display_name': displayName,
    'avatar_url': avatarUrl,
    'is_verified': isVerified,
    'follower_count': followerCount,
    'following_count': followingCount,
    'like_received_count': likeReceivedCount,
  };
}