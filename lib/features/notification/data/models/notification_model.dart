// features/notification/data/models/notification_model.dart

import '../../domain/entities/notification_entity.dart';

class NotificationModel extends NotificationEntity {
  const NotificationModel({
    required super.id,
    required super.userId,
    required super.type,
    super.title,
    super.body,
    super.data,
    super.isRead,
    required super.createdAt,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) =>
      NotificationModel(
        id: json['id'] as String,
        userId: json['user_id'] as String,
        type: json['type'] as String,
        title: json['title'] as String?,
        body: json['body'] as String?,
        data: json['data'] as Map<String, dynamic>?,
        isRead: (json['is_read'] as bool?) ?? false,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}