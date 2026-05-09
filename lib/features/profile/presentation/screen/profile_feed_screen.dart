// features/profile/presentation/screen/profile_feed_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shareco/features/profile/presentation/bloc/profile_bloc.dart';
import 'package:shareco/features/profile/presentation/bloc/profile_event.dart';
import 'package:shareco/features/profile/presentation/bloc/profile_state.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/storage_image.dart';
import '../../../feed/presentation/widgets/video_item.dart';
import '../../../video/domain/entities/video_entity.dart';
import 'package:video_player/video_player.dart';

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

class ProfileFeedScreen extends StatefulWidget {
  /// Index của video được tap trong grid
  final int initialIndex;

  const ProfileFeedScreen({super.key, required this.initialIndex});

  @override
  State<ProfileFeedScreen> createState() => _ProfileFeedScreenState();
}

class _ProfileFeedScreenState extends State<ProfileFeedScreen> {
  final _cache = _VideoCache();
  late final PageController _pageCtrl;
  int _activePage = 0;

  @override
  void initState() {
    super.initState();
    _activePage = widget.initialIndex;
    _pageCtrl = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _cache.disposeAll();
    super.dispose();
  }

  void _onPageChanged(int page, List<VideoEntity> videos, ProfileBloc bloc) {
    _cache.pauseAll();
    setState(() => _activePage = page);

    // Preload
    _preloadAt(videos, page + 1);
    _preloadAt(videos, page + 2);

    // Load more khi gần cuối
    if (page >= videos.length - 3) {
      bloc.add(const ProfileVideosLoadMoreRequested());
    }
  }

  void _preloadAt(List<VideoEntity> videos, int idx) {
    if (idx < 0 || idx >= videos.length) return;
    _cache.getOrCreate(videos[idx].videoPath);
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ProfileBloc, ProfileState>(
      builder: (context, state) {
        if (state is! ProfileLoaded) return const SizedBox.shrink();

        final videos = state.videos;

        return Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            children: [
              // ── Feed dọc ──────────────────────────────────────────────────
              PageView.builder(
                controller: _pageCtrl,
                scrollDirection: Axis.vertical,
                itemCount: videos.length + (state.isLoadingMoreVideos ? 1 : 0),
                onPageChanged: (p) =>
                    _onPageChanged(p, videos, context.read<ProfileBloc>()),
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
                  return VideoItem(
                    key: ValueKey(video.id),
                    video: video,
                    isActive: i == _activePage,
                    controllerFuture: _cache.getOrCreate(video.videoPath),
                  );
                },
              ),

              // ── Nút thoát ─────────────────────────────────────────────────
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.only(left: 12, top: 8),
                  child: _CloseButton(onTap: () => Navigator.of(context).pop()),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CloseButton extends StatelessWidget {
  final VoidCallback onTap;
  const _CloseButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: Colors.black54,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.close_rounded, color: Colors.white, size: 22),
      ),
    );
  }
}