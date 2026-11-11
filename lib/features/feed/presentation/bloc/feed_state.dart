import 'package:equatable/equatable.dart';
import 'package:shareco/features/feed/presentation/bloc/feed_event.dart';
import 'package:shareco/features/video/domain/entities/video_entity.dart';

abstract class FeedState extends Equatable {
  const FeedState();
  @override
  List<Object?> get props => [];
}

class FeedInitial extends FeedState {
  const FeedInitial();
}

class FeedLoading extends FeedState {
  const FeedLoading();
}

class FeedLoaded extends FeedState {
  final List<VideoEntity> forYouVideos;
  final bool forYouLoadingMore;
  final bool forYouHasReachedMax;
  final int forYouPage;
  final bool forYouInitialized;

  final List<VideoEntity> followingVideos;
  final bool followingLoadingMore;
  final bool followingHasReachedMax;
  final int followingPage;
  final bool followingInitialized;
  final bool isFollowingLoading;
  final String? followingError;

  final FeedTab activeTab;
  final String? pendingScrollToVideoId;

  const FeedLoaded({
    this.forYouVideos = const [],
    this.forYouLoadingMore = false,
    this.forYouHasReachedMax = false,
    this.forYouPage = 0,
    this.forYouInitialized = false,
    this.followingVideos = const [],
    this.followingLoadingMore = false,
    this.followingHasReachedMax = false,
    this.followingPage = 0,
    this.followingInitialized = false,
    this.isFollowingLoading = false,
    this.followingError,
    this.activeTab = FeedTab.forYou,
    this.pendingScrollToVideoId,
  });

  List<VideoEntity> get videos =>
      activeTab == FeedTab.following ? followingVideos : forYouVideos;

  bool get isLoadingMore =>
      activeTab == FeedTab.following ? followingLoadingMore : forYouLoadingMore;

  bool get hasReachedMax => activeTab == FeedTab.following
      ? followingHasReachedMax
      : forYouHasReachedMax;

  int get currentPage =>
      activeTab == FeedTab.following ? followingPage : forYouPage;

  FeedLoaded copyWith({
    List<VideoEntity>? forYouVideos,
    bool? forYouLoadingMore,
    bool? forYouHasReachedMax,
    int? forYouPage,
    bool? forYouInitialized,
    List<VideoEntity>? followingVideos,
    bool? followingLoadingMore,
    bool? followingHasReachedMax,
    int? followingPage,
    bool? followingInitialized,
    bool? isFollowingLoading,
    String? followingError,
    bool clearFollowingError = false,
    FeedTab? activeTab,
    String? pendingScrollToVideoId,
    bool clearPendingScroll = false,
  }) =>
      FeedLoaded(
        forYouVideos: forYouVideos ?? this.forYouVideos,
        forYouLoadingMore: forYouLoadingMore ?? this.forYouLoadingMore,
        forYouHasReachedMax: forYouHasReachedMax ?? this.forYouHasReachedMax,
        forYouPage: forYouPage ?? this.forYouPage,
        forYouInitialized: forYouInitialized ?? this.forYouInitialized,
        followingVideos: followingVideos ?? this.followingVideos,
        followingLoadingMore:
            followingLoadingMore ?? this.followingLoadingMore,
        followingHasReachedMax:
            followingHasReachedMax ?? this.followingHasReachedMax,
        followingPage: followingPage ?? this.followingPage,
        followingInitialized:
            followingInitialized ?? this.followingInitialized,
        isFollowingLoading: isFollowingLoading ?? this.isFollowingLoading,
        followingError: clearFollowingError
            ? null
            : (followingError ?? this.followingError),
        activeTab: activeTab ?? this.activeTab,
        pendingScrollToVideoId: clearPendingScroll
            ? null
            : (pendingScrollToVideoId ?? this.pendingScrollToVideoId),
      );

  @override
  List<Object?> get props => [
        forYouVideos,
        forYouLoadingMore,
        forYouHasReachedMax,
        forYouPage,
        forYouInitialized,
        followingVideos,
        followingLoadingMore,
        followingHasReachedMax,
        followingPage,
        followingInitialized,
        isFollowingLoading,
        followingError,
        activeTab,
        pendingScrollToVideoId,
      ];
}

class FeedError extends FeedState {
  final String message;
  const FeedError(this.message);
  @override
  List<Object?> get props => [message];
}
