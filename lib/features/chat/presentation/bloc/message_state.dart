import 'package:equatable/equatable.dart';
import 'package:shareco/features/chat/domain/entities/chat_entities.dart';

abstract class MessageState extends Equatable {
  const MessageState();
  @override List<Object?> get props => [];
}

class MessageInitial extends MessageState { const MessageInitial(); }
class MessageLoading extends MessageState { const MessageLoading(); }

class MessageLoaded extends MessageState {
  final String conversationId;
  final List<MessageEntity> messages;
  final bool isLoadingMore;
  final bool hasReachedMax;
  final int currentPage;
  final bool isSending;
  final MessageEntity? replyingTo;

  const MessageLoaded({
    required this.conversationId,
    required this.messages,
    this.isLoadingMore = false,
    this.hasReachedMax = false,
    this.currentPage = 0,
    this.isSending = false,
    this.replyingTo,
  });

  MessageLoaded copyWith({
    List<MessageEntity>? messages,
    bool? isLoadingMore,
    bool? hasReachedMax,
    int? currentPage,
    bool? isSending,
    MessageEntity? replyingTo,
    bool clearReply = false,
  }) =>
      MessageLoaded(
        conversationId: conversationId,
        messages: messages ?? this.messages,
        isLoadingMore: isLoadingMore ?? this.isLoadingMore,
        hasReachedMax: hasReachedMax ?? this.hasReachedMax,
        currentPage: currentPage ?? this.currentPage,
        isSending: isSending ?? this.isSending,
        replyingTo: clearReply ? null : (replyingTo ?? this.replyingTo),
      );

  @override
  List<Object?> get props =>
      [conversationId, messages, isLoadingMore, hasReachedMax, isSending, replyingTo?.id];
}

class MessageError extends MessageState {
  final String message;
  const MessageError(this.message);
  @override List<Object?> get props => [message];
}