// features/comment/data/repositories/comment_repository_impl.dart

import 'package:dartz/dartz.dart';
import '../../../../core/errors/exception.dart';
import '../../../../core/errors/failure.dart';
import '../../../../shared/domain/entities/base_entity.dart';
import '../../domain/entities/comment_entity.dart';
import '../../domain/repositories/comment_repository.dart';
import '../datasources/comment_remote_datasource.dart';

class CommentRepositoryImpl implements CommentRepository {
  final CommentRemoteDataSource remote;
  const CommentRepositoryImpl({required this.remote});

  Either<Failure, T> _handle<T>(dynamic e) {
    if (e is AuthException) return Left(AuthFailure(e.message));
    if (e is ServerException) return Left(ServerFailure(e.message));
    return Left(UnknownFailure(e.toString()));
  }

  @override
  Future<Either<Failure, PaginatedResult<CommentEntity>>> getComments(
      {required String videoId, int page = 0}) async {
    try {
      return Right(await remote.getComments(videoId: videoId, page: page));
    } catch (e) {
      return _handle(e);
    }
  }

  @override
  Future<Either<Failure, PaginatedResult<CommentEntity>>> getReplies(
      {required String parentId, int page = 0}) async {
    try {
      return Right(await remote.getReplies(parentId: parentId, page: page));
    } catch (e) {
      return _handle(e);
    }
  }

  @override
  Future<Either<Failure, CommentEntity>> postComment({
    required String videoId,
    required String content,
    String? parentId,
  }) async {
    try {
      return Right(await remote.postComment(
          videoId: videoId, content: content, parentId: parentId));
    } catch (e) {
      return _handle(e);
    }
  }

  @override
  Future<Either<Failure, void>> deleteComment(String commentId) async {
    try {
      await remote.deleteComment(commentId);
      return const Right(null);
    } catch (e) {
      return _handle(e);
    }
  }

  @override
  Future<Either<Failure, bool>> toggleCommentLike(String commentId) async {
    try {
      return Right(await remote.toggleCommentLike(commentId));
    } catch (e) {
      return _handle(e);
    }
  }
}