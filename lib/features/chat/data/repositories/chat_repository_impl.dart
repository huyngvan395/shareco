// features/chat/data/repositories/chat_repository_impl.dart

import 'package:dartz/dartz.dart';
import '../../../../core/errors/exception.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/services/supabase/index.dart';
import '../../../../shared/data/models/profile_stub_model.dart';
import '../../../../shared/domain/entities/base_entity.dart';
import '../../domain/entities/chat_entities.dart';
import '../../domain/repositories/chat_repository.dart';
import '../datasources/chat_remote_datasource.dart';
import '../models/chat_models.dart';

class ChatRepositoryImpl implements ChatRepository {
  final ChatRemoteDataSource remote;
  const ChatRepositoryImpl({required this.remote});

  Either<Failure, T> _handle<T>(dynamic e) {
    if (e is AuthException) return Left(AuthFailure(e.message));
    if (e is ServerException) return Left(ServerFailure(e.message));
    return Left(UnknownFailure(e.toString()));
  }

  @override
  Future<Either<Failure, List<ConversationEntity>>> getConversations() async {
    try {
      return Right(await remote.getConversations());
    } catch (e) {
      return _handle(e);
    }
  }

  @override
  Future<Either<Failure, ConversationEntity>> getOrCreateConversation(
      String otherUserId) async {
    try {
      return Right(await remote.getOrCreateConversation(otherUserId));
    } catch (e) {
      return _handle(e);
    }
  }

  @override
  Future<Either<Failure, PaginatedResult<MessageEntity>>> getMessages({
    required String conversationId,
    int page = 0,
  }) async {
    try {
      return Right(await remote.getMessages(
          conversationId: conversationId, page: page));
    } catch (e) {
      return _handle(e);
    }
  }

  @override
  Future<Either<Failure, MessageEntity>> sendMessage({
    required String conversationId,
    required String content,
    MessageType type = MessageType.text,
    String? replyToId,
  }) async {
    try {
      final model = await remote.sendMessage({
        'conversation_id': conversationId,
        'content': content,
        'type': type.name,
        if (replyToId != null) 'reply_to_id': replyToId,
      });
      return Right(model);
    } catch (e) {
      return _handle(e);
    }
  }

  @override
  Future<Either<Failure, MessageEntity>> sendMediaMessage({
    required String conversationId,
    required String mediaUrl,
    required MessageType type,
  }) async {
    try {
      final model = await remote.sendMessage({
        'conversation_id': conversationId,
        'media_url': mediaUrl,
        'type': type.name,
      });
      return Right(model);
    } catch (e) {
      return _handle(e);
    }
  }

  @override
  Future<Either<Failure, void>> deleteMessage(String messageId) async {
    try {
      await remote.deleteMessage(messageId);
      return const Right(null);
    } catch (e) {
      return _handle(e);
    }
  }

  @override
  Future<Either<Failure, void>> markAsRead(String conversationId) async {
    try {
      await remote.markAsRead(conversationId);
      return const Right(null);
    } catch (e) {
      return _handle(e);
    }
  }

  @override
  Stream<MessageEntity> watchMessages(String conversationId) =>
      remote.watchMessages(conversationId);

  @override
  Stream<ConversationEntity> watchConversation(String conversationId) =>
      remote.watchConversation(conversationId);

  @override
  Future<Either<Failure, List<ProfileStub>>> searchUsers(String query) async {
    try {
      return Right(await remote.searchUsers(query));
    } catch (e) {
      return _handle(e);
    }
  }
}