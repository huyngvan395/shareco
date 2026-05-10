import 'dart:async';
import 'dart:io';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shareco/core/notifier/auth_notifier.dart';
import 'package:shareco/features/chat/domain/entities/chat_entities.dart';
import 'package:shareco/features/chat/domain/usecases/chat_usecases.dart';
import 'package:shareco/features/chat/domain/usecases/upload_media_usecase.dart';
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
  final WatchUserPresenceUseCase watchUserPresence;
  final UploadMediaUseCase uploadMedia;
  StreamSubscription? _presenceSub;

  StreamSubscription<MessageEntity>? _realtimeSub;

  MessageBloc({
    required this.getMessages,
    required this.sendMessage,
    required this.deleteMessage,
    required this.markAsRead,
    required this.watchMessages,
    required this.watchUserPresence,
    required this.uploadMedia,
  }) : super(const MessageInitial()) {
    on<MessageLoadRequested>(_onLoad);
    on<MessageLoadMoreRequested>(_onLoadMore);
    on<MessageSendRequested>(_onSend);
    on<MessageDeleteRequested>(_onDelete);
    on<MessageRealtimeReceived>(_onRealtime);
    on<MessageReplySelected>(_onReplySelect);
    on<MessageSubscribed>(_onSubscribe);
    on<MessagePresenceUpdated>(_onPresenceUpdated);
    on<MessageWatchPresenceRequested>(_onWatchPresence);
    on<MessageSendImageRequested>(_onSendImage);
    on<MessageSendAudioRequested>(_onSendAudio);
  }

  // ── Load messages ──────────────────────────────────────────────────────────

  Future<void> _onLoad(
    MessageLoadRequested event,
    Emitter<MessageState> emit,
  ) async {
    emit(const MessageLoading());

    final r = await getMessages(conversationId: event.conversationId, page: 0);
    r.fold((f) => emit(MessageError(f.message)), (p) {
      emit(
        MessageLoaded(
          conversationId: event.conversationId,
          messages: p.items,
          hasReachedMax: !p.hasMore,
        ),
      );
      markAsRead(event.conversationId);
      add(MessageSubscribed(event.conversationId));

      if (event.otherUserId != null) {
        add(MessageWatchPresenceRequested(event.otherUserId!));
      }
    });
  }

  // ── Load more (older messages) ─────────────────────────────────────────────

  Future<void> _onLoadMore(
    MessageLoadMoreRequested _,
    Emitter<MessageState> emit,
  ) async {
    final current = state;
    if (current is! MessageLoaded) return;
    if (current.isLoadingMore || current.hasReachedMax) return;

    emit(current.copyWith(isLoadingMore: true));
    final nextPage = current.currentPage + 1;

    final r = await getMessages(
      conversationId: current.conversationId,
      page: nextPage,
    );
    r.fold(
      (_) => emit(current.copyWith(isLoadingMore: false)),
      (p) => emit(
        current.copyWith(
          // Prepend older messages at the top
          messages: [...p.items, ...current.messages],
          isLoadingMore: false,
          hasReachedMax: !p.hasMore,
          currentPage: nextPage,
        ),
      ),
    );
  }

  // ── Send message (optimistic) ──────────────────────────────────────────────

  Future<void> _onSend(
    MessageSendRequested event,
    Emitter<MessageState> emit,
  ) async {
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

    emit(
      current.copyWith(
        messages: [...current.messages, optimistic],
        isSending: true,
        clearReply: true,
      ),
    );

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
          emit(
            c.copyWith(
              messages: c.messages
                  .map(
                    (m) => m.id == tempId
                        ? m.copyWith(hasFailed: true, isPending: false)
                        : m,
                  )
                  .toList(),
              isSending: false,
            ),
          );
        }
      },
      (confirmed) {
        // Replace temp message with confirmed one
        final c = state;
        if (c is MessageLoaded) {
          emit(
            c.copyWith(
              messages: c.messages
                  .map((m) => m.id == tempId ? confirmed : m)
                  .toList(),
              isSending: false,
            ),
          );
        }
      },
    );
  }

  // ── Delete message ─────────────────────────────────────────────────────────

  Future<void> _onDelete(
    MessageDeleteRequested event,
    Emitter<MessageState> emit,
  ) async {
    final current = state;
    if (current is! MessageLoaded) return;

    // Optimistic: mark as deleted
    emit(
      current.copyWith(
        messages: current.messages
            .map(
              (m) => m.id == event.messageId ? m.copyWith(isDeleted: true) : m,
            )
            .toList(),
      ),
    );

    await deleteMessage(event.messageId);
  }

  // ── Realtime received ──────────────────────────────────────────────────────

  void _onRealtime(MessageRealtimeReceived event, Emitter<MessageState> emit) {
    final current = state;
    if (current is! MessageLoaded) return;

    final incoming = event.message;
    // if (incoming.isDeleted) {
    //   emit(current.copyWith(
    //     messages: current.messages
    //         .where((m) => m.id != incoming.id)
    //         .toList(),
    //   ));
    //   return;
    // }
    final existingIndex = current.messages.indexWhere(
      (m) => m.id == incoming.id,
    );

    List<MessageEntity> updated;

    if (existingIndex != -1) {
      // ✅ Message đã tồn tại → replace tại đúng vị trí (giữ thứ tự)
      updated = List.of(current.messages);
      updated[existingIndex] = incoming;
    } else {
      // Tin nhắn mới hoàn toàn: xóa pending trùng content rồi append
      final filtered = current.messages
          .where(
            (m) =>
                !(m.isPending &&
                    m.senderId == incoming.senderId &&
                    m.content == incoming.content),
          )
          .toList();
      updated = [...filtered, incoming];
    }

    emit(current.copyWith(messages: updated));

    if (!incoming.isMine) {
      markAsRead(current.conversationId);
    }
  }

  // ── Reply selection ────────────────────────────────────────────────────────

  void _onReplySelect(MessageReplySelected event, Emitter<MessageState> emit) {
    final current = state;
    if (current is! MessageLoaded) return;
    emit(
      current.copyWith(
        replyingTo: event.message,
        clearReply: event.message == null,
      ),
    );
  }

  // ── Subscribe to realtime ──────────────────────────────────────────────────

  Future<void> _onSubscribe(
    MessageSubscribed event,
    Emitter<MessageState> emit,
  ) async {
    await _realtimeSub?.cancel();
    _realtimeSub = watchMessages(
      event.conversationId,
    ).listen((msg) => add(MessageRealtimeReceived(msg)), onError: (_) {});
  }

  void _onPresenceUpdated(
    MessagePresenceUpdated event,
    Emitter<MessageState> emit,
  ) {
    final current = state;

    if (current is! MessageLoaded) return;

    emit(
      current.copyWith(
        presenceData: event.presenceData,
        hasPresenceLoaded: true,
      ),
    );
  }

  Future<void> _onWatchPresence(
    MessageWatchPresenceRequested event,
    Emitter<MessageState> emit,
  ) async {
    await _presenceSub?.cancel();
    _presenceSub = watchUserPresence(
      event.userId,
    ).listen((data) => add(MessagePresenceUpdated(data)));
  }

  Future<void> _onSendImage(
    MessageSendImageRequested event,
    Emitter<MessageState> emit,
  ) async {
    final current = state;
    if (current is! MessageLoaded) return;

    // Optimistic bubble với local file
    final tempId = 'temp_img_${DateTime.now().millisecondsSinceEpoch}';
    final optimistic = MessageEntity(
      id: tempId,
      conversationId: current.conversationId,
      senderId: SupabaseService.currentUserId ?? '',
      sender: const _EmptyProfile(),
      type: MessageType.image,
      mediaUrl: event.localPath,
      // hiển thị local trước
      createdAt: DateTime.now(),
      isMine: true,
      isPending: true,
    );
    emit(current.copyWith(messages: [...current.messages, optimistic]));

    // Upload
    final uploadResult = await uploadMedia(event.file, folder: 'images');
    await uploadResult.fold(
      (f) async {
        final c = state;
        if (c is MessageLoaded) {
          emit(
            c.copyWith(
              messages: c.messages
                  .map(
                    (m) => m.id == tempId
                        ? m.copyWith(hasFailed: true, isPending: false)
                        : m,
                  )
                  .toList(),
            ),
          );
        }
      },
      (url) async {
        final sendResult = await sendMessage(
          conversationId: current.conversationId,
          content: null,
          type: MessageType.image,
          mediaUrl: url,
        );
        final c = state;
        if (c is MessageLoaded) {
          sendResult.fold(
            (_) => emit(
              c.copyWith(
                messages: c.messages
                    .map(
                      (m) => m.id == tempId
                          ? m.copyWith(hasFailed: true, isPending: false)
                          : m,
                    )
                    .toList(),
              ),
            ),
            (confirmed) => emit(
              c.copyWith(
                messages: c.messages
                    .map((m) => m.id == tempId ? confirmed : m)
                    .toList(),
              ),
            ),
          );
        }
      },
    );
  }

  // Dán hàm này vào trong MessageBloc, thay thế hoàn toàn _onSendAudio cũ.

  Future<void> _onSendAudio(
      MessageSendAudioRequested event,
      Emitter<MessageState> emit,
      ) async {
    final current = state;
    if (current is! MessageLoaded) return;

    // 1. Optimistic bubble với local path
    final tempId = 'temp_audio_${DateTime.now().millisecondsSinceEpoch}';
    final optimistic = MessageEntity(
      id: tempId,
      conversationId: current.conversationId,
      senderId: SupabaseService.currentUserId ?? '',
      sender: const _EmptyProfile(),
      type: MessageType.audio,
      content: event.localPath, // hiển thị local trước
      createdAt: DateTime.now(),
      isMine: true,
      isPending: true,
    );
    emit(current.copyWith(messages: [...current.messages, optimistic]));

    // 2. Upload file
    final file = File(event.localPath);
    final uploadResult = await uploadMedia(file, folder: 'audio');

    // Hàm helper để mark failed — tránh lặp code
    void markFailed() {
      final c = state;
      if (c is! MessageLoaded) return;
      emit(
        c.copyWith(
          messages: c.messages
              .map(
                (m) => m.id == tempId
                ? m.copyWith(hasFailed: true, isPending: false)
                : m,
          )
              .toList(),
        ),
      );
    }

    // 3. Xử lý kết quả upload
    if (uploadResult.isLeft()) {
      markFailed();
      return;
    }

    final url = uploadResult.getOrElse(() => '');

    // 4. Gửi message với URL từ server
    final sendResult = await sendMessage(
      conversationId: current.conversationId,
      content: null,
      type: MessageType.audio,
      mediaUrl: url,
    );

    final c = state;
    if (c is! MessageLoaded) return;

    sendResult.fold(
          (_) => markFailed(),
          (confirmed) => emit(
        c.copyWith(
          messages: c.messages.map((m) => m.id == tempId ? confirmed : m).toList(),
        ),
      ),
    );
  }

  @override
  Future<void> close() async {
    await _realtimeSub?.cancel();
    await _presenceSub?.cancel();
    return super.close();
  }
}

// ─── Placeholder profile (for optimistic messages) ───────────────────────────

class _EmptyProfile extends ProfileStub {
  const _EmptyProfile() : super(id: '', username: 'me', displayName: 'Me');
}
