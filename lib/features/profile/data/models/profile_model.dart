// features/profile/data/models/profile_model.dart

import '../../domain/entities/profile_entity.dart';

class ProfileModel extends ProfileEntity {
  const ProfileModel({
    required super.id,
    required super.username,
    super.displayName,
    super.bio,
    super.avatarUrl,
    super.gender,
    super.dob,
    super.countryCode,
    super.languageCode,
    super.isVerified,
    super.followerCount,
    super.followingCount,
    super.likeReceivedCount,
    required super.createdAt,
    required super.updatedAt,
    super.isFollowing,
    super.isCurrentUser,
  });

  factory ProfileModel.fromJson(Map<String, dynamic> json,
      {bool isFollowing = false, bool isCurrentUser = false}) =>
      ProfileModel(
        id: json['id'] as String,
        username: json['username'] as String,
        displayName: json['display_name'] as String?,
        bio: json['bio'] as String?,
        avatarUrl: json['avatar_url'] as String?,
        gender: json['gender'] as String?,
        dob: json['dob'] != null ? DateTime.parse(json['dob'] as String) : null,
        countryCode: json['country_code'] as String?,
        languageCode: (json['language_code'] as String?) ?? 'vi',
        isVerified: (json['is_verified'] as bool?) ?? false,
        followerCount: (json['follower_count'] as num?)?.toInt() ?? 0,
        followingCount: (json['following_count'] as num?)?.toInt() ?? 0,
        likeReceivedCount:
        (json['like_received_count'] as num?)?.toInt() ?? 0,
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
        isFollowing: isFollowing,
        isCurrentUser: isCurrentUser,
      );

  Map<String, dynamic> toUpdateJson({
    String? displayName,
    String? bio,
    String? avatarUrl,
    String? gender,
    DateTime? dob,
    String? countryCode,
    String? languageCode,
  }) {
    final map = <String, dynamic>{};
    if (displayName != null) map['display_name'] = displayName;
    if (bio != null) map['bio'] = bio;
    if (avatarUrl != null) map['avatar_url'] = avatarUrl;
    if (gender != null) map['gender'] = gender;
    if (dob != null) map['dob'] = dob.toIso8601String().split('T').first;
    if (countryCode != null) map['country_code'] = countryCode;
    if (languageCode != null) map['language_code'] = languageCode;
    return map;
  }
}