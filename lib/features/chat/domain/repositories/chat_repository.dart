// features/chat/domain/repositories/chat_repository.dart

import 'dart:io';

import 'package:dartz/dartz.dart';
import '../../../../core/errors/failure.dart';
import '../../../../shared/domain/entities/base_entity.dart';
import '../entities/chat_entities.dart';

abstract class ChatRepository {
  /// List all conversations for the current user, ordered by latest message
  Future<Either<Failure, List<ConversationEntity>>> getConversations();

  /// Get or create a 1-to-1 conversation with [otherUserId]
  Future<Either<Failure, ConversationEntity>> getOrCreateConversation(
      String otherUserId);

  /// Load paginated messages for a conversation
  Future<Either<Failure, PaginatedResult<MessageEntity>>> getMessages({
    required String conversationId,
    int page = 0,
  });

  /// Send a text message
  Future<Either<Failure, MessageEntity>> sendMessage({
    required String conversationId,
    String? content,
    MessageType type,
    String? replyToId,
    String? mediaUrl
  });

  /// Send an image message (after upload)
  Future<Either<Failure, MessageEntity>> sendMediaMessage({
    required String conversationId,
    required String mediaUrl,
    required MessageType type,
  });

  /// Delete (soft-delete) a message
  Future<Either<Failure, void>> deleteMessage(String messageId);

  /// Mark all messages in conversation as read
  Future<Either<Failure, void>> markAsRead(String conversationId);

  /// Realtime stream of new messages for a conversation
  Stream<MessageEntity> watchMessages(String conversationId);

  /// Realtime stream of conversation updates (last message)
  Stream<ConversationEntity> watchConversation(String conversationId);

  /// Search users to start a new chat
  Future<Either<Failure, List<ProfileStub>>> searchUsers(String query);

  Stream<Map<String, dynamic>> watchUserPresence(String userId);

  Future<Either<Failure, String>> uploadMedia(
      File file, {
        String folder,
        void Function(double progress)? onProgress,
      });
}