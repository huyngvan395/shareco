// features/notification/data/repositories/notification_repository_impl.dart

import 'package:dartz/dartz.dart';
import '../../../../core/errors/exception.dart';
import '../../../../core/errors/failure.dart';
import '../../../../shared/domain/entities/base_entity.dart';
import '../../domain/entities/notification_entity.dart';
import '../../domain/repositories/notification_repository.dart';
import '../datasources/notification_remote_datasource.dart';

class NotificationRepositoryImpl implements NotificationRepository {
  final NotificationRemoteDataSource remote;
  const NotificationRepositoryImpl({required this.remote});

  Either<Failure, T> _handle<T>(dynamic e) {
    if (e is AuthException) return Left(AuthFailure(e.message));
    if (e is ServerException) return Left(ServerFailure(e.message));
    return Left(UnknownFailure(e.toString()));
  }

  @override
  Future<Either<Failure, PaginatedResult<NotificationEntity>>>
  getNotifications({int page = 0}) async {
    try {
      return Right(await remote.getNotifications(page: page));
    } catch (e) {
      return _handle(e);
    }
  }

  @override
  Future<Either<Failure, void>> markAsRead(String notificationId) async {
    try {
      await remote.markAsRead(notificationId);
      return const Right(null);
    } catch (e) {
      return _handle(e);
    }
  }

  @override
  Future<Either<Failure, void>> markAllAsRead() async {
    try {
      await remote.markAllAsRead();
      return const Right(null);
    } catch (e) {
      return _handle(e);
    }
  }

  @override
  Future<Either<Failure, int>> getUnreadCount() async {
    try {
      return Right(await remote.getUnreadCount());
    } catch (e) {
      return _handle(e);
    }
  }
}