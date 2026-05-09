// features/notification/domain/repositories/notification_repository.dart

import 'package:dartz/dartz.dart';
import '../../../../core/errors/failure.dart';
import '../../../../shared/domain/entities/base_entity.dart';
import '../entities/notification_entity.dart';

abstract class NotificationRepository {
  Future<Either<Failure, PaginatedResult<NotificationEntity>>> getNotifications({int page = 0});
  Future<Either<Failure, void>> markAsRead(String notificationId);
  Future<Either<Failure, void>> markAllAsRead();
  Future<Either<Failure, int>> getUnreadCount();
}