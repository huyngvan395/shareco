import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shareco/features/profile/domain/repositories/profile_repository.dart';
import 'package:shareco/features/profile/presentation/bloc/profile_event.dart';
import 'package:shareco/features/profile/presentation/bloc/profile_state.dart';
import 'package:shareco/features/video/domain/entities/video_entity.dart';
import 'package:shareco/features/video/domain/usecases/video_usecases.dart';
import 'package:shareco/shared/domain/entities/base_entity.dart';

import '../../../../core/services/cloudinary/cloudinary_service.dart';

class ProfileBloc extends Bloc<ProfileEvent, ProfileState> {
  final ProfileRepository profileRepo;
  final GetUserVideosUseCase getUserVideos;

  ProfileBloc({required this.profileRepo, required this.getUserVideos})
      : super(const ProfileInitial()) {
    on<ProfileLoadRequested>(_onLoad);
    on<ProfileFollowToggled>(_onFollow);
    on<ProfileVideosLoadMoreRequested>(_onLoadMoreVideos);
    on<ProfileUpdateRequested>(_onUpdate);
    on<ProfileAvatarUpdateRequested>(_onUpdateAvatar);
  }

  Future<void> _onLoad(ProfileLoadRequested event, Emitter<ProfileState> emit) async {
    emit(const ProfileLoading());
    final profileResult = await profileRepo.getProfile(event.userId);
    if (profileResult.isLeft()) {
      profileResult.fold((f) => emit(ProfileError(f.message)), (_) {});
      return;
    }
    final profile = profileResult.getOrElse(() => throw Exception());

    final videosResult = await getUserVideos(userId: event.userId, page: 0);
    final videos = videosResult
        .getOrElse(() => PaginatedResult<VideoEntity>(items: const [], hasMore: false, page: 0, limit: 0))
        .items;

    emit(ProfileLoaded(profile: profile, videos: videos));
  }

  Future<void> _onFollow(ProfileFollowToggled event, Emitter<ProfileState> emit) async {
    final current = state;
    if (current is! ProfileLoaded) return;

    // Optimistic update
    final isNowFollowing = !current.profile.isFollowing;
    emit(current.copyWith(
      profile: current.profile.copyWith(
        isFollowing: isNowFollowing,
        followerCount: current.profile.followerCount + (isNowFollowing ? 1 : -1),
      ),
    ));

    final result = await profileRepo.toggleFollow(event.targetUserId);
    result.fold((_) => emit(current), (_) {});
  }

  Future<void> _onLoadMoreVideos(
      ProfileVideosLoadMoreRequested _, Emitter<ProfileState> emit) async {
    final current = state;
    if (current is! ProfileLoaded) return;
    if (current.isLoadingMoreVideos || current.hasReachedMax) return;
    emit(current.copyWith(isLoadingMoreVideos: true));
    final next = current.videoPage + 1;
    final result = await getUserVideos(userId: current.profile.id, page: next);
    result.fold(
          (_) => emit(current.copyWith(isLoadingMoreVideos: false)),
          (p) => emit(current.copyWith(
        videos: [...current.videos, ...p.items],
        isLoadingMoreVideos: false,
        hasReachedMax: !p.hasMore,
        videoPage: next,
      )),
    );
  }

  Future<void> _onUpdate(ProfileUpdateRequested event, Emitter<ProfileState> emit) async {
    final current = state;
    if (current is! ProfileLoaded) return;
    final result = await profileRepo.updateProfile(
        displayName: event.displayName, bio: event.bio);
    result.fold((_) {}, (p) => emit(current.copyWith(profile: p)));
  }

  Future<void> _onUpdateAvatar(
      ProfileAvatarUpdateRequested event,
      Emitter<ProfileState> emit,
      ) async {
    final current = state;
    if (current is! ProfileLoaded) return;

    emit(current.copyWith(isUploadingAvatar: true));

    try {
      final cloudinary = CloudinaryService();
      final avatarUrl = await cloudinary.uploadThumbnail(event.filePath);

      final result = await profileRepo.updateProfile(avatarUrl: avatarUrl);

      result.fold(
            (_) => emit(current.copyWith(isUploadingAvatar: false)), // rollback khi lỗi
            (updatedProfile) => emit(current.copyWith(
          profile: updatedProfile,
          isUploadingAvatar: false,
        )),
      );
    } catch (_) {
      emit(current.copyWith(isUploadingAvatar: false));
    }
  }
}

