// features/chat/data/models/chat_models.dart

import '../../../../shared/data/models/profile_stub_model.dart';
import '../../domain/entities/chat_entities.dart';

// ─── Message model ────────────────────────────────────────────────────────────

class MessageModel extends MessageEntity {
  const MessageModel({
    required super.id,
    required super.conversationId,
    required super.senderId,
    required super.sender,
    super.type,
    super.content,
    super.mediaUrl,
    super.replyToId,
    super.replyTo,
    super.isDeleted,
    required super.createdAt,
    super.isMine,
    super.isPending,
    super.hasFailed,
  });

  factory MessageModel.fromJson(
    Map<String, dynamic> json, {
    bool isMine = false,
  }) {
    final senderJson = json['profiles'] as Map<String, dynamic>? ?? {};
    return MessageModel(
      id: json['id'] as String,
      conversationId: json['conversation_id'] as String,
      senderId: json['sender_id'] as String,
      sender: ProfileStubModel.fromJson({
        'id': json['sender_id'],
        ...senderJson,
      }),
      type: _parseType(json['type'] as String? ?? 'text'),
      content: json['content'] as String?,
      mediaUrl: json['media_url'] as String?,
      replyToId: json['reply_to_id'] as String?,
      isDeleted: (json['is_deleted'] as bool?) ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      isMine: isMine,
    );
  }

  /// Build optimistic message (before server confirms)
  factory MessageModel.optimistic({
    required String tempId,
    required String conversationId,
    required String senderId,
    required ProfileStubModel sender,
    required String content,
    MessageType type = MessageType.text,
    String? replyToId,
  }) => MessageModel(
    id: tempId,
    conversationId: conversationId,
    senderId: senderId,
    sender: sender,
    type: type,
    content: content,
    replyToId: replyToId,
    createdAt: DateTime.now(),
    isMine: true,
    isPending: true,
  );

  Map<String, dynamic> toInsertJson() => {
    'conversation_id': conversationId,
    'sender_id': senderId,
    'type': type.name,
    if (content != null) 'content': content,
    if (mediaUrl != null) 'media_url': mediaUrl,
    if (replyToId != null) 'reply_to_id': replyToId,
  };

  static MessageType _parseType(String raw) => switch (raw) {
    'image' => MessageType.image,
    'video' => MessageType.video,
    'sticker' => MessageType.sticker,
    'gift' => MessageType.gift,
    'audio' => MessageType.audio,
    _ => MessageType.text,
  };
}

// ─── Conversation model ───────────────────────────────────────────────────────

class ConversationModel extends ConversationEntity {
  const ConversationModel({
    required super.id,
    required super.participants,
    super.lastMessage,
    super.lastMessageAt,
    super.lastSenderId,
    required super.createdAt,
    required super.updatedAt,
    super.lastReadAt,
    super.isMuted,
  });

  factory ConversationModel.fromJson(
    Map<String, dynamic> json, {
    String? currentUserId,
  }) {
    // Participants come from a join: conversation_participants -> profiles
    final participantsJson =
        (json['conversation_participants'] as List?)
            ?.cast<Map<String, dynamic>>() ??
        [];

    final participants = participantsJson.map((cp) {
      final profile = cp['profiles'] as Map<String, dynamic>? ?? {};
      final userId = cp['user_id'] as String? ?? '';
      return ProfileStubModel.fromJson({'id': userId, ...profile});
    }).toList();

    // Last read for current user
    DateTime? lastReadAt;
    if (currentUserId != null) {
      final myEntry = participantsJson.firstWhere(
        (cp) => cp['user_id'] == currentUserId,
        orElse: () => <String, dynamic>{},
      );
      final raw = myEntry['last_read_at'];
      if (raw != null) lastReadAt = DateTime.tryParse(raw as String);
    }

    final lastMsgAt = json['last_message_at'] != null
        ? DateTime.tryParse(json['last_message_at'] as String)
        : null;

    return ConversationModel(
      id: json['id'] as String,
      participants: participants,
      lastMessage: json['last_message'] as String?,
      lastMessageAt: lastMsgAt,
      lastSenderId: json['last_sender_id'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      lastReadAt: lastReadAt,
      isMuted: false,
    );
  }
}
