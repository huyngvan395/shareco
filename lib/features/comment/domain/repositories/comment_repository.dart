// features/comment/domain/repositories/comment_repository.dart

import 'package:dartz/dartz.dart';
import '../../../../core/errors/failure.dart';
import '../../../../shared/domain/entities/base_entity.dart';
import '../entities/comment_entity.dart';

abstract class CommentRepository {
  Future<Either<Failure, PaginatedResult<CommentEntity>>> getComments({
    required String videoId,
    int page = 0,
  });

  Future<Either<Failure, PaginatedResult<CommentEntity>>> getReplies({
    required String parentId,
    int page = 0,
  });

  Future<Either<Failure, CommentEntity>> postComment({
    required String videoId,
    required String content,
    String? parentId,
  });

  Future<Either<Failure, void>> deleteComment(String commentId);

  Future<Either<Failure, bool>> toggleCommentLike(String commentId);
}