// features/comment/data/datasources/comment_remote_datasource.dart

import '../../../../core/constants/env.dart';
import '../../../../core/errors/exception.dart';
import '../../../../core/services/supabase/index.dart';
import '../../../../shared/domain/entities/base_entity.dart';
import '../models/comment_model.dart';

abstract class CommentRemoteDataSource {
  Future<PaginatedResult<CommentModel>> getComments({
    required String videoId,
    int page = 0,
  });
  Future<PaginatedResult<CommentModel>> getReplies({
    required String parentId,
    int page = 0,
  });
  Future<CommentModel> postComment({
    required String videoId,
    required String content,
    String? parentId,
  });
  Future<void> deleteComment(String commentId);
  Future<bool> toggleCommentLike(String commentId);
}

class CommentRemoteDataSourceImpl implements CommentRemoteDataSource {
  static const _table = 'video_comments';
  static const _limit = Env.commentPageSize;
  static const int replyPageSize = 3; // Cơ chế load từng cụm 3 câu trả lời kiểu TikTok
  static const _select = '''
    *,
    profiles:user_id (
      id, username, display_name, avatar_url, is_verified
    )
  ''';

  /// Tìm bình luận gốc cấp 1 (rootId) của bất kỳ câu trả lời lồng nhau nào.
  String? _resolveRootId(
    String commentId,
    Map<String, CommentModel> allById,
  ) {
    final visited = <String>{};
    var curr = allById[commentId];
    while (curr != null && curr.parentId != null) {
      if (!visited.add(curr.id)) return null;
      final parent = allById[curr.parentId!];
      if (parent == null) {
        // Nếu parent là bình luận gốc nằm ở trang khác hoặc đã ẩn
        return curr.parentId;
      }
      if (parent.parentId == null) {
        return parent.id;
      }
      curr = parent;
    }
    return curr?.id;
  }

  Future<Set<String>> _getLikedCommentIds(List<String> commentIds) async {
    final uid = SupabaseService.currentUserId;
    if (uid == null || commentIds.isEmpty) return const {};
    try {
      final rows = await SupabaseService.from('video_comment_likes')
          .select('comment_id')
          .eq('user_id', uid)
          .inFilter('comment_id', commentIds) as List;
      return {
        for (final r in rows)
          (r as Map<String, dynamic>)['comment_id'] as String,
      };
    } catch (_) {
      return const {};
    }
  }

  @override
  Future<PaginatedResult<CommentModel>> getComments({
    required String videoId,
    int page = 0,
  }) async {
    try {
      final (from, to) = SupabaseService.pageRange(page, _limit);
      final rootRows = await SupabaseService.from(_table)
          .select(_select)
          .eq('video_id', videoId)
          .isFilter('parent_id', null)
          .eq('status', 'visible')
          .order('created_at', ascending: false)
          .range(from, to) as List;

      final rootModels = [
        for (final r in rootRows)
          CommentModel.fromJson(r as Map<String, dynamic>),
      ];

      if (rootModels.isEmpty) {
        return PaginatedResult(
          items: const [],
          page: page,
          limit: _limit,
          hasMore: false,
        );
      }

      // Lấy danh sách các câu trả lời hiển thị của video để tính chính xác tổng số reply
      // trong từng luồng (bao gồm cả reply lồng nhiều cấp kiểu TikTok).
      final replyRows = await SupabaseService.from(_table)
          .select(_select)
          .eq('video_id', videoId)
          .not('parent_id', 'is', null)
          .eq('status', 'visible')
          .order('created_at', ascending: true) as List;

      final allById = <String, CommentModel>{
        for (final root in rootModels) root.id: root,
      };
      final rawReplies = <CommentModel>[];
      for (final r in replyRows) {
        final model = CommentModel.fromJson(r as Map<String, dynamic>);
        allById[model.id] = model;
        rawReplies.add(model);
      }

      final replyCountByRoot = <String, int>{};
      for (final reply in rawReplies) {
        final rootId = _resolveRootId(reply.id, allById);
        if (rootId != null) {
          replyCountByRoot[rootId] = (replyCountByRoot[rootId] ?? 0) + 1;
        }
      }

      final likedIds = await _getLikedCommentIds([
        for (final root in rootModels) root.id,
      ]);

      final enrichedRoots = rootModels.map((root) {
        final exactCount = replyCountByRoot[root.id] ?? 0;
        return CommentModel(
          id: root.id,
          videoId: root.videoId,
          userId: root.userId,
          user: root.user,
          parentId: null,
          content: root.content,
          likeCount: root.likeCount,
          replyCount: exactCount,
          status: root.status,
          createdAt: root.createdAt,
          updatedAt: root.updatedAt,
          isLiked: likedIds.contains(root.id) || root.isLiked,
          hasMoreReplies: exactCount > 0,
        );
      }).toList();

      return PaginatedResult(
        items: enrichedRoots,
        page: page,
        limit: _limit,
        hasMore: rootRows.length == _limit,
      );
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<PaginatedResult<CommentModel>> getReplies({
    required String parentId,
    int page = 0,
  }) async {
    try {
      // Lấy thông tin bình luận gốc để biết video_id & thông tin tác giả gốc
      final rootRow = await SupabaseService.from(_table)
          .select(_select)
          .eq('id', parentId)
          .maybeSingle();

      if (rootRow == null) {
        return PaginatedResult(
          items: const [],
          page: page,
          limit: replyPageSize,
          hasMore: false,
        );
      }

      final rootModel = CommentModel.fromJson(rootRow);
      final replyRows = await SupabaseService.from(_table)
          .select(_select)
          .eq('video_id', rootModel.videoId)
          .not('parent_id', 'is', null)
          .eq('status', 'visible')
          .order('created_at', ascending: true) as List;

      final allById = <String, CommentModel>{rootModel.id: rootModel};
      final allReplies = <CommentModel>[];
      for (final r in replyRows) {
        final model = CommentModel.fromJson(r as Map<String, dynamic>);
        allById[model.id] = model;
        allReplies.add(model);
      }

      // Gom toàn bộ câu trả lời (cả trực tiếp lẫn trả lời chéo nhau) thuộc về root thread này
      final threadReplies = <CommentModel>[];
      for (final reply in allReplies) {
        final resolvedRoot = _resolveRootId(reply.id, allById);
        if (resolvedRoot == parentId) {
          final targetParent =
              reply.parentId != null ? allById[reply.parentId!] : rootModel;
          threadReplies.add(
            CommentModel(
              id: reply.id,
              videoId: reply.videoId,
              userId: reply.userId,
              user: reply.user,
              parentId: reply.parentId,
              rootId: parentId,
              replyToUsername: targetParent?.user.username,
              replyToDisplayName: targetParent?.user.displayName,
              replyToContent: targetParent?.content,
              content: reply.content,
              likeCount: reply.likeCount,
              replyCount: reply.replyCount,
              status: reply.status,
              createdAt: reply.createdAt,
              updatedAt: reply.updatedAt,
              isLiked: reply.isLiked,
            ),
          );
        }
      }

      threadReplies.sort((a, b) => a.createdAt.compareTo(b.createdAt));

      final start = page * replyPageSize;
      if (start >= threadReplies.length) {
        return PaginatedResult(
          items: const [],
          page: page,
          limit: replyPageSize,
          hasMore: false,
        );
      }
      final end = (start + replyPageSize) > threadReplies.length
          ? threadReplies.length
          : (start + replyPageSize);
      final slice = threadReplies.sublist(start, end);
      final likedIds = await _getLikedCommentIds([
        for (final s in slice) s.id,
      ]);
      final enrichedSlice = [
        for (final s in slice)
          likedIds.contains(s.id)
              ? CommentModel(
                  id: s.id,
                  videoId: s.videoId,
                  userId: s.userId,
                  user: s.user,
                  parentId: s.parentId,
                  rootId: s.rootId,
                  replyToUsername: s.replyToUsername,
                  replyToDisplayName: s.replyToDisplayName,
                  replyToContent: s.replyToContent,
                  content: s.content,
                  likeCount: s.likeCount,
                  replyCount: s.replyCount,
                  status: s.status,
                  createdAt: s.createdAt,
                  updatedAt: s.updatedAt,
                  isLiked: true,
                )
              : s,
      ];

      return PaginatedResult(
        items: enrichedSlice,
        page: page,
        limit: replyPageSize,
        hasMore: end < threadReplies.length,
      );
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

      String? rootId;
      String? replyToUsername;
      String? replyToDisplayName;
      String? replyToContent;

      if (parentId != null) {
        try {
          final parentRow = await SupabaseService.from(_table)
              .select(_select)
              .eq('id', parentId)
              .maybeSingle();
          if (parentRow != null) {
            final parentModel = CommentModel.fromJson(parentRow);
            replyToUsername = parentModel.user.username;
            replyToDisplayName = parentModel.user.displayName;
            replyToContent = parentModel.content;

            // Dò ngược lên bình luận cấp 1 (rootId) nếu người dùng đang trả lời một reply con
            var cursor = parentModel;
            var guard = 0;
            while (cursor.parentId != null && guard < 10) {
              guard++;
              final upperRow = await SupabaseService.from(_table)
                  .select(_select)
                  .eq('id', cursor.parentId!)
                  .maybeSingle();
              if (upperRow == null) break;
              cursor = CommentModel.fromJson(upperRow);
            }
            rootId = cursor.id;
          }
        } catch (_) {
          rootId = parentId;
        }
      }

      final row = await SupabaseService.from(_table)
          .insert({
            'video_id': videoId,
            'user_id': uid,
            'content': content,
            'parent_id': ?parentId,
          })
          .select(_select)
          .single();

      return CommentModel.fromJson(
        row,
        rootId: rootId ?? parentId,
        replyToUsername: replyToUsername,
        replyToDisplayName: replyToDisplayName,
        replyToContent: replyToContent,
      );
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<void> deleteComment(String commentId) async {
    try {
      final uid = SupabaseService.currentUserId;
      if (uid != null) {
        await SupabaseService.from(_table)
            .delete()
            .eq('id', commentId)
            .eq('user_id', uid);
      } else {
        await SupabaseService.from(_table)
            .update({'status': 'deleted'})
            .eq('id', commentId);
      }
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<bool> toggleCommentLike(String commentId) async {
    final uid = SupabaseService.currentUserId;
    if (uid == null) throw const AuthException('Unauthenticated');

    try {
      final res = await SupabaseService.rpc(
        'toggle_comment_like',
        params: {'p_comment_id': commentId},
      );
      return res as bool;
    } catch (_) {
      // Fallback trực tiếp vào bảng video_comment_likes nếu RPC chưa được chạy
      try {
        final existing = await SupabaseService.from('video_comment_likes')
            .select('comment_id')
            .eq('comment_id', commentId)
            .eq('user_id', uid)
            .maybeSingle();
        if (existing != null) {
          await SupabaseService.from('video_comment_likes')
              .delete()
              .eq('comment_id', commentId)
              .eq('user_id', uid);
          return false;
        } else {
          await SupabaseService.from('video_comment_likes').insert({
            'comment_id': commentId,
            'user_id': uid,
          });
          return true;
        }
      } catch (_) {
        return true;
      }
    }
  }
}
