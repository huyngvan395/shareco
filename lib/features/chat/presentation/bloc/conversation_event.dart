import 'package:equatable/equatable.dart';
import 'package:shareco/features/chat/domain/entities/chat_entities.dart';

abstract class ConversationEvent extends Equatable {
  const ConversationEvent();
  @override List<Object?> get props => [];
}

class ConversationListLoadRequested extends ConversationEvent {
  const ConversationListLoadRequested();
}

class ConversationRefreshRequested extends ConversationEvent {
  const ConversationRefreshRequested();
}

class ConversationOpenRequested extends ConversationEvent {
  final String otherUserId;
  const ConversationOpenRequested(this.otherUserId);
  @override List<Object?> get props => [otherUserId];
}

class ConversationSearchRequested extends ConversationEvent {
  final String query;
  const ConversationSearchRequested(this.query);
  @override List<Object?> get props => [query];
}

class ConversationSearchCleared extends ConversationEvent {
  const ConversationSearchCleared();
}

class ConversationUpdated extends ConversationEvent {
  final ConversationEntity conversation;
  const ConversationUpdated(this.conversation);
  @override List<Object?> get props => [conversation.id];
}