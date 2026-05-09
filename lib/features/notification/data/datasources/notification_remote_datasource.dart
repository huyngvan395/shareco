// features/notification/data/datasources/notification_remote_datasource.dart

import 'package:supabase_flutter/supabase_flutter.dart' hide AuthException;

import '../../../../core/constants/env.dart';
import '../../../../core/errors/exception.dart';
import '../../../../core/services/supabase/index.dart';
import '../../../../shared/domain/entities/base_entity.dart';
import '../models/notification_model.dart';

abstract class NotificationRemoteDataSource {
  Future<PaginatedResult<NotificationModel>> getNotifications({int page = 0});
  Future<void> markAsRead(String id);
  Future<void> markAllAsRead();
  Future<int> getUnreadCount();
}

class NotificationRemoteDataSourceImpl
    implements NotificationRemoteDataSource {
  static const _table = 'notifications';
  static const _limit = Env.notifPageSize;

  @override
  Future<PaginatedResult<NotificationModel>> getNotifications(
      {int page = 0}) async {
    try {
      final uid = SupabaseService.currentUserId;
      if (uid == null) throw const AuthException();
      final (from, to) = SupabaseService.pageRange(page, _limit);
      final rows = await SupabaseService.from(_table)
          .select()
          .eq('user_id', uid)
          .order('created_at', ascending: false)
          .range(from, to) as List;
      final models = [
        for (final r in rows)
          NotificationModel.fromJson(r as Map<String, dynamic>)
      ];
      return PaginatedResult(
          items: models, page: page, limit: _limit, hasMore: rows.length == _limit);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<void> markAsRead(String id) async {
    try {
      await SupabaseService.from(_table)
          .update({'is_read': true}).eq('id', id);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<void> markAllAsRead() async {
    try {
      final uid = SupabaseService.currentUserId;
      if (uid == null) throw const AuthException();
      await SupabaseService.from(_table)
          .update({'is_read': true})
          .eq('user_id', uid)
          .eq('is_read', false);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<int> getUnreadCount() async {
    try {
      final uid = SupabaseService.currentUserId;
      if (uid == null) return 0;
      final res = await SupabaseService.from(_table)
          .count(CountOption.exact)
          .eq('user_id', uid)
          .eq('is_read', false);
      return (res as dynamic).count as int? ?? 0;
    } catch (_) {
      return 0;
    }
  }
}