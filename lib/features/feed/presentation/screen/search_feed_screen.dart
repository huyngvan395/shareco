// features/feed/presentation/screen/search_feed_screen.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/utils/video_controller_cache.dart';
import '../../../video/domain/entities/video_entity.dart';
import '../widgets/video_item.dart';

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
  final _cache = VideoControllerCache();
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