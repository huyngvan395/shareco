import 'package:equatable/equatable.dart';
import 'package:shareco/features/profile/domain/entities/profile_entity.dart';
import 'package:shareco/features/video/domain/entities/video_entity.dart';

abstract class ProfileState extends Equatable {
  const ProfileState();
  @override List<Object?> get props => [];
}

class ProfileInitial extends ProfileState { const ProfileInitial(); }
class ProfileLoading extends ProfileState { const ProfileLoading(); }

class ProfileLoaded extends ProfileState {
  final ProfileEntity profile;
  final List<VideoEntity> videos;
  final bool isLoadingMoreVideos;
  final bool hasReachedMax;
  final int videoPage;
  final bool isUploadingAvatar;

  const ProfileLoaded({
    required this.profile,
    this.videos = const [],
    this.isLoadingMoreVideos = false,
    this.hasReachedMax = false,
    this.videoPage = 0,
    this.isUploadingAvatar = false,
  });

  ProfileLoaded copyWith({
    ProfileEntity? profile,
    List<VideoEntity>? videos,
    bool? isLoadingMoreVideos,
    bool? hasReachedMax,
    int? videoPage,
    bool? isUploadingAvatar,
  }) => ProfileLoaded(
    profile: profile ?? this.profile,
    videos: videos ?? this.videos,
    isLoadingMoreVideos: isLoadingMoreVideos ?? this.isLoadingMoreVideos,
    hasReachedMax: hasReachedMax ?? this.hasReachedMax,
    videoPage: videoPage ?? this.videoPage,
    isUploadingAvatar: isUploadingAvatar ?? this.isUploadingAvatar,
  );

  @override
  List<Object?> get props => [profile, videos, isLoadingMoreVideos, hasReachedMax];
}


class ProfileError extends ProfileState {
  final String message;
  const ProfileError(this.message);
  @override List<Object?> get props => [message];
}