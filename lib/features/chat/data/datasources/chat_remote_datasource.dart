// features/chat/data/datasources/chat_remote_datasource.dart

import 'package:flutter/cupertino.dart';
import 'package:shareco/core/services/supabase/presence_service.dart';
import '../../../../core/errors/exception.dart';
import '../../../../core/services/supabase/index.dart';
import '../../../../shared/data/models/profile_stub_model.dart';
import '../../../../shared/domain/entities/base_entity.dart';
import '../models/chat_models.dart';

abstract class ChatRemoteDataSource {
  Future<List<ConversationModel>> getConversations();
  Future<ConversationModel> getOrCreateConversation(String otherUserId);
  Future<ConversationModel> getOrCreateShopConversation({
    required String shopId,
    required String ownerId,
    String? shopName,
    String? shopLogo,
    bool? isShopVerified,
  });
  Future<PaginatedResult<MessageModel>> getMessages({
    required String conversationId,
    int page = 0,
  });
  Future<MessageModel> sendMessage(Map<String, dynamic> data);
  Future<void> deleteMessage(String messageId);
  Future<void> markAsRead(String conversationId);
  Stream<MessageModel> watchMessages(String conversationId);
  Stream<ConversationModel> watchConversation(String conversationId);
  Future<List<ProfileStubModel>> searchUsers(String query);
  Stream<Map<String, dynamic>> watchUserPresence(String userId);
}

class ChatRemoteDataSourceImpl implements ChatRemoteDataSource {
  static const _convTable  = 'conversations';
  static const _partTable  = 'conversation_participants';
  static const _msgTable   = 'messages';
  static const _profTable  = 'profiles';
  static const _msgLimit   = 30;
  final PresenceService _presenceService;

  // Join: conversations + shop + participants + their profiles + last_read_at
  static const _convSelectWithShop = '''
    *,
    shops:shop_id (
      id, shop_name, logo_path, is_verified, owner_id
    ),
    conversation_participants (
      user_id,
      last_read_at,
      is_muted,
      profiles:user_id (
        id, username, display_name, avatar_url, is_verified
      )
    )
  ''';

  static const _convSelectFallback = '''
    *,
    conversation_participants (
      user_id,
      last_read_at,
      is_muted,
      profiles:user_id (
        id, username, display_name, avatar_url, is_verified
      )
    )
  ''';

  // Join: messages + sender profile
  static const _msgSelect = '''
    *,
    profiles:sender_id (
      id, username, display_name, avatar_url, is_verified
    )
  ''';

  String get _uid => SupabaseService.currentUserId ?? '';

  ChatRemoteDataSourceImpl({required PresenceService presenceService})
      : _presenceService = presenceService;

  // ── Conversations ──────────────────────────────────────────────────────────

  @override
  Future<List<ConversationModel>> getConversations() async {
    try {
      // Only fetch conversations where current user is a participant
      final participantRows = await SupabaseService.from(_partTable)
          .select('conversation_id')
          .eq('user_id', _uid) as List;

      if (participantRows.isEmpty) return [];

      final ids = participantRows
          .map((r) => r['conversation_id'] as String)
          .toList();

      List rows;
      try {
        rows = await SupabaseService.from(_convTable)
            .select(_convSelectWithShop)
            .inFilter('id', ids)
            .order('updated_at', ascending: false) as List;
      } catch (e) {
        debugPrint('Note: Fallback to basic conv select: $e');
        rows = await SupabaseService.from(_convTable)
            .select(_convSelectFallback)
            .inFilter('id', ids)
            .order('updated_at', ascending: false) as List;
      }

      final convList = rows
          .map((r) => ConversationModel.fromJson(
          r as Map<String, dynamic>, currentUserId: _uid))
          .toList();

      // Batch enrich thông tin Shop cho các hội thoại Shop nếu thiếu logo/tên
      final missingShopIds = convList
          .where((c) => c.isShop && (c.shopLogo == null || c.shopLogo!.isEmpty) && c.shopId != null && c.shopId!.isNotEmpty)
          .map((c) => c.shopId!)
          .toSet()
          .toList();

      if (missingShopIds.isNotEmpty) {
        try {
          final shopRows = await SupabaseService.from('shops')
              .select('id, shop_name, logo_path, is_verified, owner_id')
              .inFilter('id', missingShopIds) as List;
          final shopMap = {for (var s in shopRows) s['id']?.toString(): s};
          for (var i = 0; i < convList.length; i++) {
            final c = convList[i];
            if (c.shopId != null && shopMap.containsKey(c.shopId)) {
              final s = shopMap[c.shopId]!;
              convList[i] = c.copyWith(
                shopName: (c.shopName != null && c.shopName!.isNotEmpty) ? c.shopName : s['shop_name'] as String?,
                shopLogo: (c.shopLogo != null && c.shopLogo!.isNotEmpty) ? c.shopLogo : s['logo_path'] as String?,
                isShopVerified: c.isShopVerified || (s['is_verified'] == true),
                shopOwnerId: c.shopOwnerId ?? s['owner_id'] as String?,
              );
            }
          }
        } catch (_) {}
      }

      return convList;
    } catch (e) {
      debugPrint('ERROR: $e');
      throw ServerException(e.toString());
    }
  }

  @override
  Future<ConversationModel> getOrCreateConversation(
      String otherUserId) async {
    try {
      // Call RPC that returns conversation UUID
      final convId = await SupabaseService.rpc(
        'get_or_create_conversation',
        params: {'other_user_id': otherUserId},
      ) as String;

      // Fetch full conversation with participants
      if (convId.isEmpty) {
        throw const ServerException('Không thể tạo cuộc trò chuyện');
      }

      Map<String, dynamic> row;
      try {
        row = await SupabaseService.from(_convTable)
            .select(_convSelectWithShop)
            .eq('id', convId)
            .single();
      } catch (_) {
        row = await SupabaseService.from(_convTable)
            .select(_convSelectFallback)
            .eq('id', convId)
            .single();
      }

      return ConversationModel.fromJson(
          row, currentUserId: _uid);
    } catch (e) {
      debugPrint('ERROR: $e');
      throw ServerException(e.toString());
    }
  }

  @override
  Future<ConversationModel> getOrCreateShopConversation({
    required String shopId,
    required String ownerId,
    String? shopName,
    String? shopLogo,
    bool? isShopVerified,
  }) async {
    try {
      String? convId;
      try {
        final res = await SupabaseService.rpc(
          'get_or_create_shop_conversation',
          params: {'p_shop_id': shopId},
        );
        convId = res?.toString();
      } catch (e) {
        debugPrint('Warning: get_or_create_shop_conversation RPC error: $e');
      }

      if (convId == null || convId.isEmpty) {
        String effectiveOwnerId = ownerId;
        if (effectiveOwnerId.isEmpty) {
          try {
            final shopRow = await SupabaseService.from('shops')
                .select('owner_id')
                .eq('id', shopId)
                .single();
            effectiveOwnerId = (shopRow['owner_id'] as String?) ?? '';
          } catch (_) {}
        }

        if (effectiveOwnerId.isNotEmpty) {
          // Fallback: gọi get_or_create_conversation với ownerId
          convId = await SupabaseService.rpc(
            'get_or_create_conversation',
            params: {'other_user_id': effectiveOwnerId},
          ) as String;

          // Thử cập nhật gán shop_id vào conversation nếu cột có tồn tại
          try {
            await SupabaseService.from(_convTable)
                .update({'type': 'shop', 'shop_id': shopId})
                .eq('id', convId);
          } catch (_) {}
        }
      }

      if (convId == null || convId.isEmpty) {
        throw const ServerException('Không thể tạo cuộc trò chuyện với Shop');
      }

      Map<String, dynamic> row;
      try {
        row = await SupabaseService.from(_convTable)
            .select(_convSelectWithShop)
            .eq('id', convId)
            .single();
      } catch (_) {
        row = await SupabaseService.from(_convTable)
            .select(_convSelectFallback)
            .eq('id', convId)
            .single();
      }

      final model = ConversationModel.fromJson(row, currentUserId: _uid);

      String? effectiveShopName = (model.shopName != null && model.shopName!.isNotEmpty)
          ? model.shopName
          : shopName;
      String? effectiveShopLogo = (model.shopLogo != null && model.shopLogo!.isNotEmpty)
          ? model.shopLogo
          : shopLogo;
      String? effectiveOwnerId = (model.shopOwnerId != null && model.shopOwnerId!.isNotEmpty)
          ? model.shopOwnerId
          : ownerId;
      bool effectiveVerified = model.isShopVerified || (isShopVerified ?? false);

      // Nếu vẫn thiếu logo hoặc tên gian hàng, truy vấn trực tiếp bảng shops
      if ((effectiveShopLogo == null || effectiveShopLogo.isEmpty || effectiveShopName == null || effectiveShopName.isEmpty) && shopId.isNotEmpty) {
        try {
          final sRow = await SupabaseService.from('shops')
              .select('id, shop_name, logo_path, is_verified, owner_id')
              .eq('id', shopId)
              .maybeSingle();
          if (sRow != null) {
            effectiveShopName ??= sRow['shop_name'] as String?;
            effectiveShopLogo ??= sRow['logo_path'] as String?;
            if (sRow['is_verified'] == true) effectiveVerified = true;
            effectiveOwnerId = (sRow['owner_id'] as String?) ?? effectiveOwnerId;
          }
        } catch (_) {}
      }

      // Enrich thông tin shop nếu chưa có từ query
      return model.copyWith(
        type: 'shop',
        shopId: model.shopId ?? shopId,
        shopName: effectiveShopName,
        shopLogo: effectiveShopLogo,
        isShopVerified: effectiveVerified,
        shopOwnerId: effectiveOwnerId,
      );
    } catch (e) {
      debugPrint('ERROR in getOrCreateShopConversation: $e');
      throw ServerException(e.toString());
    }
  }

  // ── Messages ───────────────────────────────────────────────────────────────

  @override
  Future<PaginatedResult<MessageModel>> getMessages({
    required String conversationId,
    int page = 0,
  }) async {
    try {
      final (from, to) = SupabaseService.pageRange(page, _msgLimit);

      final rows = await SupabaseService.from(_msgTable)
          .select(_msgSelect)
          .eq('conversation_id', conversationId)
          .order('created_at', ascending: false) // newest first
          .range(from, to) as List;

      final models = rows
          .map((r) => MessageModel.fromJson(
          r as Map<String, dynamic>,
          isMine: (r['sender_id'] as String) == _uid))
          .toList();

      // Reverse so oldest is first in the list (chat UX)
      final reversed = models.reversed.toList();

      return PaginatedResult(
        items: reversed,
        page: page,
        limit: _msgLimit,
        hasMore: rows.length == _msgLimit,
      );
    } catch (e) {
      debugPrint('ERROR: $e');
      throw ServerException(e.toString());
    }
  }

  @override
  Future<MessageModel> sendMessage(Map<String, dynamic> data) async {
    try {
      final row = await SupabaseService.from(_msgTable)
          .insert({...data, 'sender_id': _uid})
          .select(_msgSelect)
          .single();

      return MessageModel.fromJson(
          row, isMine: true);
    } catch (e) {
      debugPrint('ERROR: $e');
      throw ServerException(e.toString());
    }
  }

  @override
  Future<void> deleteMessage(String messageId) async {
    try {
      await SupabaseService.from(_msgTable)
          .update({'is_deleted': true})
          .eq('id', messageId)
          .eq('sender_id', _uid);
    } catch (e) {
      debugPrint('ERROR: $e');
      throw ServerException(e.toString());
    }
  }

  @override
  Future<void> markAsRead(String conversationId) async {
    try {
      await SupabaseService.rpc(
        'mark_conversation_read',
        params: {'p_conversation_id': conversationId},
      );
    } catch (_) {
      // Non-critical — don't throw
    }
  }

  // ── Realtime streams ───────────────────────────────────────────────────────

  @override
  Stream<MessageModel> watchMessages(String conversationId) {
    // Track IDs đã thấy để tránh emit lại
    final seenIds = <String>{};

    return SupabaseService.client
        .from(_msgTable)
        .stream(primaryKey: ['id'])
        .eq('conversation_id', conversationId)
        .order('created_at')
        .asyncExpand((rows) async* {   // dùng asyncExpand thay vì .map().asyncMap()
      if (rows.isEmpty) return;

      // Lấy row mới nhất chưa từng thấy
      final newRows = rows.where((r) {
        final id = r['id'] as String?;
        return id != null && !seenIds.contains(id);
      }).toList();

      for (final row in newRows) {
        final id = row['id'] as String;
        seenIds.add(id);

        try {
          final full = await SupabaseService.from(_msgTable)
              .select(_msgSelect)
              .eq('id', id)
              .single();
          yield MessageModel.fromJson(
            full,
            isMine: (full['sender_id'] as String) == _uid,
          );
        } catch (_) {
          yield MessageModel.fromJson(
            {...row, 'profiles': <String, dynamic>{}},
            isMine: (row['sender_id'] as String?) == _uid,
          );
        }
      }
    });
  }

  @override
  Stream<ConversationModel> watchConversation(String conversationId) {
    return SupabaseService.client
        .from(_convTable)
        .stream(primaryKey: ['id'])
        .eq('id', conversationId)
        .map((rows) => rows.isNotEmpty ? rows.first : <String, dynamic>{})
        .asyncMap((row) async {
      if (row.isEmpty) throw const ServerException('Not found');
      final full = await SupabaseService.from(_convTable)
          .select(_convSelectFallback)
          .eq('id', conversationId)
          .single();
      return ConversationModel.fromJson(
          full, currentUserId: _uid);
    });
  }

  // ── User search ────────────────────────────────────────────────────────────

  @override
  Future<List<ProfileStubModel>> searchUsers(String query) async {
    try {
      if (query.trim().isEmpty) return [];
      final rows = await SupabaseService.from(_profTable)
          .select('id, username, display_name, avatar_url, is_verified')
          .or('username.ilike.%$query%,display_name.ilike.%$query%')
          .neq('id', _uid) // exclude self
          .limit(20) as List;

      return rows
          .map((r) => ProfileStubModel.fromJson(r as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('ERROR: $e');
      throw ServerException(e.toString());
    }
  }

  @override
  Stream<Map<String, dynamic>> watchUserPresence(String userId) =>
      _presenceService.watchUserPresence(userId);
}