// features/feed/presentation/bloc/feed_bloc.dart

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
    on<FeedAuthChanged>(_onAuthChanged);
  }

  Future<void> _onAuthChanged(
    FeedAuthChanged event,
    Emitter<FeedState> emit,
  ) async {
    final current = state;
    if (current is FeedLoaded) {
      // Xoá danh sách Đang theo dõi của phiên trước; nếu vừa đăng xuất thì chuyển về Dành cho bạn
      final nextTab = event.isAuthenticated ? current.activeTab : FeedTab.forYou;
      emit(
        current.copyWith(
          activeTab: nextTab,
          followingVideos: const [],
          followingPage: 0,
          followingHasReachedMax: false,
          followingLoadingMore: false,
          followingInitialized: false,
          isFollowingLoading: false,
          clearFollowingError: true,
          forYouVideos: !event.isAuthenticated
              ? current.forYouVideos
                    .map((v) => v.isLiked ? v.copyWith(isLiked: false) : v)
                    .toList()
              : current.forYouVideos,
        ),
      );

      final r = await getForYouFeed(page: 0);
      r.fold((_) {}, (p) {
        final latest = state;
        if (latest is FeedLoaded) {
          emit(
            latest.copyWith(
              forYouVideos: p.items,
              forYouPage: 0,
              forYouHasReachedMax: !p.hasMore,
              forYouInitialized: true,
            ),
          );
        }
      });

      if (event.isAuthenticated && nextTab == FeedTab.following) {
        add(const FeedFollowingLoadRequested());
      }
    } else {
      add(const FeedLoadRequested());
    }
  }

  Future<void> _onLoad(FeedLoadRequested _, Emitter<FeedState> emit) async {
    final prev = state;
    if (prev is! FeedLoaded) {
      emit(const FeedLoading());
    }
    final r = await getForYouFeed(page: 0);
    r.fold(
      (f) {
        if (state is! FeedLoaded) {
          emit(FeedError(f.message));
        }
      },
      (p) {
        final curr = state;
        if (curr is FeedLoaded) {
          emit(
            curr.copyWith(
              forYouVideos: p.items,
              forYouPage: 0,
              forYouHasReachedMax: !p.hasMore,
              forYouLoadingMore: false,
              forYouInitialized: true,
            ),
          );
        } else {
          emit(
            FeedLoaded(
              forYouVideos: p.items,
              forYouPage: 0,
              forYouHasReachedMax: !p.hasMore,
              forYouInitialized: true,
              activeTab: FeedTab.forYou,
            ),
          );
        }
      },
    );
  }

  Future<void> _onLoadFollowing(
    FeedFollowingLoadRequested _,
    Emitter<FeedState> emit,
  ) async {
    final prev = state;
    if (prev is FeedLoaded) {
      emit(
        prev.copyWith(
          isFollowingLoading: true,
          clearFollowingError: true,
        ),
      );
    } else {
      emit(
        const FeedLoaded(
          activeTab: FeedTab.following,
          isFollowingLoading: true,
        ),
      );
    }

    final r = await getFollowingFeed(page: 0);
    final curr = state;
    r.fold(
      (f) {
        if (curr is FeedLoaded) {
          emit(
            curr.copyWith(
              isFollowingLoading: false,
              followingInitialized: true,
              followingError: f.message,
            ),
          );
        } else {
          emit(FeedError(f.message));
        }
      },
      (p) {
        final base = state is FeedLoaded
            ? (state as FeedLoaded)
            : const FeedLoaded(activeTab: FeedTab.following);
        emit(
          base.copyWith(
            followingVideos: p.items,
            followingPage: 0,
            followingHasReachedMax: !p.hasMore,
            followingLoadingMore: false,
            followingInitialized: true,
            isFollowingLoading: false,
            clearFollowingError: true,
          ),
        );
      },
    );
  }

  Future<void> _onTabChanged(
    FeedTabChanged event,
    Emitter<FeedState> emit,
  ) async {
    final current = state;
    if (current is FeedLoaded) {
      if (current.activeTab == event.tab) {
        add(const FeedRefreshRequested());
        return;
      }

      emit(current.copyWith(activeTab: event.tab));

      if (event.tab == FeedTab.following &&
          !current.followingInitialized &&
          !current.isFollowingLoading) {
        add(const FeedFollowingLoadRequested());
      } else if (event.tab == FeedTab.forYou && !current.forYouInitialized) {
        add(const FeedLoadRequested());
      }
    } else {
      if (event.tab == FeedTab.following) {
        add(const FeedFollowingLoadRequested());
      } else {
        add(const FeedLoadRequested());
      }
    }
  }

  Future<void> _onLoadToVideo(
    FeedLoadToVideoRequested event,
    Emitter<FeedState> emit,
  ) async {
    emit(const FeedLoading());
    var all = <VideoEntity>[];
    var page = 0;
    var found = false;
    while (page <= _maxDeepLinkPages) {
      final r = await getForYouFeed(page: page);
      if (r.isLeft()) {
        r.fold((f) => emit(FeedError(f.message)), (_) {});
        return;
      }
      final p = r.getOrElse(
        () => PaginatedResult(items: [], page: 0, limit: 0, hasMore: false),
      );
      all = [...all, ...p.items];
      if (all.any((v) => v.id == event.videoId)) {
        found = true;
        break;
      }
      if (!p.hasMore) break;
      page++;
    }
    emit(
      FeedLoaded(
        forYouVideos: all,
        forYouPage: page,
        forYouInitialized: true,
        activeTab: FeedTab.forYou,
        pendingScrollToVideoId: found ? event.videoId : null,
      ),
    );
  }

  Future<void> _onRefresh(
    FeedRefreshRequested _,
    Emitter<FeedState> emit,
  ) async {
    final current = state;
    final tab = current is FeedLoaded ? current.activeTab : FeedTab.forYou;
    if (tab == FeedTab.following) {
      final r = await getFollowingFeed(page: 0);
      r.fold((_) {}, (p) {
        final base = state is FeedLoaded
            ? (state as FeedLoaded)
            : const FeedLoaded(activeTab: FeedTab.following);
        emit(
          base.copyWith(
            followingVideos: p.items,
            followingPage: 0,
            followingHasReachedMax: !p.hasMore,
            followingInitialized: true,
            isFollowingLoading: false,
            clearFollowingError: true,
          ),
        );
      });
    } else {
      final r = await getForYouFeed(page: 0);
      r.fold((_) {}, (p) {
        final base = state is FeedLoaded
            ? (state as FeedLoaded)
            : const FeedLoaded(activeTab: FeedTab.forYou);
        emit(
          base.copyWith(
            forYouVideos: p.items,
            forYouPage: 0,
            forYouHasReachedMax: !p.hasMore,
            forYouInitialized: true,
          ),
        );
      });
    }
  }

  Future<void> _onLoadMore(
    FeedLoadMoreRequested _,
    Emitter<FeedState> emit,
  ) async {
    final current = state;
    if (current is! FeedLoaded) return;

    if (current.activeTab == FeedTab.following) {
      if (current.followingLoadingMore || current.followingHasReachedMax) {
        return;
      }
      emit(current.copyWith(followingLoadingMore: true));
      final next = current.followingPage + 1;
      final r = await getFollowingFeed(page: next);
      final latest = state;
      if (latest is! FeedLoaded) return;

      r.fold(
        (_) => emit(latest.copyWith(followingLoadingMore: false)),
        (p) => p.isEmpty
            ? emit(
                latest.copyWith(
                  followingLoadingMore: false,
                  followingHasReachedMax: true,
                ),
              )
            : emit(
                latest.copyWith(
                  followingVideos: [...latest.followingVideos, ...p.items],
                  followingLoadingMore: false,
                  followingPage: next,
                  followingHasReachedMax: !p.hasMore,
                ),
              ),
      );
    } else {
      if (current.forYouLoadingMore || current.forYouHasReachedMax) return;
      emit(current.copyWith(forYouLoadingMore: true));
      final next = current.forYouPage + 1;
      final r = await getForYouFeed(page: next);
      final latest = state;
      if (latest is! FeedLoaded) return;

      r.fold(
        (_) => emit(latest.copyWith(forYouLoadingMore: false)),
        (p) => p.isEmpty
            ? emit(
                latest.copyWith(
                  forYouLoadingMore: false,
                  forYouHasReachedMax: true,
                ),
              )
            : emit(
                latest.copyWith(
                  forYouVideos: [...latest.forYouVideos, ...p.items],
                  forYouLoadingMore: false,
                  forYouPage: next,
                  forYouHasReachedMax: !p.hasMore,
                ),
              ),
      );
    }
  }

  List<VideoEntity> _mapToggleLike(List<VideoEntity> list, String videoId) {
    return list.map((v) {
      if (v.id != videoId) return v;
      return v.copyWith(
        isLiked: !v.isLiked,
        likeCount: v.isLiked ? v.likeCount - 1 : v.likeCount + 1,
      );
    }).toList();
  }

  Future<void> _onToggleLike(
    FeedVideoLikeToggled event,
    Emitter<FeedState> emit,
  ) async {
    final current = state;
    if (current is! FeedLoaded) return;

    emit(
      current.copyWith(
        forYouVideos: _mapToggleLike(current.forYouVideos, event.videoId),
        followingVideos:
            _mapToggleLike(current.followingVideos, event.videoId),
      ),
    );
    final result = await toggleVideoLike(event.videoId);
    result.fold((_) => emit(current), (_) {});
  }

  List<VideoEntity> _mapCommentDelta(
    List<VideoEntity> list,
    String videoId,
    int delta,
  ) {
    return list.map((v) {
      if (v.id != videoId) return v;
      final nextCount = v.commentCount + delta;
      return v.copyWith(commentCount: nextCount < 0 ? 0 : nextCount);
    }).toList();
  }

  Future<void> _onCommentChanged(
    FeedCommentChanged event,
    Emitter<FeedState> emit,
  ) async {
    final current = state;
    if (current is! FeedLoaded) return;

    emit(
      current.copyWith(
        forYouVideos: _mapCommentDelta(
          current.forYouVideos,
          event.videoId,
          event.delta,
        ),
        followingVideos: _mapCommentDelta(
          current.followingVideos,
          event.videoId,
          event.delta,
        ),
      ),
    );
  }
}
