import 'package:equatable/equatable.dart';
import 'package:shareco/features/chat/domain/entities/chat_entities.dart';
import 'package:shareco/shared/domain/entities/base_entity.dart';

abstract class ConversationState extends Equatable {
  const ConversationState();
  @override List<Object?> get props => [];
}

class ConversationInitial extends ConversationState {
  const ConversationInitial();
}

class ConversationLoading extends ConversationState {
  const ConversationLoading();
}

class ConversationListLoaded extends ConversationState {
  final List<ConversationEntity> conversations;
  final List<ProfileStub> searchResults;
  final bool isSearching;
  final String searchQuery;

  const ConversationListLoaded({
    required this.conversations,
    this.searchResults = const [],
    this.isSearching = false,
    this.searchQuery = '',
  });

  int get unreadCount =>
      conversations.where((c) => c.hasUnread).length;

  ConversationListLoaded copyWith({
    List<ConversationEntity>? conversations,
    List<ProfileStub>? searchResults,
    bool? isSearching,
    String? searchQuery,
  }) =>
      ConversationListLoaded(
        conversations: conversations ?? this.conversations,
        searchResults: searchResults ?? this.searchResults,
        isSearching: isSearching ?? this.isSearching,
        searchQuery: searchQuery ?? this.searchQuery,
      );

  @override
  List<Object?> get props =>
      [conversations, searchResults, isSearching, searchQuery];
}

class ConversationNavigateTo extends ConversationState {
  final ConversationEntity conversation;
  const ConversationNavigateTo(this.conversation);
  @override List<Object?> get props => [conversation.id];
}

class ConversationError extends ConversationState {
  final String message;
  const ConversationError(this.message);
  @override List<Object?> get props => [message];
}