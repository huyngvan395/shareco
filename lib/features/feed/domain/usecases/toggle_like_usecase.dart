// features/feed/domain/usecases/toggle_like_usecase.dart

import 'package:dartz/dartz.dart';
import 'package:shareco/features/feed/domain/entities/feed_entity.dart';
import '../../../../core/errors/failure.dart';
import '../repositories/feed_repository.dart';

class ToggleVideoLikeUseCase {
  final FeedRepository repository;
  const ToggleVideoLikeUseCase(this.repository);

  Future<Either<Failure, VideoPostEntity>> call(String videoId) =>
      repository.toggleVideoLike(videoId);
}

class TogglePostLikeUseCase {
  final FeedRepository repository;
  const TogglePostLikeUseCase(this.repository);

  Future<Either<Failure, PostEntity>> call(String postId) =>
      repository.togglePostLike(postId);
}