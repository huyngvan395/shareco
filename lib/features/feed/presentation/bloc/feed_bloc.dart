// features/feed/presentation/bloc/feed_bloc.dart

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shareco/features/feed/presentation/bloc/feed_event.dart';
import 'package:shareco/features/feed/presentation/bloc/feed_state.dart';
import '../../../video/domain/entities/video_entity.dart';
import '../../../video/domain/usecases/video_usecases.dart';
import '../../../../shared/domain/entities/base_entity.dart';

// ─── BLoC ─────────────────────────────────────────────────────────────────────

class FeedBloc extends Bloc<FeedEvent, FeedState> {
  final GetForYouFeedUseCase getForYouFeed;
  final GetFollowingFeedUseCase getFollowingFeed;
  final ToggleVideoLikeUseCase toggleVideoLike;
  final IncrementVideoViewUseCase incrementView;

  static const _maxDeepLinkPages = 5;

  FeedBloc({
    required this.getForYouFeed,
    required this.getFollowingFeed,
    required this.toggleVideoLike,
    required this.incrementView,
  }) : super(const FeedInitial()) {
    on<FeedLoadRequested>(_onLoad);
    on<FeedFollowingLoadRequested>(_onLoadFollowing);
    on<FeedTabChanged>(_onTabChanged);
    on<FeedLoadToVideoRequested>(_onLoadToVideo);
    on<FeedRefreshRequested>(_onRefresh);
    on<FeedLoadMoreRequested>(_onLoadMore);
    on<FeedVideoLikeToggled>(_onToggleLike);
    on<FeedCommentChanged>(_onCommentChanged);
  }

  Future<void> _onLoad(FeedLoadRequested _, Emitter<FeedState> emit) async {
    emit(const FeedLoading());
    final r = await getForYouFeed(page: 0);
    r.fold((f) => emit(FeedError(f.message)),
            (p) => emit(FeedLoaded(videos: p.items)));
  }

  Future<void> _onLoadFollowing(
      FeedFollowingLoadRequested _, Emitter<FeedState> emit) async {
    emit(const FeedLoading());
    final r = await getFollowingFeed(page: 0);
    r.fold((f) => emit(FeedError(f.message)),
            (p) => emit(FeedLoaded(videos: p.items, activeTab: FeedTab.following)));
  }

  Future<void> _onTabChanged(
      FeedTabChanged event, Emitter<FeedState> emit) async {
    if (event.tab == FeedTab.following) {
      add(const FeedFollowingLoadRequested());
    } else {
      add(const FeedLoadRequested());
    }
  }

  Future<void> _onLoadToVideo(
      FeedLoadToVideoRequested event, Emitter<FeedState> emit) async {
    emit(const FeedLoading());
    var all = <VideoEntity>[];
    var page = 0;
    var found = false;
    while (page <= _maxDeepLinkPages) {
      final r = await getForYouFeed(page: page);
      if (r.isLeft()) { r.fold((f) => emit(FeedError(f.message)), (_) {}); return; }
      final p = r.getOrElse(() => PaginatedResult(items: [], page: 0, limit: 0, hasMore: false));
      all = [...all, ...p.items];
      if (all.any((v) => v.id == event.videoId)) { found = true; break; }
      if (!p.hasMore) break;
      page++;
    }
    emit(FeedLoaded(
      videos: all,
      currentPage: page,
      pendingScrollToVideoId: found ? event.videoId : null,
    ));
  }

  Future<void> _onRefresh(FeedRefreshRequested _, Emitter<FeedState> emit) async {
    final current = state;
    final tab = current is FeedLoaded ? current.activeTab : FeedTab.forYou;
    final r = tab == FeedTab.following
        ? await getFollowingFeed(page: 0)
        : await getForYouFeed(page: 0);
    r.fold((_) {}, (p) => emit(FeedLoaded(videos: p.items, activeTab: tab)));
  }

  Future<void> _onLoadMore(FeedLoadMoreRequested _, Emitter<FeedState> emit) async {
    final current = state;
    if (current is! FeedLoaded) return;
    if (current.isLoadingMore || current.hasReachedMax) return;
    emit(current.copyWith(isLoadingMore: true));
    final next = current.currentPage + 1;
    final r = current.activeTab == FeedTab.following
        ? await getFollowingFeed(page: next)
        : await getForYouFeed(page: next);
    r.fold(
          (_) => emit(current.copyWith(isLoadingMore: false)),
          (p) => p.isEmpty
          ? emit(current.copyWith(isLoadingMore: false, hasReachedMax: true))
          : emit(current.copyWith(
        videos: [...current.videos, ...p.items],
        isLoadingMore: false,
        currentPage: next,
      )),
    );
  }

  Future<void> _onToggleLike(
      FeedVideoLikeToggled event, Emitter<FeedState> emit) async {
    final current = state;
    if (current is! FeedLoaded) return;
    // Optimistic update
    emit(current.copyWith(
      videos: current.videos.map((v) {
        if (v.id != event.videoId) return v;
        return v.copyWith(
          isLiked: !v.isLiked,
          likeCount: v.isLiked ? v.likeCount - 1 : v.likeCount + 1,
        );
      }).toList(),
    ));
    final result = await toggleVideoLike(event.videoId);
    result.fold((_) => emit(current), (_) {});
  }

  Future<void> _onCommentChanged(
      FeedCommentChanged event,
      Emitter<FeedState> emit,
      ) async {
    final current = state;
    if (current is! FeedLoaded) return;

    final updatedVideos = current.videos.map((v) {
      if (v.id != event.videoId) return v;

      return v.copyWith(
        commentCount: v.commentCount + event.delta,
      );
    }).toList();

    emit(current.copyWith(videos: updatedVideos));
  }
}