// features/feed/presentation/screen/search_feed_screen.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/storage_image.dart';
import '../../../video/domain/entities/video_entity.dart';
import '../widgets/video_item.dart';
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
    for (final c in _cache.values) c.pause();
  }

  Future<void> disposeAll() async {
    for (final c in _cache.values) await c.dispose();
    _cache.clear();
    _pending.clear();
  }
}

class SearchFeedScreen extends StatefulWidget {
  final List<VideoEntity> videos;
  final int initialIndex;

  const SearchFeedScreen({
    super.key,
    required this.videos,
    required this.initialIndex,
  });

  @override
  State<SearchFeedScreen> createState() => _SearchFeedScreenState();
}

class _SearchFeedScreenState extends State<SearchFeedScreen> {
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

  void _onPageChanged(int page) {
    _cache.pauseAll();
    setState(() => _activePage = page);
    _preloadAt(page + 1);
    _preloadAt(page + 2);
  }

  void _preloadAt(int idx) {
    final videos = widget.videos;
    if (idx < 0 || idx >= videos.length) return;
    _cache.getOrCreate(videos[idx].videoPath);
  }

  @override
  Widget build(BuildContext context) {
    final videos = widget.videos;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageCtrl,
            scrollDirection: Axis.vertical,
            itemCount: videos.length,
            onPageChanged: _onPageChanged,
            itemBuilder: (_, i) {
              final video = videos[i];
              return VideoItem(
                key: ValueKey(video.id),
                video: video,
                isActive: i == _activePage,
                controllerFuture: _cache.getOrCreate(video.videoPath),
              );
            },
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(left: 12, top: 8),
              child: _BackButton(onTap: () => context.pop()),
            ),
          ),
        ],
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  final VoidCallback onTap;
  const _BackButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: const BoxDecoration(
          color: Colors.black54,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.arrow_back_ios_new_rounded,
            color: Colors.white, size: 18),
      ),
    );
  }
}