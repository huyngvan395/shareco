// features/video/domain/usecases/video_usecases.dart

import 'package:dartz/dartz.dart';
import '../../../../core/errors/failure.dart';
import '../../../../shared/domain/entities/base_entity.dart';
import '../entities/video_entity.dart';
import '../repositories/video_repository.dart';

class GetForYouFeedUseCase {
  final VideoRepository repo;
  const GetForYouFeedUseCase(this.repo);
  Future<Either<Failure, PaginatedResult<VideoEntity>>> call({int page = 0}) =>
      repo.getForYouFeed(page: page);
}

class GetFollowingFeedUseCase {
  final VideoRepository repo;
  const GetFollowingFeedUseCase(this.repo);
  Future<Either<Failure, PaginatedResult<VideoEntity>>> call({int page = 0}) =>
      repo.getFollowingFeed(page: page);
}

class GetUserVideosUseCase {
  final VideoRepository repo;
  const GetUserVideosUseCase(this.repo);
  Future<Either<Failure, PaginatedResult<VideoEntity>>> call({
    required String userId,
    int page = 0,
  }) =>
      repo.getUserVideos(userId: userId, page: page);
}

class GetVideoByIdUseCase {
  final VideoRepository repo;
  const GetVideoByIdUseCase(this.repo);
  Future<Either<Failure, VideoEntity>> call(String videoId) =>
      repo.getVideoById(videoId);
}

class ToggleVideoLikeUseCase {
  final VideoRepository repo;
  const ToggleVideoLikeUseCase(this.repo);
  Future<Either<Failure, bool>> call(String videoId) =>
      repo.toggleLike(videoId);
}

class IncrementVideoViewUseCase {
  final VideoRepository repo;
  const IncrementVideoViewUseCase(this.repo);
  Future<Either<Failure, void>> call(String videoId) =>
      repo.incrementView(videoId);
}

class CreateVideoUseCase {
  final VideoRepository repo;
  const CreateVideoUseCase(this.repo);

  Future<Either<Failure, VideoEntity>> call({
    required String videoPath,
    required String thumbnailPath,
    String? caption,
    String visibility = 'public',
    void Function(double progress)? onProgress, // 👈 thêm, bỏ durationMs/width/height
  }) =>
      repo.createVideo(
        videoPath: videoPath,
        thumbnailPath: thumbnailPath,
        caption: caption,
        visibility: visibility,
        onProgress: onProgress,
      );
}

class DeleteVideoUseCase {
  final VideoRepository repo;
  const DeleteVideoUseCase(this.repo);
  Future<Either<Failure, void>> call(String videoId) =>
      repo.deleteVideo(videoId);
}