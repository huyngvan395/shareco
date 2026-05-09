// features/comment/data/datasources/comment_remote_datasource.dart

import '../../../../core/constants/env.dart';
import '../../../../core/errors/exception.dart';
import '../../../../core/services/supabase/index.dart';
import '../../../../shared/domain/entities/base_entity.dart';
import '../models/comment_model.dart';

abstract class CommentRemoteDataSource {
  Future<PaginatedResult<CommentModel>> getComments(
      {required String videoId, int page = 0});
  Future<PaginatedResult<CommentModel>> getReplies(
      {required String parentId, int page = 0});
  Future<CommentModel> postComment(
      {required String videoId,
        required String content,
        String? parentId});
  Future<void> deleteComment(String commentId);
  Future<bool> toggleCommentLike(String commentId);
}

class CommentRemoteDataSourceImpl implements CommentRemoteDataSource {
  static const _table   = 'video_comments';
  static const _limit   = Env.commentPageSize;
  static const _select  = '''
    *,
    profiles:user_id (
      id, username, display_name, avatar_url, is_verified
    )
  ''';

  @override
  Future<PaginatedResult<CommentModel>> getComments(
      {required String videoId, int page = 0}) async {
    try {
      final (from, to) = SupabaseService.pageRange(page, _limit);
      final rows = await SupabaseService.from(_table)
          .select(_select)
          .eq('video_id', videoId)
          .isFilter('parent_id', null) // top-level comments only
          .eq('status', 'visible')
          .order('created_at', ascending: false)
          .range(from, to) as List;

      final models = [
        for (final r in rows)
          CommentModel.fromJson(r as Map<String, dynamic>)
      ];
      return PaginatedResult(
          items: models, page: page, limit: _limit, hasMore: rows.length == _limit);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<PaginatedResult<CommentModel>> getReplies(
      {required String parentId, int page = 0}) async {
    try {
      final (from, to) = SupabaseService.pageRange(page, _limit);
      final rows = await SupabaseService.from(_table)
          .select(_select)
          .eq('parent_id', parentId)
          .eq('status', 'visible')
          .order('created_at')
          .range(from, to) as List;

      final models = [
        for (final r in rows)
          CommentModel.fromJson(r as Map<String, dynamic>)
      ];
      return PaginatedResult(
          items: models, page: page, limit: _limit, hasMore: rows.length == _limit);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<CommentModel> postComment({
    required String videoId,
    required String content,
    String? parentId,
  }) async {
    try {
      final uid = SupabaseService.currentUserId;
      if (uid == null) throw const AuthException('Unauthenticated');
      final row = await SupabaseService.from(_table)
          .insert({
        'video_id': videoId,
        'user_id': uid,
        'content': content,
        if (parentId != null) 'parent_id': parentId,
      })
          .select(_select)
          .single();
      return CommentModel.fromJson(row);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<void> deleteComment(String commentId) async {
    try {
      await SupabaseService.from(_table)
          .update({'status': 'deleted'}).eq('id', commentId);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<bool> toggleCommentLike(String commentId) async {
    // Supabase không có RPC riêng — dùng comment_likes table nếu có
    // Tạm thời trả về true (cần thêm bảng comment_likes)
    return true;
  }
}