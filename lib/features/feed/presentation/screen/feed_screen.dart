// features/feed/presentation/screen/feed_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shareco/core/navigation/app_route_observer.dart';
import 'package:shareco/core/notifier/auth_notifier.dart';
import 'package:shareco/di/injector.dart';
import 'package:shareco/features/feed/presentation/bloc/feed_event.dart';
import 'package:shareco/features/feed/presentation/bloc/feed_state.dart';
import 'package:shareco/routes/app_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/video_controller_cache.dart';
import '../../../video/domain/entities/video_entity.dart';
import '../bloc/feed_bloc.dart';
import '../widgets/feed_topbar.dart';
import '../widgets/video_item.dart';

// ─── Feed Screen (Dual-Tab TikTok Engine: Đang theo dõi & Dành cho bạn) ───────

class FeedScreen extends StatefulWidget {
  final String? initialVideoId;
  const FeedScreen({super.key, this.initialVideoId});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> with WidgetsBindingObserver {
  final _cache = VideoControllerCache(maxControllers: 3);

  // Page 0 = Đang theo dõi (Following), Page 1 = Dành cho bạn (For You)
  late final PageController _tabPageCtrl = PageController(initialPage: 1);
  final PageController _forYouPageCtrl = PageController();
  final PageController _followingPageCtrl = PageController();

  int _forYouActivePage = 0;
  int _followingActivePage = 0;
  bool _hasScrolledToTarget = false;
  late final GoRouter _router;
  bool _routerListenerAdded = false;
  bool _isFeedVisible = true;
  bool _programmaticTabSwitch = false;
  Timer? _preloadDebounce;
  String? _lastAuthUserId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    routeObserver.addRouteListener(_onNavigationEvent);
    final auth = sl<AuthNotifier>();
    _lastAuthUserId = auth.userId;
    auth.addListener(_onAuthChanged);
    if (widget.initialVideoId != null) {
      context.read<FeedBloc>().add(
            FeedLoadToVideoRequested(widget.initialVideoId!),
          );
    } else {
      context.read<FeedBloc>().add(const FeedLoadRequested());
    }
  }

  void _onAuthChanged() {
    if (!mounted) return;
    final auth = sl<AuthNotifier>();
    if (_lastAuthUserId == auth.userId) return;
    _lastAuthUserId = auth.userId;
    _followingActivePage = 0;

    if (!auth.isAuthenticated &&
        _tabPageCtrl.hasClients &&
        _tabPageCtrl.page?.round() != 1) {
      _programmaticTabSwitch = true;
      _tabPageCtrl.jumpToPage(1);
      _programmaticTabSwitch = false;
    }

    context.read<FeedBloc>().add(
          FeedAuthChanged(isAuthenticated: auth.isAuthenticated),
        );
  }

  void _onNavigationEvent() {
    if (!mounted) return;
    if (!_routerListenerAdded) {
      if (routeObserver.hasOverlayRoute) {
        _setFeedVisible(false);
      }
      return;
    }
    final isFeed = _isCurrentFeedRoute();
    _setFeedVisible(isFeed);
  }

  @override
  void dispose() {
    _preloadDebounce?.cancel();
    sl<AuthNotifier>().removeListener(_onAuthChanged);
    WidgetsBinding.instance.removeObserver(this);
    routeObserver.removeRouteListener(_onNavigationEvent);
    if (_routerListenerAdded) {
      _router.routerDelegate.removeListener(_onRouteChanged);
    }
    _tabPageCtrl.dispose();
    _forYouPageCtrl.dispose();
    _followingPageCtrl.dispose();
    _cache.disposeAll();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _setFeedVisible(false);
    } else if (state == AppLifecycleState.resumed &&
        _routerListenerAdded &&
        _isCurrentFeedRoute()) {
      _setFeedVisible(true);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (!_routerListenerAdded) {
      _router = GoRouter.of(context);
      _router.routerDelegate.addListener(_onRouteChanged);
      _routerListenerAdded = true;
    }
  }

  void _onRouteChanged() {
    final isFeedRoute = _isCurrentFeedRoute();
    _setFeedVisible(isFeedRoute);
  }

  bool _isCurrentFeedRoute() {
    if (routeObserver.hasOverlayRoute) return false;

    final config = _router.routerDelegate.currentConfiguration;
    final uri = config.uri;
    return uri.path == Routes.feed;
  }

  void _setFeedVisible(bool visible) {
    if (!mounted) return;

    if (!visible) {
      _preloadDebounce?.cancel();
      _cache.pauseAll();
      _cache.evictIdle();
    }

    if (_isFeedVisible != visible) {
      setState(() => _isFeedVisible = visible);
    } else if (visible) {
      setState(() {});
    }
  }

  void _onSelectTabFromTopBar(FeedTab tab) {
    _preloadDebounce?.cancel();
    _cache.pauseAll();

    final targetIndex = tab == FeedTab.following ? 0 : 1;
    context.read<FeedBloc>().add(FeedTabChanged(tab));

    if (_tabPageCtrl.hasClients &&
        _tabPageCtrl.page?.round() != targetIndex) {
      _programmaticTabSwitch = true;
      _tabPageCtrl
          .animateToPage(
            targetIndex,
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
          )
          .whenComplete(() {
            _programmaticTabSwitch = false;
          });
    }
  }

  void _onHorizontalTabSwiped(int index) {
    _preloadDebounce?.cancel();
    _cache.pauseAll();
    if (_programmaticTabSwitch) return;

    final nextTab = index == 0 ? FeedTab.following : FeedTab.forYou;
    final curr = context.read<FeedBloc>().state;
    if (curr is! FeedLoaded || curr.activeTab != nextTab) {
      context.read<FeedBloc>().add(FeedTabChanged(nextTab));
    }
  }

  void _onVerticalPageChanged({
    required FeedTab tab,
    required int page,
    required List<VideoEntity> videos,
  }) {
    _cache.pauseAll();
    setState(() {
      if (tab == FeedTab.following) {
        _followingActivePage = page;
      } else {
        _forYouActivePage = page;
      }
    });

    // Chờ lướt dừng 180ms mới preload 1 video kế tiếp để chống nghẽn bộ giải mã khi vuốt nhanh
    _preloadDebounce?.cancel();
    _preloadDebounce = Timer(const Duration(milliseconds: 180), () {
      if (!mounted || !_isFeedVisible) return;
      final nextIdx = page + 1;
      if (nextIdx >= 0 && nextIdx < videos.length) {
        _cache.preload(videos[nextIdx].videoPath);
      }
    });

    if (page >= videos.length - 3) {
      context.read<FeedBloc>().add(const FeedLoadMoreRequested());
    }
  }

  void _handlePendingScroll(FeedLoaded state) {
    if (state.pendingScrollToVideoId == null || _hasScrolledToTarget) return;
    final idx = state.forYouVideos.indexWhere(
      (v) => v.id == state.pendingScrollToVideoId,
    );
    if (idx == -1) return;
    _hasScrolledToTarget = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_forYouPageCtrl.hasClients) {
        _forYouPageCtrl.jumpToPage(idx);
        setState(() => _forYouActivePage = idx);
      }
    });
  }

  Future<void> _onRefresh() async {
    _hasScrolledToTarget = false;
    _cache.pauseAll();
    context.read<FeedBloc>().add(const FeedRefreshRequested());
    await Future.delayed(const Duration(milliseconds: 550));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          BlocConsumer<FeedBloc, FeedState>(
            listener: (_, state) {
              if (state is FeedLoaded) {
                if (state.pendingScrollToVideoId != null) {
                  _handlePendingScroll(state);
                }
                final expectedIdx =
                    state.activeTab == FeedTab.following ? 0 : 1;
                if (_tabPageCtrl.hasClients &&
                    !_programmaticTabSwitch &&
                    _tabPageCtrl.page?.round() != expectedIdx) {
                  _tabPageCtrl.jumpToPage(expectedIdx);
                }
              }
            },
            builder: (_, state) {
              if (state is FeedLoading) return _buildShimmer();
              if (state is FeedError) return _buildError(state.message);
              if (state is FeedLoaded) return _buildDualTabPager(state);
              return const SizedBox.shrink();
            },
          ),
          BlocBuilder<FeedBloc, FeedState>(
            buildWhen: (prev, curr) {
              final pTab =
                  prev is FeedLoaded ? prev.activeTab : FeedTab.forYou;
              final cTab =
                  curr is FeedLoaded ? curr.activeTab : FeedTab.forYou;
              return pTab != cTab;
            },
            builder: (_, state) => FeedTopBar(
              activeTab: state is FeedLoaded ? state.activeTab : FeedTab.forYou,
              onTabChanged: _onSelectTabFromTopBar,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDualTabPager(FeedLoaded state) {
    return PageView(
      controller: _tabPageCtrl,
      onPageChanged: _onHorizontalTabSwiped,
      children: [
        // Tab 0: Đang theo dõi (Following)
        _FeedTabKeepAlivePane(
          key: const PageStorageKey('feed_tab_following'),
          child: _buildFollowingTab(state),
        ),
        // Tab 1: Dành cho bạn (For You)
        _FeedTabKeepAlivePane(
          key: const PageStorageKey('feed_tab_foryou'),
          child: _buildVerticalVideoList(
            tab: FeedTab.forYou,
            state: state,
            videos: state.forYouVideos,
            isLoadingMore: state.forYouLoadingMore,
            pageController: _forYouPageCtrl,
            activePage: _forYouActivePage,
          ),
        ),
      ],
    );
  }

  Widget _buildFollowingTab(FeedLoaded state) {
    if (state.isFollowingLoading && state.followingVideos.isEmpty) {
      return _buildShimmer();
    }
    if (state.followingError != null && state.followingVideos.isEmpty) {
      return _buildError(
        state.followingError!,
        onRetry: () =>
            context.read<FeedBloc>().add(const FeedFollowingLoadRequested()),
      );
    }
    return _buildVerticalVideoList(
      tab: FeedTab.following,
      state: state,
      videos: state.followingVideos,
      isLoadingMore: state.followingLoadingMore,
      pageController: _followingPageCtrl,
      activePage: _followingActivePage,
    );
  }

  Widget _buildVerticalVideoList({
    required FeedTab tab,
    required FeedLoaded state,
    required List<VideoEntity> videos,
    required bool isLoadingMore,
    required PageController pageController,
    required int activePage,
  }) {
    final isTabSelected = state.activeTab == tab;

    if (videos.isEmpty) {
      return RefreshIndicator(
        onRefresh: _onRefresh,
        color: AppColors.primary,
        backgroundColor: AppColors.surfaceCard,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.85,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.06),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.videocam_off_outlined,
                          color: Colors.white38,
                          size: 34,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        tab == FeedTab.following
                            ? 'Chưa có video từ người đang theo dõi'
                            : 'Chưa có video nào',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (tab == FeedTab.following) ...[
                        const SizedBox(height: 8),
                        const Text(
                          'Hãy theo dõi các nhà sáng tạo để xem video mới nhất của họ tại đây.',
                          style: TextStyle(color: Colors.white38, fontSize: 13),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    final safeActivePage = activePage >= videos.length ? 0 : activePage;

    return RefreshIndicator(
      onRefresh: _onRefresh,
      color: AppColors.primary,
      backgroundColor: AppColors.surfaceCard,
      child: PageView.builder(
        controller: pageController,
        scrollDirection: Axis.vertical,
        itemCount: videos.length + (isLoadingMore ? 1 : 0),
        onPageChanged: (page) => _onVerticalPageChanged(
          tab: tab,
          page: page,
          videos: videos,
        ),
        itemBuilder: (_, i) {
          if (i >= videos.length) {
            return const Center(
              child: CircularProgressIndicator(
                color: AppColors.primary,
                strokeWidth: 2,
              ),
            );
          }
          final video = videos[i];
          final isCurrentItem =
              _isFeedVisible && isTabSelected && i == safeActivePage;
          final isAdjacentInActiveTab =
              _isFeedVisible && isTabSelected && (i - safeActivePage).abs() <= 1;

          return VideoItem(
            key: ValueKey('${tab.name}_${video.id}'),
            video: video,
            cache: _cache,
            isActive: isCurrentItem,
            shouldPrepare: isAdjacentInActiveTab,
          );
        },
      ),
    );
  }

  Widget _buildShimmer() => Container(
        color: Colors.black,
        child: const Center(
          child: CircularProgressIndicator(
            color: AppColors.primary,
            strokeWidth: 2,
          ),
        ),
      );

  Widget _buildError(String msg, {VoidCallback? onRetry}) => Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.wifi_off_rounded, color: Colors.white38, size: 48),
              const SizedBox(height: 16),
              Text(
                msg,
                style: const TextStyle(color: Colors.white54),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: onRetry ??
                    () => context
                        .read<FeedBloc>()
                        .add(const FeedLoadRequested()),
                child: const Text(
                  'Thử lại',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
}

class _FeedTabKeepAlivePane extends StatefulWidget {
  final Widget child;
  const _FeedTabKeepAlivePane({super.key, required this.child});

  @override
  State<_FeedTabKeepAlivePane> createState() => _FeedTabKeepAlivePaneState();
}

class _FeedTabKeepAlivePaneState extends State<_FeedTabKeepAlivePane>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
