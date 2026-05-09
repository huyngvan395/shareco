// features/chat/domain/usecases/chat_usecases.dart

import 'package:dartz/dartz.dart';
import '../../../../core/errors/failure.dart';
import '../../../../shared/domain/entities/base_entity.dart';
import '../entities/chat_entities.dart';
import '../repositories/chat_repository.dart';

class GetConversationsUseCase {
  final ChatRepository repo;
  const GetConversationsUseCase(this.repo);
  Future<Either<Failure, List<ConversationEntity>>> call() =>
      repo.getConversations();
}

class GetOrCreateConversationUseCase {
  final ChatRepository repo;
  const GetOrCreateConversationUseCase(this.repo);
  Future<Either<Failure, ConversationEntity>> call(String otherUserId) =>
      repo.getOrCreateConversation(otherUserId);
}

class GetMessagesUseCase {
  final ChatRepository repo;
  const GetMessagesUseCase(this.repo);
  Future<Either<Failure, PaginatedResult<MessageEntity>>> call({
    required String conversationId,
    int page = 0,
  }) =>
      repo.getMessages(conversationId: conversationId, page: page);
}

class SendMessageUseCase {
  final ChatRepository repo;
  const SendMessageUseCase(this.repo);
  Future<Either<Failure, MessageEntity>> call({
    required String conversationId,
    required String content,
    MessageType type = MessageType.text,
    String? replyToId,
  }) =>
      repo.sendMessage(
        conversationId: conversationId,
        content: content,
        type: type,
        replyToId: replyToId,
      );
}

class DeleteMessageUseCase {
  final ChatRepository repo;
  const DeleteMessageUseCase(this.repo);
  Future<Either<Failure, void>> call(String messageId) =>
      repo.deleteMessage(messageId);
}

class MarkAsReadUseCase {
  final ChatRepository repo;
  const MarkAsReadUseCase(this.repo);
  Future<Either<Failure, void>> call(String conversationId) =>
      repo.markAsRead(conversationId);
}

class WatchMessagesUseCase {
  final ChatRepository repo;
  const WatchMessagesUseCase(this.repo);
  Stream<MessageEntity> call(String conversationId) =>
      repo.watchMessages(conversationId);
}

class SearchUsersUseCase {
  final ChatRepository repo;
  const SearchUsersUseCase(this.repo);
  Future<Either<Failure, List<ProfileStub>>> call(String query) =>
      repo.searchUsers(query);
}