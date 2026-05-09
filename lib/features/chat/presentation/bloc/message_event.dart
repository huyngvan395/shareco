import 'package:equatable/equatable.dart';
import 'package:shareco/features/chat/domain/entities/chat_entities.dart';

abstract class MessageEvent extends Equatable {
  const MessageEvent();
  @override List<Object?> get props => [];
}

class MessageLoadRequested extends MessageEvent {
  final String conversationId;
  const MessageLoadRequested(this.conversationId);
  @override List<Object?> get props => [conversationId];
}

class MessageLoadMoreRequested extends MessageEvent {
  const MessageLoadMoreRequested();
}

class MessageSendRequested extends MessageEvent {
  final String content;
  final MessageType type;
  final String? replyToId;
  const MessageSendRequested({
    required this.content,
    this.type = MessageType.text,
    this.replyToId,
  });
  @override List<Object?> get props => [content, type, replyToId];
}

class MessageDeleteRequested extends MessageEvent {
  final String messageId;
  const MessageDeleteRequested(this.messageId);
  @override List<Object?> get props => [messageId];
}

class MessageRealtimeReceived extends MessageEvent {
  final MessageEntity message;
  const MessageRealtimeReceived(this.message);
  @override List<Object?> get props => [message.id];
}

class MessageReplySelected extends MessageEvent {
  final MessageEntity? message;
  const MessageReplySelected(this.message);
  @override List<Object?> get props => [message?.id];
}

class MessageSubscribed extends MessageEvent {
  const MessageSubscribed();
}