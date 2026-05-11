import 'package:equatable/equatable.dart';

abstract class ProfileEvent extends Equatable {
  const ProfileEvent();
  @override List<Object?> get props => [];
}

class ProfileLoadRequested extends ProfileEvent {
  final String userId;
  const ProfileLoadRequested(this.userId);
  @override List<Object?> get props => [userId];
}

class ProfileFollowToggled extends ProfileEvent {
  final String targetUserId;
  const ProfileFollowToggled(this.targetUserId);
  @override List<Object?> get props => [targetUserId];
}

class ProfileVideosLoadMoreRequested extends ProfileEvent {
  const ProfileVideosLoadMoreRequested();
}

class ProfileUpdateRequested extends ProfileEvent {
  final String? displayName;
  final String? bio;
  const ProfileUpdateRequested({this.displayName, this.bio});
  @override List<Object?> get props => [displayName, bio];
}

class ProfileAvatarUpdateRequested extends ProfileEvent {
  final String filePath;
  const ProfileAvatarUpdateRequested(this.filePath);
}

class ProfileVideosRefreshRequested extends ProfileEvent {
  const ProfileVideosRefreshRequested();
}