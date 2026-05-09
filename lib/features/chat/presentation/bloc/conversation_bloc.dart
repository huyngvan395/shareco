import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shareco/features/chat/domain/usecases/chat_usecases.dart';
import 'package:shareco/features/chat/presentation/bloc/conversation_event.dart';
import 'package:shareco/features/chat/presentation/bloc/conversation_state.dart';

class ConversationBloc extends Bloc<ConversationEvent, ConversationState> {
  final GetConversationsUseCase getConversations;
  final GetOrCreateConversationUseCase getOrCreateConversation;
  final SearchUsersUseCase searchUsers;

  ConversationBloc({
    required this.getConversations,
    required this.getOrCreateConversation,
    required this.searchUsers,
  }) : super(const ConversationInitial()) {
    on<ConversationListLoadRequested>(_onLoad);
    on<ConversationRefreshRequested>(_onRefresh);
    on<ConversationOpenRequested>(_onOpen);
    on<ConversationSearchRequested>(_onSearch);
    on<ConversationSearchCleared>(_onSearchClear);
    on<ConversationUpdated>(_onUpdated);
  }

  Future<void> _onLoad(
      ConversationListLoadRequested _, Emitter<ConversationState> emit) async {
    emit(const ConversationLoading());
    final r = await getConversations();
    r.fold(
          (f) => emit(ConversationError(f.message)),
          (list) => emit(ConversationListLoaded(conversations: list)),
    );
  }

  Future<void> _onRefresh(
      ConversationRefreshRequested _, Emitter<ConversationState> emit) async {
    final r = await getConversations();
    r.fold(
          (_) {},
          (list) {
        final current = state;
        if (current is ConversationListLoaded) {
          emit(current.copyWith(conversations: list));
        } else {
          emit(ConversationListLoaded(conversations: list));
        }
      },
    );
  }

  Future<void> _onOpen(
      ConversationOpenRequested event, Emitter<ConversationState> emit) async {
    final r = await getOrCreateConversation(event.otherUserId);
    r.fold(
          (f) => emit(ConversationError(f.message)),
          (conv) => emit(ConversationNavigateTo(conv)),
    );
    // Restore list state after navigation
    final current = state;
    if (current is! ConversationListLoaded) {
      add(const ConversationListLoadRequested());
    }
  }

  Future<void> _onSearch(
      ConversationSearchRequested event, Emitter<ConversationState> emit) async {
    final current = state;
    if (current is! ConversationListLoaded) return;

    emit(current.copyWith(
      isSearching: true,
      searchQuery: event.query,
      searchResults: [],
    ));

    if (event.query.trim().isEmpty) {
      emit(current.copyWith(
          isSearching: true, searchQuery: '', searchResults: []));
      return;
    }

    final r = await searchUsers(event.query);
    r.fold(
          (_) {},
          (users) {
        final c = state;
        if (c is ConversationListLoaded) {
          emit(c.copyWith(searchResults: users));
        }
      },
    );
  }

  void _onSearchClear(
      ConversationSearchCleared _, Emitter<ConversationState> emit) {
    final current = state;
    if (current is ConversationListLoaded) {
      emit(current.copyWith(
          isSearching: false, searchQuery: '', searchResults: []));
    }
  }

  void _onUpdated(
      ConversationUpdated event, Emitter<ConversationState> emit) {
    final current = state;
    if (current is! ConversationListLoaded) return;
    final updated = current.conversations.map((c) {
      return c.id == event.conversation.id ? event.conversation : c;
    }).toList();
    updated.sort((a, b) {
      final aTime = a.lastMessageAt ?? a.updatedAt;
      final bTime = b.lastMessageAt ?? b.updatedAt;
      return bTime.compareTo(aTime);
    });
    emit(current.copyWith(conversations: updated));
  }
}