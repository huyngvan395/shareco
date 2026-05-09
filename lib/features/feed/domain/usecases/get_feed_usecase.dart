// features/feed/domain/usecases/get_feed_usecase.dart

import 'package:dartz/dartz.dart';
import 'package:shareco/features/feed/domain/entities/feed_entity.dart';
import '../../../../core/errors/failure.dart';
import '../repositories/feed_repository.dart';

class GetFeedUseCase {
  final FeedRepository repository;
  const GetFeedUseCase(this.repository);

  Future<Either<Failure, List<FeedItemEntity>>> call({
    int page = 0,
    int limit = 10,
  }) =>
      repository.getFeed(page: page, limit: limit);
}