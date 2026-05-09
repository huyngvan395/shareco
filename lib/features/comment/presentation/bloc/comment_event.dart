import 'package:equatable/equatable.dart';

abstract class CommentEvent extends Equatable {
  const CommentEvent();
  @override List<Object?> get props => [];
}

class CommentLoadRequested extends CommentEvent {
  final String videoId;
  const CommentLoadRequested(this.videoId);
  @override List<Object?> get props => [videoId];
}

class CommentLoadMoreRequested extends CommentEvent {
  const CommentLoadMoreRequested();
}

class CommentPostRequested extends CommentEvent {
  final String content;
  final String? parentId;
  const CommentPostRequested({required this.content, this.parentId});
  @override List<Object?> get props => [content, parentId];
}

class CommentDeleteRequested extends CommentEvent {
  final String commentId;
  const CommentDeleteRequested(this.commentId);
  @override List<Object?> get props => [commentId];
}

class CommentRepliesLoadRequested extends CommentEvent {
  final String parentId;
  const CommentRepliesLoadRequested(this.parentId);
  @override List<Object?> get props => [parentId];
}