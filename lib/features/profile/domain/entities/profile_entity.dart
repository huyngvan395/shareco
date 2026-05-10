// features/profile/domain/entities/profile_entity.dart

import 'package:equatable/equatable.dart';

class ProfileEntity extends Equatable {
  final String id;
  final String username;
  final String? displayName;
  final String? bio;
  final String? avatarUrl;
  final String? gender;
  final DateTime? dob;
  final String? countryCode;
  final String languageCode;
  final bool isVerified;
  final int followerCount;
  final int followingCount;
  final int likeReceivedCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Client-side computed
  final bool isFollowing;
  final bool isCurrentUser;

  const ProfileEntity({
    required this.id,
    required this.username,
    this.displayName,
    this.bio,
    this.avatarUrl,
    this.gender,
    this.dob,
    this.countryCode,
    this.languageCode = 'vi',
    this.isVerified = false,
    this.followerCount = 0,
    this.followingCount = 0,
    this.likeReceivedCount = 0,
    required this.createdAt,
    required this.updatedAt,
    this.isFollowing = false,
    this.isCurrentUser = false,
  });

  ProfileEntity copyWith({
    bool? isFollowing,
    int? followerCount,
    String? displayName,
    String? bio,
    String? avatarUrl,
  }) =>
      ProfileEntity(
        id: id,
        username: username,
        displayName: displayName ?? this.displayName,
        bio: bio ?? this.bio,
        avatarUrl: avatarUrl ?? this.avatarUrl,
        gender: gender,
        dob: dob,
        countryCode: countryCode,
        languageCode: languageCode,
        isVerified: isVerified,
        followerCount: followerCount ?? this.followerCount,
        followingCount: followingCount,
        likeReceivedCount: likeReceivedCount,
        createdAt: createdAt,
        updatedAt: updatedAt,
        isFollowing: isFollowing ?? this.isFollowing,
        isCurrentUser: isCurrentUser,
      );

  @override
  List<Object?> get props =>
      [id, username, followerCount, followingCount, isFollowing, isCurrentUser, bio, avatarUrl, displayName];
}