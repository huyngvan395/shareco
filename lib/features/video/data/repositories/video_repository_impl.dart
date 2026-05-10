// features/video/data/repositories/video_repository_impl.dart

import 'package:dartz/dartz.dart';
import '../../../../core/errors/exception.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/services/supabase/index.dart';
import '../../../../shared/domain/entities/base_entity.dart';
import '../../domain/entities/video_entity.dart';
import '../../domain/repositories/video_repository.dart';
import '../datasources/video_remote_datasource.dart';

class VideoRepositoryImpl implements VideoRepository {
  final VideoRemoteDataSource remote;
  const VideoRepositoryImpl({required this.remote});

  Either<Failure, T> _handle<T>(dynamic e) {
    if (e is AuthException) return Left(AuthFailure(e.message));
    if (e is ServerException) return Left(ServerFailure(e.message));
    if (e is NetworkException) return Left(NetworkFailure(e.message));
    return Left(UnknownFailure(e.toString()));
  }

  @override
  Future<Either<Failure, PaginatedResult<VideoEntity>>> getForYouFeed(
      {int page = 0}) async {
    try {
      return Right(await remote.getForYouFeed(page: page));
    } catch (e) {
      return _handle(e);
    }
  }

  @override
  Future<Either<Failure, PaginatedResult<VideoEntity>>> getFollowingFeed(
      {int page = 0}) async {
    try {
      return Right(await remote.getFollowingFeed(page: page));
    } catch (e) {
      return _handle(e);
    }
  }

  @override
  Future<Either<Failure, PaginatedResult<VideoEntity>>> getUserVideos(
      {required String userId, int page = 0}) async {
    try {
      return Right(await remote.getUserVideos(userId: userId, page: page));
    } catch (e) {
      return _handle(e);
    }
  }

  @override
  Future<Either<Failure, VideoEntity>> getVideoById(String videoId) async {
    try {
      return Right(await remote.getVideoById(videoId));
    } catch (e) {
      return _handle(e);
    }
  }

  @override
  Future<Either<Failure, bool>> toggleLike(String videoId) async {
    try {
      return Right(await remote.toggleLike(videoId));
    } catch (e) {
      return _handle(e);
    }
  }

  @override
  Future<Either<Failure, void>> incrementView(String videoId) async {
    try {
      await remote.incrementView(videoId);
      return const Right(null);
    } catch (e) {
      return _handle(e);
    }
  }

  @override
  Future<Either<Failure, VideoEntity>> createVideo({
    required String videoPath,
    required String thumbnailPath,
    String? caption,
    String visibility = 'public',
    void Function(double progress)? onProgress, // 👈 thêm
    // Bỏ durationMs / width / height vì datasource không cần nữa
  }) async {
    try {
      // Auth check giữ ở đây — tầng domain không nên biết Supabase
      if (SupabaseService.currentUserId == null) {
        return const Left(AuthFailure('User not authenticated'));
      }

      final model = await remote.createVideo(
        localVideoPath: videoPath,
        localThumbnailPath: thumbnailPath,
        caption: caption ?? '',
        visibility: visibility,
        onProgress: onProgress,
      );

      return Right(model);
    } catch (e) {
      return _handle(e);
    }
  }

  @override
  Future<Either<Failure, VideoEntity>> updateVideo({
    required String videoId,
    String? caption,
    String? visibility,
    bool? allowComment,
  }) async {
    try {
      final data = <String, dynamic>{};
      if (caption != null) data['caption'] = caption;
      if (visibility != null) data['visibility'] = visibility;
      if (allowComment != null) data['allow_comment'] = allowComment;
      final model = await remote.updateVideo(videoId: videoId, data: data);
      return Right(model);
    } catch (e) {
      return _handle(e);
    }
  }

  @override
  Future<Either<Failure, void>> deleteVideo(String videoId) async {
    try {
      await remote.deleteVideo(videoId);
      return const Right(null);
    } catch (e) {
      return _handle(e);
    }
  }

  @override
  Future<List<VideoEntity>> searchVideos(String query) async {
    return await remote.searchVideos(query);
  }


}