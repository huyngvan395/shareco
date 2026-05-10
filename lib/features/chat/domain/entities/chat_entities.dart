// features/chat/domain/entities/chat_entities.dart

import 'package:equatable/equatable.dart';
import '../../../../shared/domain/entities/base_entity.dart';

// ─── Message type ─────────────────────────────────────────────────────────────

enum MessageType { text, image, video, sticker, gift, audio }

// ─── Message ──────────────────────────────────────────────────────────────────

class MessageEntity extends Equatable {
  final String id;
  final String conversationId;
  final String senderId;
  final ProfileStub sender;
  final MessageType type;
  final String? content;
  final String? mediaUrl;
  final String? replyToId;
  final MessageEntity? replyTo;
  final bool isDeleted;
  final DateTime createdAt;

  // Client-side helpers
  final bool isMine;
  final bool isPending; // optimistic send
  final bool hasFailed;

  const MessageEntity({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.sender,
    this.type = MessageType.text,
    this.content,
    this.mediaUrl,
    this.replyToId,
    this.replyTo,
    this.isDeleted = false,
    required this.createdAt,
    this.isMine = false,
    this.isPending = false,
    this.hasFailed = false,
  });

  String get displayContent {
    if (isDeleted) return 'Message deleted';
    return switch (type) {
      MessageType.text    => content ?? '',
      MessageType.image   => 'Image',
      MessageType.video   => 'Video',
      MessageType.sticker => content ?? '😊',
      MessageType.gift    => 'Gift',
      MessageType.audio => 'Voice message',
    };
  }

  MessageEntity copyWith({
    bool? isPending,
    bool? hasFailed,
    bool? isDeleted,
    String? id,
  }) => MessageEntity(
    id: id ?? this.id,
    conversationId: conversationId,
    senderId: senderId,
    sender: sender,
    type: type,
    content: content,
    mediaUrl: mediaUrl,
    replyToId: replyToId,
    replyTo: replyTo,
    isDeleted: isDeleted ?? this.isDeleted,
    createdAt: createdAt,
    isMine: isMine,
    isPending: isPending ?? this.isPending,
    hasFailed: hasFailed ?? this.hasFailed,
  );

  @override
  List<Object?> get props =>
      [id, conversationId, senderId, type, content, isDeleted, createdAt, isPending];
}

// ─── Conversation ─────────────────────────────────────────────────────────────

class ConversationEntity extends Equatable {
  final String id;
  final List<ProfileStub> participants;
  final String? lastMessage;
  final DateTime? lastMessageAt;
  final String? lastSenderId;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Client-side
  final DateTime? lastReadAt;
  final bool isMuted;

  const ConversationEntity({
    required this.id,
    required this.participants,
    this.lastMessage,
    this.lastMessageAt,
    this.lastSenderId,
    required this.createdAt,
    required this.updatedAt,
    this.lastReadAt,
    this.isMuted = false,
  });

  /// The other user in a 1-to-1 conversation
  ProfileStub? otherUser(String myUserId) =>
      participants.where((p) => p.id != myUserId).firstOrNull;

  /// Number of unread messages (simplified: based on lastReadAt vs lastMessageAt)
  bool get hasUnread =>
      lastMessageAt != null &&
          lastReadAt != null &&
          lastMessageAt!.isAfter(lastReadAt!);

  @override
  List<Object?> get props =>
      [id, lastMessage, lastMessageAt, updatedAt, hasUnread];
}