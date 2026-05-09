// features/notification/domain/entities/notification_entity.dart

import 'package:equatable/equatable.dart';

class NotificationEntity extends Equatable {
  final String id;
  final String userId;
  final String type; // follow | like | comment | order | system
  final String? title;
  final String? body;
  final Map<String, dynamic>? data; // deeplink payload (e.g. videoId)
  final bool isRead;
  final DateTime createdAt;

  const NotificationEntity({
    required this.id,
    required this.userId,
    required this.type,
    this.title,
    this.body,
    this.data,
    this.isRead = false,
    required this.createdAt,
  });

  NotificationEntity copyWith({bool? isRead}) => NotificationEntity(
    id: id,
    userId: userId,
    type: type,
    title: title,
    body: body,
    data: data,
    isRead: isRead ?? this.isRead,
    createdAt: createdAt,
  );

  @override
  List<Object?> get props => [id, userId, type, isRead, createdAt];
}