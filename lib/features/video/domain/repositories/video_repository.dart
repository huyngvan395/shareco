// features/video/domain/repositories/video_repository.dart

import 'package:dartz/dartz.dart';
import '../../../../core/errors/failure.dart';
import '../../../../shared/domain/entities/base_entity.dart';
import '../entities/video_entity.dart';

abstract class VideoRepository {
  /// Feed "For You" — paginated
  Future<Either<Failure, PaginatedResult<VideoEntity>>> getForYouFeed({
    int page = 0,
  });

  /// Feed "Following" — dùng RPC get_following_feed
  Future<Either<Failure, PaginatedResult<VideoEntity>>> getFollowingFeed({
    int page = 0,
  });

  /// Videos của một user cụ thể
  Future<Either<Failure, PaginatedResult<VideoEntity>>> getUserVideos({
    required String userId,
    int page = 0,
  });

  /// Lấy video đơn theo ID
  Future<Either<Failure, VideoEntity>> getVideoById(String videoId);

  /// Toggle like — dùng RPC toggle_video_like
  Future<Either<Failure, bool>> toggleLike(String videoId);

  /// Tăng view count
  Future<Either<Failure, void>> incrementView(String videoId);

  /// Upload video lên Cloudinary rồi lưu metadata vào Supabase
  Future<Either<Failure, VideoEntity>> createVideo({
    required String videoPath,       // local file path
    required String thumbnailPath,   // local file path
    String? caption,
    String visibility = 'public',
    void Function(double progress)? onProgress, // 0.0 → 1.0
    // durationMs / width / height bỏ — datasource tự lấy từ Cloudinary response
  });

  /// Cập nhật caption / visibility
  Future<Either<Failure, VideoEntity>> updateVideo({
    required String videoId,
    String? caption,
    String? visibility,
    bool? allowComment,
  });

  /// Xóa video
  Future<Either<Failure, void>> deleteVideo(String videoId);

  Future<List<VideoEntity>> searchVideos(String query);
}