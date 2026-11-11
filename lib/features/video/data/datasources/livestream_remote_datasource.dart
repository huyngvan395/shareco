// features/video/data/datasources/livestream_remote_datasource.dart

import '../../../../core/services/supabase/index.dart';

class LivestreamRoomInfo {
  final String id;
  final String hostId;
  final String hostUsername;
  final String hostDisplayName;
  final String? hostAvatarUrl;
  final String title;
  final String? coverUrl;
  final String channelName;
  final String status;
  final int viewerCount;
  final int likeCount;
  final int totalGiftCoins;
  final String? pinnedProductId;
  final DateTime startedAt;

  const LivestreamRoomInfo({
    required this.id,
    required this.hostId,
    required this.hostUsername,
    required this.hostDisplayName,
    this.hostAvatarUrl,
    required this.title,
    this.coverUrl,
    required this.channelName,
    required this.status,
    required this.viewerCount,
    required this.likeCount,
    required this.totalGiftCoins,
    this.pinnedProductId,
    required this.startedAt,
  });

  factory LivestreamRoomInfo.fromMap(Map<String, dynamic> map) {
    final profile = map['profiles'];
    final profileMap = profile is Map
        ? Map<String, dynamic>.from(profile)
        : <String, dynamic>{};

    final username = profileMap['username']?.toString() ?? 'streamer';
    final displayName =
        profileMap['display_name']?.toString() ?? username;

    return LivestreamRoomInfo(
      id: map['id']?.toString() ?? '',
      hostId: map['host_id']?.toString() ?? '',
      hostUsername: username,
      hostDisplayName: displayName.isNotEmpty ? displayName : username,
      hostAvatarUrl: profileMap['avatar_url']?.toString(),
      title: map['title']?.toString() ?? 'Phát trực tiếp',
      coverUrl: map['cover_url']?.toString(),
      channelName: map['channel_name']?.toString() ?? 'live_room',
      status: map['status']?.toString() ?? 'live',
      viewerCount: (map['viewer_count'] as num?)?.toInt() ?? 0,
      likeCount: (map['like_count'] as num?)?.toInt() ?? 0,
      totalGiftCoins: (map['total_gift_coins'] as num?)?.toInt() ?? 0,
      pinnedProductId: map['pinned_product_id']?.toString(),
      startedAt: DateTime.tryParse(map['started_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  LivestreamRoomInfo copyWith({
    String? title,
    String? status,
    int? viewerCount,
    int? likeCount,
    int? totalGiftCoins,
    String? pinnedProductId,
    bool clearPinnedProduct = false,
  }) {
    return LivestreamRoomInfo(
      id: id,
      hostId: hostId,
      hostUsername: hostUsername,
      hostDisplayName: hostDisplayName,
      hostAvatarUrl: hostAvatarUrl,
      title: title ?? this.title,
      coverUrl: coverUrl,
      channelName: channelName,
      status: status ?? this.status,
      viewerCount: viewerCount ?? this.viewerCount,
      likeCount: likeCount ?? this.likeCount,
      totalGiftCoins: totalGiftCoins ?? this.totalGiftCoins,
      pinnedProductId: clearPinnedProduct
          ? null
          : (pinnedProductId ?? this.pinnedProductId),
      startedAt: startedAt,
    );
  }
}

class LivestreamCommentItem {
  final String id;
  final String livestreamId;
  final String userId;
  final String username;
  final String displayName;
  final String? avatarUrl;
  final String content;
  final String type; // 'chat', 'system', 'gift'
  final String? giftName;
  final String? giftIcon;
  final int giftQuantity;
  final int giftCoins;
  final DateTime createdAt;

  bool get isJoinEvent => type == 'system' && content.startsWith('[JOIN]');
  bool get isLikeEvent => type == 'system' && content.startsWith('[LIKE]');

  String get cleanContent {
    if (content.startsWith('[JOIN]')) {
      return content.substring(6).trim();
    }
    if (content.startsWith('[LIKE]')) {
      return content.substring(6).trim();
    }
    return content;
  }

  const LivestreamCommentItem({
    required this.id,
    required this.livestreamId,
    required this.userId,
    required this.username,
    required this.displayName,
    this.avatarUrl,
    required this.content,
    this.type = 'chat',
    this.giftName,
    this.giftIcon,
    this.giftQuantity = 1,
    this.giftCoins = 0,
    required this.createdAt,
  });

  factory LivestreamCommentItem.fromMap(Map<String, dynamic> map) {
    final profile = map['profiles'];
    final profileMap = profile is Map
        ? Map<String, dynamic>.from(profile)
        : <String, dynamic>{};

    final username = profileMap['username']?.toString() ?? 'user';
    final displayName =
        profileMap['display_name']?.toString() ?? username;

    return LivestreamCommentItem(
      id: map['id']?.toString() ?? '',
      livestreamId: map['livestream_id']?.toString() ?? '',
      userId: map['user_id']?.toString() ?? '',
      username: username,
      displayName: displayName.isNotEmpty ? displayName : username,
      avatarUrl: profileMap['avatar_url']?.toString(),
      content: map['content']?.toString() ?? '',
      type: map['type']?.toString() ?? 'chat',
      giftName: map['gift_name']?.toString(),
      giftIcon: map['gift_icon']?.toString(),
      giftQuantity: (map['gift_quantity'] as num?)?.toInt() ?? 1,
      giftCoins: (map['gift_coins'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.tryParse(map['created_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}

class LivestreamRemoteDataSource {
  LivestreamRemoteDataSource._();
  static final LivestreamRemoteDataSource instance =
      LivestreamRemoteDataSource._();

  // In-memory fallback rooms when DB tables haven't been migrated yet
  final List<LivestreamRoomInfo> _localRooms = [];

  Future<LivestreamRoomInfo> createLivestream({
    required String title,
    required String channelName,
    List<String> productIds = const [],
    String? pinnedProductId,
  }) async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) {
      throw Exception('Vui lòng đăng nhập để bắt đầu Livestream');
    }

    String username = 'streamer';
    String displayName = 'Streamer';
    String? avatarUrl;

    try {
      final profile = await SupabaseService.from('profiles')
          .select('username, display_name, avatar_url')
          .eq('id', userId)
          .maybeSingle();
      if (profile != null) {
        username = profile['username']?.toString() ?? username;
        displayName = profile['display_name']?.toString() ?? username;
        avatarUrl = profile['avatar_url']?.toString();
      }
    } catch (_) {}

    final effectivePinned =
        pinnedProductId ?? (productIds.isNotEmpty ? productIds.first : null);

    try {
      // End any previous lingering 'live' sessions of this host
      await SupabaseService.from('livestreams')
          .update({
            'status': 'ended',
            'ended_at': DateTime.now().toIso8601String(),
          })
          .eq('host_id', userId)
          .eq('status', 'live');

      final inserted = await SupabaseService.from('livestreams')
          .insert({
            'host_id': userId,
            'title': title.trim().isEmpty ? 'Phát trực tiếp' : title.trim(),
            'channel_name': channelName,
            'status': 'live',
            'viewer_count': 0,
            'like_count': 0,
            'total_gift_coins': 0,
            'pinned_product_id': effectivePinned,
          })
          .select('*, profiles!livestreams_host_id_fkey(username, display_name, avatar_url)')
          .single();

      final streamId = inserted['id'].toString();

      if (productIds.isNotEmpty) {
        final rows = <Map<String, dynamic>>[];
        for (int i = 0; i < productIds.length; i++) {
          rows.add({
            'livestream_id': streamId,
            'product_id': productIds[i],
            'is_pinned': productIds[i] == effectivePinned,
            'sort_order': i,
          });
        }
        await SupabaseService.from('livestream_products').upsert(rows);
      }

      await SupabaseService.from('livestream_comments').insert({
        'livestream_id': streamId,
        'user_id': userId,
        'content':
            'Chào mừng mọi người đến với phòng Live! Nhấn vào Giỏ hàng góc dưới để săn deal nhé 🛒🔥',
        'type': 'system',
      });

      return LivestreamRoomInfo.fromMap(Map<String, dynamic>.from(inserted));
    } catch (_) {
      final fallbackRoom = LivestreamRoomInfo(
        id: 'local-${DateTime.now().millisecondsSinceEpoch}',
        hostId: userId,
        hostUsername: username,
        hostDisplayName: displayName,
        hostAvatarUrl: avatarUrl,
        title: title.trim().isEmpty ? 'Phát trực tiếp' : title.trim(),
        channelName: channelName,
        status: 'live',
        viewerCount: 0,
        likeCount: 0,
        totalGiftCoins: 0,
        pinnedProductId: effectivePinned,
        startedAt: DateTime.now(),
      );
      _localRooms.removeWhere((r) => r.hostId == userId);
      _localRooms.insert(0, fallbackRoom);
      return fallbackRoom;
    }
  }

  Future<void> endLivestream(String livestreamId) async {
    _localRooms.removeWhere((r) => r.id == livestreamId);
    if (livestreamId.startsWith('local-')) return;
    try {
      await SupabaseService.from('livestreams').update({
        'status': 'ended',
        'viewer_count': 0,
        'ended_at': DateTime.now().toIso8601String(),
      }).eq('id', livestreamId);
    } catch (_) {}
  }

  Future<void> updateViewerCount(String livestreamId, int exactCount) async {
    if (livestreamId.startsWith('local-')) return;
    try {
      await SupabaseService.from('livestreams').update({
        'viewer_count': exactCount < 0 ? 0 : exactCount,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', livestreamId);
    } catch (_) {}
  }

  Future<({String userId, String username, String displayName, String? avatarUrl})>
      getCurrentUserMiniProfile() async {
    final userId = SupabaseService.currentUserId ?? '';
    if (userId.isEmpty) {
      return (
        userId: '',
        username: 'khach',
        displayName: 'Khách xem Live',
        avatarUrl: null,
      );
    }
    try {
      final profile = await SupabaseService.from('profiles')
          .select('username, display_name, avatar_url')
          .eq('id', userId)
          .maybeSingle();
      if (profile != null) {
        final username = profile['username']?.toString() ?? 'user';
        final displayName = profile['display_name']?.toString() ?? username;
        return (
          userId: userId,
          username: username,
          displayName: displayName.isNotEmpty ? displayName : username,
          avatarUrl: profile['avatar_url']?.toString(),
        );
      }
    } catch (_) {}
    return (
      userId: userId,
      username: 'user',
      displayName: 'Người xem',
      avatarUrl: null,
    );
  }

  Future<List<LivestreamRoomInfo>> getActiveLivestreams() async {
    try {
      final rows = await SupabaseService.from('livestreams')
          .select(
            '*, profiles!livestreams_host_id_fkey(username, display_name, avatar_url)',
          )
          .eq('status', 'live')
          .order('started_at', ascending: false)
          .limit(30);

      final list = (rows as List)
          .map((e) => LivestreamRoomInfo.fromMap(Map<String, dynamic>.from(e)))
          .toList();
      if (list.isNotEmpty) return list;
    } catch (_) {}
    return _localRooms;
  }

  Future<LivestreamRoomInfo?> getLivestreamRoom(String livestreamId) async {
    if (livestreamId.startsWith('local-')) {
      for (final r in _localRooms) {
        if (r.id == livestreamId) return r;
      }
      return null;
    }

    try {
      final row = await SupabaseService.from('livestreams')
          .select(
            '*, profiles!livestreams_host_id_fkey(username, display_name, avatar_url)',
          )
          .eq('id', livestreamId)
          .maybeSingle();
      if (row != null) {
        return LivestreamRoomInfo.fromMap(Map<String, dynamic>.from(row));
      }
    } catch (_) {}
    return null;
  }

  Future<List<String>> getLivestreamProductIds(String livestreamId) async {
    if (livestreamId.startsWith('local-')) return [];
    try {
      final rows = await SupabaseService.from('livestream_products')
          .select('product_id')
          .eq('livestream_id', livestreamId)
          .order('sort_order', ascending: true);

      return (rows as List)
          .map((e) => e['product_id']?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> syncLivestreamProducts({
    required String livestreamId,
    required List<String> productIds,
    String? pinnedProductId,
  }) async {
    if (livestreamId.startsWith('local-')) return;
    try {
      await SupabaseService.from('livestream_products')
          .delete()
          .eq('livestream_id', livestreamId);

      if (productIds.isNotEmpty) {
        final rows = <Map<String, dynamic>>[];
        for (int i = 0; i < productIds.length; i++) {
          rows.add({
            'livestream_id': livestreamId,
            'product_id': productIds[i],
            'is_pinned': productIds[i] == pinnedProductId,
            'sort_order': i,
          });
        }
        await SupabaseService.from('livestream_products').insert(rows);
      }

      await SupabaseService.from('livestreams').update({
        'pinned_product_id': pinnedProductId,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', livestreamId);
    } catch (_) {}
  }

  Future<void> pinProduct({
    required String livestreamId,
    required String? productId,
  }) async {
    if (livestreamId.startsWith('local-')) return;
    try {
      await SupabaseService.from('livestream_products')
          .update({'is_pinned': false})
          .eq('livestream_id', livestreamId);

      if (productId != null) {
        await SupabaseService.from('livestream_products')
            .update({'is_pinned': true})
            .eq('livestream_id', livestreamId)
            .eq('product_id', productId);
      }

      await SupabaseService.from('livestreams').update({
        'pinned_product_id': productId,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', livestreamId);
    } catch (_) {}
  }

  Future<List<LivestreamCommentItem>> getComments(String livestreamId) async {
    if (livestreamId.startsWith('local-')) return [];
    try {
      final rows = await SupabaseService.from('livestream_comments')
          .select(
            '*, profiles!livestream_comments_user_id_fkey(username, display_name, avatar_url)',
          )
          .eq('livestream_id', livestreamId)
          .order('created_at', ascending: true)
          .limit(80);

      return (rows as List)
          .map(
            (e) => LivestreamCommentItem.fromMap(Map<String, dynamic>.from(e)),
          )
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<LivestreamCommentItem?> sendComment({
    required String livestreamId,
    required String content,
  }) async {
    final userId = SupabaseService.currentUserId;
    if (userId == null || content.trim().isEmpty) return null;

    if (!livestreamId.startsWith('local-')) {
      try {
        final row = await SupabaseService.from('livestream_comments')
            .insert({
              'livestream_id': livestreamId,
              'user_id': userId,
              'content': content.trim(),
              'type': 'chat',
            })
            .select(
              '*, profiles!livestream_comments_user_id_fkey(username, display_name, avatar_url)',
            )
            .single();
        return LivestreamCommentItem.fromMap(Map<String, dynamic>.from(row));
      } catch (_) {}
    }

    return LivestreamCommentItem(
      id: 'local-c-${DateTime.now().millisecondsSinceEpoch}',
      livestreamId: livestreamId,
      userId: userId,
      username: 'bạn',
      displayName: 'Bạn',
      content: content.trim(),
      type: 'chat',
      createdAt: DateTime.now(),
    );
  }

  Future<LivestreamCommentItem?> sendRoomActivity({
    required String livestreamId,
    required String tag, // 'JOIN' or 'LIKE'
    required String message,
  }) async {
    final userId = SupabaseService.currentUserId;
    final formatted = '[$tag] ${message.trim()}';
    if (userId != null && !livestreamId.startsWith('local-')) {
      try {
        final row = await SupabaseService.from('livestream_comments')
            .insert({
              'livestream_id': livestreamId,
              'user_id': userId,
              'content': formatted,
              'type': 'system',
            })
            .select(
              '*, profiles!livestream_comments_user_id_fkey(username, display_name, avatar_url)',
            )
            .single();
        return LivestreamCommentItem.fromMap(Map<String, dynamic>.from(row));
      } catch (_) {}
    }

    final me = await getCurrentUserMiniProfile();
    return LivestreamCommentItem(
      id: 'local-act-${DateTime.now().millisecondsSinceEpoch}',
      livestreamId: livestreamId,
      userId: me.userId.isEmpty ? 'guest' : me.userId,
      username: me.username,
      displayName: me.displayName,
      avatarUrl: me.avatarUrl,
      content: formatted,
      type: 'system',
      createdAt: DateTime.now(),
    );
  }

  Future<void> joinLivestream(String livestreamId, {String? hostId}) async {
    if (livestreamId.startsWith('local-')) return;
    final uid = SupabaseService.currentUserId;
    if (uid != null && hostId != null && uid == hostId) return;
    try {
      await SupabaseService.rpc(
        'join_livestream',
        params: {'p_livestream_id': livestreamId},
      );
    } catch (_) {}
  }

  Future<void> leaveLivestream(String livestreamId, {String? hostId}) async {
    if (livestreamId.startsWith('local-')) return;
    final uid = SupabaseService.currentUserId;
    if (uid != null && hostId != null && uid == hostId) return;
    try {
      await SupabaseService.rpc(
        'leave_livestream',
        params: {'p_livestream_id': livestreamId},
      );
    } catch (_) {}
  }

  Future<void> likeLivestream(String livestreamId, {int count = 1}) async {
    if (livestreamId.startsWith('local-')) return;
    try {
      await SupabaseService.rpc(
        'like_livestream',
        params: {
          'p_livestream_id': livestreamId,
          'p_count': count,
        },
      );
    } catch (_) {}
  }
}

