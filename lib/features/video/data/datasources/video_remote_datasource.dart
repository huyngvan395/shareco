// features/video/data/datasources/video_remote_datasource.dart

import 'dart:developer' as dev;

import 'package:flutter/foundation.dart';
import 'package:shareco/core/notifier/auth_notifier.dart';
import 'package:shareco/di/injector.dart';

import '../../../../core/constants/env.dart';
import '../../../../core/errors/exception.dart';
import '../../../../core/services/cloudinary/cloudinary_service.dart';
import '../../../../core/services/supabase/index.dart';
import '../../../../shared/domain/entities/base_entity.dart';
import '../models/video_model.dart';

abstract class VideoRemoteDataSource {
  Future<PaginatedResult<VideoModel>> getForYouFeed({int page = 0});
  Future<PaginatedResult<VideoModel>> getFollowingFeed({int page = 0});
  Future<PaginatedResult<VideoModel>> getUserVideos(
      {required String userId, int page = 0});
  Future<VideoModel> getVideoById(String videoId);
  Future<bool> toggleLike(String videoId);
  Future<void> incrementView(String videoId);
  Future<VideoModel> createVideo({
    required String localVideoPath,
    required String localThumbnailPath,
    required String caption,
    required String visibility,
    List<String> taggedProductIds = const [],
    void Function(double progress)? onProgress,
  });
  Future<VideoModel> updateVideo(
      {required String videoId, required Map<String, dynamic> data});
  Future<void> deleteVideo(String videoId);
  Future<List<VideoModel>> searchVideos(String query);
}

class VideoRemoteDataSourceImpl implements VideoRemoteDataSource {
  static const _table = 'videos';
  static const _likesTable = 'video_likes';
  static const _productTagsTable = 'video_product_tags';
  // Join author profile & tagged products
  static const _select = '''
    *,
    profiles:author_id (
      id, username, display_name, avatar_url, is_verified,
      follower_count, following_count, like_received_count
    ),
    video_product_tags (
      sort_order,
      products (
        id, shop_id, category_id, title, description, brand, status,
        price_min, price_max, currency, stock_total, sold_count,
        rating_avg, rating_count, cover_path, created_at, updated_at,
        shops(shop_name),
        product_media(id, product_id, media_type, storage_path, sort_order, created_at),
        product_variants(id, product_id, sku, variant_name, price, compare_at_price, stock_qty, weight_grams, status, created_at)
      )
    )
  ''';
  static const _limit = Env.videoPageSize;

  final CloudinaryService _cloudinary;

  VideoRemoteDataSourceImpl(this._cloudinary);

  // ── Helper: fetch set of liked video IDs ─────────────────────────────────
  Future<Set<String>> _getLikedIds(List<String> videoIds) async {
    final uid = SupabaseService.currentUserId;
    if (uid == null || videoIds.isEmpty) return {};
    final res = await SupabaseService.from(_likesTable)
        .select('video_id')
        .eq('user_id', uid)
        .inFilter('video_id', videoIds);
    return {for (final r in (res as List)) r['video_id'] as String};
  }

  // ── Helper: map rows → models ─────────────────────────────────────────────
  Future<List<VideoModel>> _toModels(List<dynamic> rows) async {
    final ids = [for (final r in rows) r['id'] as String];
    final liked = await _getLikedIds(ids);
    return [
      for (final r in rows)
        VideoModel.fromJson(r as Map<String, dynamic>,
            isLiked: liked.contains(r['id']))
    ];
  }

  // ── Paginated helper ──────────────────────────────────────────────────────
  Future<PaginatedResult<VideoModel>> _paginate(
      dynamic query,
      int page,
      ) async {
    final (from, to) = SupabaseService.pageRange(page, _limit);
    final rows = await query.range(from, to) as List;
    final models = await _toModels(rows);
    return PaginatedResult(
      items: models,
      page: page,
      limit: _limit,
      hasMore: rows.length == _limit,
    );
  }

  @override
  Future<PaginatedResult<VideoModel>> getForYouFeed({int page = 0}) async {
    try {
      final authNotifier = sl<AuthNotifier>();
      var query = SupabaseService.from(_table)
          .select(_select)
          .eq('status', 'published')
          .eq('visibility', 'public');
      if (authNotifier.userId != null) {
        query = query.neq('author_id', authNotifier.userId!);
      }
      return _paginate(query.order('published_at', ascending: false), page);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<PaginatedResult<VideoModel>> getFollowingFeed({int page = 0}) async {
    try {
      final (from, to) = SupabaseService.pageRange(page, _limit);
      // Dùng RPC get_following_feed
      final rows = await SupabaseService.rpc(
        'get_following_feed',
        params: {'p_limit': _limit, 'p_offset': from},
      ) as List;

      // RPC trả về videos — cần fetch profiles riêng
      final ids = [for (final r in rows) r['id'] as String];
      if (ids.isEmpty) {
        return PaginatedResult(
            items: [], page: page, limit: _limit, hasMore: false);
      }

      // Re-fetch với join để có profiles & liked status song song
      final fullFuture = SupabaseService.from(_table)
          .select(_select)
          .inFilter('id', ids);
      final likedFuture = _getLikedIds(ids);
      final full = await fullFuture as List;
      final liked = await likedFuture;

      final byId = {
        for (final r in full)
          (r as Map<String, dynamic>)['id'] as String: r,
      };
      final models = [
        for (final id in ids)
          if (byId.containsKey(id))
            VideoModel.fromJson(byId[id]!, isLiked: liked.contains(id))
      ];

      return PaginatedResult(
        items: models,
        page: page,
        limit: _limit,
        hasMore: rows.length == _limit,
      );
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<PaginatedResult<VideoModel>> getUserVideos(
      {required String userId, int page = 0}) async {
    try {
      final isOwnProfile = SupabaseService.currentUserId == userId;
      var query = SupabaseService.from(_table)
          .select(_select)
          .eq('author_id', userId);
      if (isOwnProfile) {
        query = query.inFilter('status', ['draft', 'published']);
      } else {
        query = query.eq('status', 'published');
      }
      return _paginate(query.order('created_at', ascending: false), page);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<VideoModel> getVideoById(String videoId) async {
    try {
      final row = await SupabaseService.from(_table)
          .select(_select)
          .eq('id', videoId)
          .single();
      final liked = await _getLikedIds([videoId]);
      return VideoModel.fromJson(
          row,
          isLiked: liked.contains(videoId));
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<bool> toggleLike(String videoId) async {
    try {
      // Dùng RPC toggle_video_like (trả về bool)
      final result = await SupabaseService.rpc(
        'toggle_video_like',
        params: {'p_video_id': videoId},
      );
      return result as bool;
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<void> incrementView(String videoId) async {
    try {
      await SupabaseService.rpc(
        'increment_video_view',
        params: {'p_video_id': videoId},
      );
    } catch (_) {
      // Không throw — view count không critical
    }
  }

  @override
  Future<VideoModel> createVideo({
    required String localVideoPath,
    required String localThumbnailPath,
    required String caption,
    required String visibility,
    List<String> taggedProductIds = const [],
    void Function(double progress)? onProgress,
  }) async {
    try {
      final uid = SupabaseService.currentUserId;
      if (uid == null) throw ServerException('User not authenticated');

      // ── Step 1 & 2: Upload video & thumbnail song song ─────────────────
      final thumbFuture = localThumbnailPath.isNotEmpty
          ? _cloudinary.uploadThumbnail(localThumbnailPath)
          : Future<String?>.value(null);

      final videoUrl = await _cloudinary.uploadVideo(
        localVideoPath,
        onProgress: (p) => onProgress?.call(p * 0.85),
      );
      final thumbnailUrl = await thumbFuture;
      onProgress?.call(0.95);

      // ── Step 3: Insert metadata vào Supabase (chiếm 5% cuối) ───────────
      // Mặc định status = 'draft' (Chờ Super Admin kiểm duyệt trước khi lên Xu hướng)
      var row = await SupabaseService.from(_table)
          .insert({
        'author_id':     uid,
        'video_path':     videoUrl,
        'thumbnail_path': thumbnailUrl,
        'caption':       caption.isEmpty ? null : caption,
        'visibility':    visibility,
        'status':        'draft',
        'published_at':  DateTime.now().toIso8601String(),
      })
          .select(_select)
          .single();

      // ── Step 4: Gắn sản phẩm vào bảng video_product_tags (nếu có) ──────
      if (taggedProductIds.isNotEmpty) {
        final videoId = row['id'] as String;
        final uniqueIds = taggedProductIds.toSet().toList();
        final tagRows = [
          for (var i = 0; i < uniqueIds.length; i++)
            {
              'video_id': videoId,
              'product_id': uniqueIds[i],
              'sort_order': i,
            }
        ];
        await SupabaseService.from(_productTagsTable).insert(tagRows);

        // Fetch lại video đã bao gồm danh sách sản phẩm vừa gắn
        row = await SupabaseService.from(_table)
            .select(_select)
            .eq('id', videoId)
            .single();
      }

      onProgress?.call(1.0);
      return VideoModel.fromJson(row);
    } catch (e) {
      if (kDebugMode){
        dev.log('Error in createVideo: $e', name: 'VIDEO UPLOAD');
      }
      throw ServerException(e.toString());
    }
  }

  @override
  Future<VideoModel> updateVideo(
      {required String videoId,
        required Map<String, dynamic> data}) async {
    try {
      final row = await SupabaseService.from(_table)
          .update(data)
          .eq('id', videoId)
          .select(_select)
          .single();
      return VideoModel.fromJson(row);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<void> deleteVideo(String videoId) async {
    try {
      await SupabaseService.from(_table)
          .update({'status': 'deleted'}).eq('id', videoId);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<List<VideoModel>> searchVideos(String query) async {
    final rows = await SupabaseService.rpc(
      'search_videos',
      params: {
        'p_query': query,
      },
    ) as List;

    if (rows.isEmpty) return [];

    final ids = [for (final e in rows) e['id'] as String];

    final fullFuture = SupabaseService.from('videos')
        .select(_select)
        .inFilter('id', ids);
    final likedFuture = _getLikedIds(ids);
    final full = await fullFuture as List;
    final liked = await likedFuture;

    final byId = {
      for (final r in full)
        (r as Map<String, dynamic>)['id'] as String: r,
    };
    return [
      for (final id in ids)
        if (byId.containsKey(id))
          VideoModel.fromJson(byId[id]!, isLiked: liked.contains(id)),
    ];
  }
}