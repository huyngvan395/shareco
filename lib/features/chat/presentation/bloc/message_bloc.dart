import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shareco/features/chat/domain/entities/chat_entities.dart';
import 'package:shareco/features/chat/domain/usecases/chat_usecases.dart';
import 'package:shareco/features/chat/presentation/bloc/message_event.dart';
import 'package:shareco/features/chat/presentation/bloc/message_state.dart';

import '../../../../core/services/supabase/index.dart';
import '../../../../shared/domain/entities/base_entity.dart';

class MessageBloc extends Bloc<MessageEvent, MessageState> {
  final GetMessagesUseCase getMessages;
  final SendMessageUseCase sendMessage;
  final DeleteMessageUseCase deleteMessage;
  final MarkAsReadUseCase markAsRead;
  final WatchMessagesUseCase watchMessages;

  StreamSubscription<MessageEntity>? _realtimeSub;

  MessageBloc({
    required this.getMessages,
    required this.sendMessage,
    required this.deleteMessage,
    required this.markAsRead,
    required this.watchMessages,
  }) : super(const MessageInitial()) {
    on<MessageLoadRequested>(_onLoad);
    on<MessageLoadMoreRequested>(_onLoadMore);
    on<MessageSendRequested>(_onSend);
    on<MessageDeleteRequested>(_onDelete);
    on<MessageRealtimeReceived>(_onRealtime);
    on<MessageReplySelected>(_onReplySelect);
    on<MessageSubscribed>(_onSubscribe);
  }

  // ── Load messages ──────────────────────────────────────────────────────────

  Future<void> _onLoad(
      MessageLoadRequested event, Emitter<MessageState> emit) async {
    emit(const MessageLoading());

    final r = await getMessages(conversationId: event.conversationId, page: 0);
    r.fold(
          (f) => emit(MessageError(f.message)),
          (p) {
        emit(MessageLoaded(
          conversationId: event.conversationId,
          messages: p.items,
          hasReachedMax: !p.hasMore,
        ));
        // Mark as read + start realtime subscription
        markAsRead(event.conversationId);
        add(const MessageSubscribed());
      },
    );
  }

  // ── Load more (older messages) ─────────────────────────────────────────────

  Future<void> _onLoadMore(
      MessageLoadMoreRequested _, Emitter<MessageState> emit) async {
    final current = state;
    if (current is! MessageLoaded) return;
    if (current.isLoadingMore || current.hasReachedMax) return;

    emit(current.copyWith(isLoadingMore: true));
    final nextPage = current.currentPage + 1;

    final r = await getMessages(
        conversationId: current.conversationId, page: nextPage);
    r.fold(
          (_) => emit(current.copyWith(isLoadingMore: false)),
          (p) => emit(current.copyWith(
        // Prepend older messages at the top
        messages: [...p.items, ...current.messages],
        isLoadingMore: false,
        hasReachedMax: !p.hasMore,
        currentPage: nextPage,
      )),
    );
  }

  // ── Send message (optimistic) ──────────────────────────────────────────────

  Future<void> _onSend(
      MessageSendRequested event, Emitter<MessageState> emit) async {
    final current = state;
    if (current is! MessageLoaded) return;

    final uid = SupabaseService.currentUserId ?? '';
    final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';

    // Optimistic: add message immediately with pending flag
    final optimistic = MessageEntity(
      id: tempId,
      conversationId: current.conversationId,
      senderId: uid,
      sender: const _EmptyProfile(),
      type: event.type,
      content: event.content,
      replyToId: event.replyToId,
      replyTo: event.replyToId != null
          ? current.messages.where((m) => m.id == event.replyToId).firstOrNull
          : null,
      createdAt: DateTime.now(),
      isMine: true,
      isPending: true,
    );

    emit(current.copyWith(
      messages: [...current.messages, optimistic],
      isSending: true,
      clearReply: true,
    ));

    final r = await sendMessage(
      conversationId: current.conversationId,
      content: event.content,
      type: event.type,
      replyToId: event.replyToId,
    );

    r.fold(
          (f) {
        // Mark as failed
        final c = state;
        if (c is MessageLoaded) {
          emit(c.copyWith(
            messages: c.messages.map((m) =>
            m.id == tempId ? m.copyWith(hasFailed: true, isPending: false) : m).toList(),
            isSending: false,
          ));
        }
      },
          (confirmed) {
        // Replace temp message with confirmed one
        final c = state;
        if (c is MessageLoaded) {
          emit(c.copyWith(
            messages: c.messages.map((m) =>
            m.id == tempId ? confirmed : m).toList(),
            isSending: false,
          ));
        }
      },
    );
  }

  // ── Delete message ─────────────────────────────────────────────────────────

  Future<void> _onDelete(
      MessageDeleteRequested event, Emitter<MessageState> emit) async {
    final current = state;
    if (current is! MessageLoaded) return;

    // Optimistic: mark as deleted
    emit(current.copyWith(
      messages: current.messages.map((m) =>
      m.id == event.messageId ? m.copyWith(isDeleted: true) : m).toList(),
    ));

    await deleteMessage(event.messageId);
  }

  // ── Realtime received ──────────────────────────────────────────────────────

  void _onRealtime(
      MessageRealtimeReceived event, Emitter<MessageState> emit) {
    final current = state;
    if (current is! MessageLoaded) return;

    // Ignore if it's an optimistic message we already have
    final exists = current.messages.any((m) =>
    m.id == event.message.id && !m.isPending);
    if (exists) return;

    // Remove any pending message with same content from same sender
    final filtered = current.messages.where((m) =>
    !(m.isPending &&
        m.senderId == event.message.senderId &&
        m.content == event.message.content)).toList();

    emit(current.copyWith(
      messages: [...filtered, event.message],
    ));

    // Mark as read when we receive a message
    if (!event.message.isMine) {
      markAsRead(current.conversationId);
    }
  }

  // ── Reply selection ────────────────────────────────────────────────────────

  void _onReplySelect(
      MessageReplySelected event, Emitter<MessageState> emit) {
    final current = state;
    if (current is! MessageLoaded) return;
    emit(current.copyWith(
      replyingTo: event.message,
      clearReply: event.message == null,
    ));
  }

  // ── Subscribe to realtime ──────────────────────────────────────────────────

  Future<void> _onSubscribe(
      MessageSubscribed _, Emitter<MessageState> emit) async {
    final current = state;
    if (current is! MessageLoaded) return;

    await _realtimeSub?.cancel();
    _realtimeSub = watchMessages(current.conversationId).listen(
          (msg) => add(MessageRealtimeReceived(msg)),
      onError: (_) {}, // Ignore stream errors silently
    );
  }

  @override
  Future<void> close() async {
    await _realtimeSub?.cancel();
    return super.close();
  }
}

// ─── Placeholder profile (for optimistic messages) ───────────────────────────

class _EmptyProfile extends ProfileStub {
  const _EmptyProfile()
      : super(id: '', username: 'me', displayName: 'Me');
}