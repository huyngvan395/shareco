import 'package:equatable/equatable.dart';
import 'package:shareco/features/feed/presentation/bloc/feed_event.dart';
import 'package:shareco/features/video/domain/entities/video_entity.dart';

abstract class FeedState extends Equatable {
  const FeedState();
  @override List<Object?> get props => [];
}

class FeedInitial extends FeedState { const FeedInitial(); }
class FeedLoading extends FeedState { const FeedLoading(); }

class FeedLoaded extends FeedState {
  final List<VideoEntity> videos;
  final bool isLoadingMore;
  final bool hasReachedMax;
  final int currentPage;
  final FeedTab activeTab;
  final String? pendingScrollToVideoId;

  const FeedLoaded({
    required this.videos,
    this.isLoadingMore = false,
    this.hasReachedMax = false,
    this.currentPage = 0,
    this.activeTab = FeedTab.forYou,
    this.pendingScrollToVideoId,
  });

  FeedLoaded copyWith({
    List<VideoEntity>? videos,
    bool? isLoadingMore,
    bool? hasReachedMax,
    int? currentPage,
    FeedTab? activeTab,
    String? pendingScrollToVideoId,
    bool clearPendingScroll = false,
  }) =>
      FeedLoaded(
        videos: videos ?? this.videos,
        isLoadingMore: isLoadingMore ?? this.isLoadingMore,
        hasReachedMax: hasReachedMax ?? this.hasReachedMax,
        currentPage: currentPage ?? this.currentPage,
        activeTab: activeTab ?? this.activeTab,
        pendingScrollToVideoId:
        clearPendingScroll ? null : (pendingScrollToVideoId ?? this.pendingScrollToVideoId),
      );

  @override
  List<Object?> get props =>
      [videos, isLoadingMore, hasReachedMax, currentPage, activeTab, pendingScrollToVideoId];
}

class FeedError extends FeedState {
  final String message;
  const FeedError(this.message);
  @override List<Object?> get props => [message];
}