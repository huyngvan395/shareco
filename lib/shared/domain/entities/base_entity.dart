// shared/domain/entities/base_entity.dart
// Base classes & common entities dùng chung toàn app

import 'package:equatable/equatable.dart';

abstract class BaseEntity extends Equatable {
  final String id;
  final DateTime createdAt;
  final DateTime updatedAt;

  const BaseEntity({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
  });

  @override
  List<Object?> get props => [id, createdAt, updatedAt];
}

// Pagination metadata
class PaginatedResult<T> {
  final List<T> items;
  final int page;
  final int limit;
  final bool hasMore;

  const PaginatedResult({
    required this.items,
    required this.page,
    required this.limit,
    required this.hasMore,
  });

  bool get isEmpty => items.isEmpty;
}

// Profile stub — shared across features
class ProfileStub extends Equatable {
  final String id;
  final String username;
  final String displayName;
  final String? avatarUrl;
  final bool isVerified;
  final int followerCount;
  final int followingCount;
  final int likeReceivedCount;

  const ProfileStub({
    required this.id,
    required this.username,
    required this.displayName,
    this.avatarUrl,
    this.isVerified = false,
    this.followerCount = 0,
    this.followingCount = 0,
    this.likeReceivedCount = 0,
  });

  @override
  List<Object?> get props => [id, username, displayName, avatarUrl, isVerified];
}