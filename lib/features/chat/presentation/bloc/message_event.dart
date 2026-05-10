import 'dart:io';

import 'package:equatable/equatable.dart';
import 'package:shareco/features/chat/domain/entities/chat_entities.dart';

abstract class MessageEvent extends Equatable {
  const MessageEvent();
  @override List<Object?> get props => [];
}

class MessageLoadRequested extends MessageEvent {
  final String conversationId;
  final String? otherUserId;
  const MessageLoadRequested(this.conversationId,{this.otherUserId});
  @override List<Object?> get props => [conversationId, otherUserId];
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
  final String conversationId;  // thêm field này
  const MessageSubscribed(this.conversationId);
}

class MessagePresenceUpdated extends MessageEvent {
  final Map<String, dynamic> presenceData;
  const MessagePresenceUpdated(this.presenceData);

  @override
  List<Object?> get props => [presenceData];
}

class MessageWatchPresenceRequested extends MessageEvent {
  final String userId;
  const MessageWatchPresenceRequested(this.userId);
}

class MessageSendImageRequested extends MessageEvent {
  final File file;
  final String localPath;
  const MessageSendImageRequested({
    required this.file,
    required this.localPath,
  });
  @override List<Object?> get props => [localPath];
}

class MessageSendAudioRequested extends MessageEvent {
  final String localPath; // path tạm sau khi record
  const MessageSendAudioRequested({required this.localPath});
  @override List<Object?> get props => [localPath];
}