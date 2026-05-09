// features/feed/domain/repositories/feed_repository.dart

import 'package:dartz/dartz.dart';
import 'package:shareco/features/feed/domain/entities/feed_entity.dart';
import '../../../../core/errors/failure.dart';

abstract class FeedRepository {
  /// Fetch a paginated feed page.
  Future<Either<Failure, List<FeedItemEntity>>> getFeed({
    int page = 0,
    int limit = 10,
  });

  /// Toggle like on a video post.
  Future<Either<Failure, VideoPostEntity>> toggleVideoLike(String videoId);

  /// Toggle like on a regular post.
  Future<Either<Failure, PostEntity>> togglePostLike(String postId);
}