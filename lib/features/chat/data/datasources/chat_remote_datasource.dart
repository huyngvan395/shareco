// features/chat/data/datasources/chat_remote_datasource.dart

import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/constants/env.dart';
import '../../../../core/errors/exception.dart';
import '../../../../core/services/supabase/index.dart';
import '../../../../shared/data/models/profile_stub_model.dart';
import '../../../../shared/domain/entities/base_entity.dart';
import '../models/chat_models.dart';
import '../../domain/entities/chat_entities.dart';

abstract class ChatRemoteDataSource {
  Future<List<ConversationModel>> getConversations();
  Future<ConversationModel> getOrCreateConversation(String otherUserId);
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
}

class ChatRemoteDataSourceImpl implements ChatRemoteDataSource {
  static const _convTable  = 'conversations';
  static const _partTable  = 'conversation_participants';
  static const _msgTable   = 'messages';
  static const _profTable  = 'profiles';
  static const _msgLimit   = 30;

  // Join: conversations + participants + their profiles + last_read_at
  static const _convSelect = '''
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

      final rows = await SupabaseService.from(_convTable)
          .select(_convSelect)
          .inFilter('id', ids)
          .order('updated_at', ascending: false) as List;

      return rows
          .map((r) => ConversationModel.fromJson(
          r as Map<String, dynamic>, currentUserId: _uid))
          .toList();
    } catch (e) {
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
      final row = await SupabaseService.from(_convTable)
          .select(_convSelect)
          .eq('id', convId)
          .single();

      return ConversationModel.fromJson(
          row as Map<String, dynamic>, currentUserId: _uid);
    } catch (e) {
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
          .eq('is_deleted', false)
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
          row as Map<String, dynamic>, isMine: true);
    } catch (e) {
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
    return SupabaseService.client
        .from(_msgTable)
        .stream(primaryKey: ['id'])
        .eq('conversation_id', conversationId)
        .order('created_at')
        .map((rows) => rows.last) // only emit new rows
        .asyncMap((row) async {
      // Fetch full message with sender profile
      try {
        final full = await SupabaseService.from(_msgTable)
            .select(_msgSelect)
            .eq('id', row['id'] as String)
            .single();
        return MessageModel.fromJson(
            full as Map<String, dynamic>,
            isMine: (full['sender_id'] as String) == _uid);
      } catch (_) {
        // Fallback: build minimal model from stream row
        return MessageModel.fromJson(
          {...row, 'profiles': <String, dynamic>{}},
          isMine: (row['sender_id'] as String?) == _uid,
        );
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
          .select(_convSelect)
          .eq('id', conversationId)
          .single();
      return ConversationModel.fromJson(
          full as Map<String, dynamic>, currentUserId: _uid);
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
      throw ServerException(e.toString());
    }
  }
}