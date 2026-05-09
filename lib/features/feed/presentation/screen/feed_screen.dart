// features/feed/presentation/screen/feed_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shareco/features/feed/presentation/bloc/feed_event.dart';
import 'package:shareco/features/feed/presentation/bloc/feed_state.dart';
import 'package:video_player/video_player.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/storage_image.dart';
import '../../../video/domain/entities/video_entity.dart';
import '../bloc/feed_bloc.dart';
import '../widgets/feed_topbar.dart';
import '../widgets/video_item.dart';

// ─── Video Controller Cache ────────────────────────────────────────────────────

class _VideoCache {
  final Map<String, VideoPlayerController> _cache = {};
  final Map<String, Future<VideoPlayerController>> _pending = {};
  static const _max = 5;

  Future<VideoPlayerController> getOrCreate(String path) async {
    final url = StorageImage.videoUrl(path);
    if (_cache.containsKey(url)) return _cache[url]!;
    if (_pending.containsKey(url)) return _pending[url]!;

    final future = _create(url);
    _pending[url] = future;
    return future;
  }

  Future<VideoPlayerController> _create(String url) async {
    if (_cache.length >= _max) {
      final old = _cache.keys.first;
      await _cache[old]?.dispose();
      _cache.remove(old);
    }
    final ctrl = VideoPlayerController.networkUrl(
      Uri.parse(url),
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    );
    await ctrl.initialize();
    ctrl.setLooping(true);
    _cache[url] = ctrl;
    _pending.remove(url);
    return ctrl;
  }

  void pauseAll() {
    for (final c in _cache.values) {
      c.pause();
    }
  }

  Future<void> disposeAll() async {
    for (final c in _cache.values) {
      await c.dispose();
    }
    _cache.clear();
    _pending.clear();
  }
}

// ─── Feed Screen ──────────────────────────────────────────────────────────────

class FeedScreen extends StatefulWidget {
  final String? initialVideoId;
  const FeedScreen({super.key, this.initialVideoId});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  final _cache = _VideoCache();
  final _pageCtrl = PageController();
  int _activePage = 0;
  bool _hasScrolledToTarget = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialVideoId != null) {
      context.read<FeedBloc>().add(
        FeedLoadToVideoRequested(widget.initialVideoId!),
      );
    } else {
      context.read<FeedBloc>().add(const FeedLoadRequested());
    }
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _cache.disposeAll();
    super.dispose();
  }

  void _onPageChanged(int page) {
    _cache.pauseAll();
    setState(() => _activePage = page);
    final state = context.read<FeedBloc>().state;
    if (state is FeedLoaded) {
      _preloadAt(state.videos, page + 1);
      _preloadAt(state.videos, page + 2);
      if (page >= state.videos.length - 3) {
        context.read<FeedBloc>().add(const FeedLoadMoreRequested());
      }
    }
  }

  void _preloadAt(List<VideoEntity> videos, int idx) {
    if (idx < 0 || idx >= videos.length) return;
    _cache.getOrCreate(videos[idx].videoPath);
  }

  void _handlePendingScroll(FeedLoaded state) {
    if (state.pendingScrollToVideoId == null || _hasScrolledToTarget) return;
    final idx = state.videos.indexWhere(
      (v) => v.id == state.pendingScrollToVideoId,
    );
    if (idx == -1) return;
    _hasScrolledToTarget = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_pageCtrl.hasClients) {
        _pageCtrl.jumpToPage(idx);
        setState(() => _activePage = idx);
      }
    });
  }

  Future<void> _onRefresh() async {
    _hasScrolledToTarget = false;
    context.read<FeedBloc>().add(const FeedRefreshRequested());
    await Future.delayed(const Duration(milliseconds: 600));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          BlocConsumer<FeedBloc, FeedState>(
            buildWhen: (prev, curr) {
              if (prev is FeedLoaded && curr is FeedLoaded) {
                return prev.videos != curr.videos ||
                    prev.isLoadingMore != curr.isLoadingMore;
              }
              return true;
            },
            listener: (_, state) {
              if (state is FeedLoaded && state.pendingScrollToVideoId != null) {
                _handlePendingScroll(state);
              }
            },
            builder: (_, state) {
              if (state is FeedLoading) return _buildShimmer();
              if (state is FeedError) return _buildError(state.message);
              if (state is FeedLoaded) return _buildFeed(state);
              return const SizedBox.shrink();
            },
          ),
          BlocBuilder<FeedBloc, FeedState>(
            builder: (_, state) => FeedTopBar(
              activeTab: state is FeedLoaded ? state.activeTab : FeedTab.forYou,
              onTabChanged: (tab) =>
                  context.read<FeedBloc>().add(FeedTabChanged(tab)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeed(FeedLoaded state) {
    if (state.videos.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.videocam_off_outlined,
              color: Colors.white24,
              size: 64,
            ),
            const SizedBox(height: 16),
            const Text(
              'No videos yet',
              style: TextStyle(color: Colors.white38, fontSize: 16),
            ),
            if (state.activeTab == FeedTab.following) ...[
              const SizedBox(height: 8),
              const Text(
                'Follow creators to see their videos here',
                style: TextStyle(color: Colors.white24, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _onRefresh,
      color: AppColors.primary,
      backgroundColor: AppColors.bgCard,
      child: PageView.builder(
        controller: _pageCtrl,
        scrollDirection: Axis.vertical,
        itemCount: state.videos.length + (state.isLoadingMore ? 1 : 0),
        onPageChanged: _onPageChanged,
        itemBuilder: (_, i) {
          if (i >= state.videos.length) {
            return const Center(
              child: CircularProgressIndicator(
                color: AppColors.primary,
                strokeWidth: 2,
              ),
            );
          }
          final video = state.videos[i];
          return VideoItem(
            key: ValueKey(video.id),
            video: video,
            isActive: i == _activePage,
            controllerFuture: _cache.getOrCreate(video.videoPath),
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

  Widget _buildError(String msg) => Center(
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
          onPressed: () =>
              context.read<FeedBloc>().add(const FeedLoadRequested()),
          child: const Text(
            'Retry',
            style: TextStyle(color: AppColors.primary),
          ),
        ),
      ],
    ),
  );
}
