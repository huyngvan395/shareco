import 'package:equatable/equatable.dart';

abstract class FeedEvent extends Equatable {
  const FeedEvent();
  @override
  List<Object?> get props => [];
}

class FeedLoadRequested extends FeedEvent {
  const FeedLoadRequested();
}

class FeedFollowingLoadRequested extends FeedEvent{
  const FeedFollowingLoadRequested();
}

class FeedRefreshRequested extends FeedEvent{
  const FeedRefreshRequested();
}

class FeedLoadMoreRequested extends FeedEvent{
  const FeedLoadMoreRequested();
}

class FeedLoadToVideoRequested extends FeedEvent{
  final String videoId;
  const FeedLoadToVideoRequested(this.videoId);
  @override
  List<Object?> get props => [videoId];
}

class FeedVideoLikeToggled extends FeedEvent{
  final String videoId;
  const FeedVideoLikeToggled(this.videoId);
  @override
  List<Object?> get props => [videoId];
}

class FeedTabChanged extends FeedEvent {
  final FeedTab tab;
  const FeedTabChanged(this.tab);
  @override List<Object?> get props => [tab];
}

class FeedCommentChanged extends FeedEvent {
  final String videoId;
  final int delta; // +1 khi comment, -1 khi xoá

  const FeedCommentChanged({
    required this.videoId,
    this.delta = 1,
  });

  @override
  List<Object?> get props => [videoId, delta];
}

enum FeedTab { forYou, following }



