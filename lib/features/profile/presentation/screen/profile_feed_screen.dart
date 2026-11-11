// features/profile/presentation/screen/profile_feed_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shareco/features/profile/presentation/bloc/profile_bloc.dart';
import 'package:shareco/features/profile/presentation/bloc/profile_event.dart';
import 'package:shareco/features/profile/presentation/bloc/profile_state.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/video_controller_cache.dart';
import '../../../feed/presentation/widgets/video_item.dart';
import '../../../video/domain/entities/video_entity.dart';

class ProfileFeedScreen extends StatefulWidget {
  /// Index của video được tap trong grid
  final int initialIndex;

  const ProfileFeedScreen({super.key, required this.initialIndex});

  @override
  State<ProfileFeedScreen> createState() => _ProfileFeedScreenState();
}

class _ProfileFeedScreenState extends State<ProfileFeedScreen> {
  final _cache = VideoControllerCache(maxControllers: 3);
  late final PageController _pageCtrl;
  int _activePage = 0;
  Timer? _preloadDebounce;

  @override
  void initState() {
    super.initState();
    VideoControllerCache.pauseAllGlobal(except: _cache);
    _activePage = widget.initialIndex;
    _pageCtrl = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _preloadDebounce?.cancel();
    _pageCtrl.dispose();
    _cache.disposeAll();
    super.dispose();
  }

  void _onPageChanged(int page, List<VideoEntity> videos, ProfileBloc bloc) {
    _cache.pauseAll();
    setState(() => _activePage = page);

    _preloadDebounce?.cancel();
    _preloadDebounce = Timer(const Duration(milliseconds: 180), () {
      if (!mounted) return;
      final next = page + 1;
      if (next >= 0 && next < videos.length) {
        _cache.preload(videos[next].videoPath);
      }
    });

    // Load more khi gần cuối
    if (page >= videos.length - 3) {
      bloc.add(const ProfileVideosLoadMoreRequested());
    }
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
                    key: ValueKey('profile_${video.id}'),
                    video: video,
                    cache: _cache,
                    isActive: i == _activePage,
                    shouldPrepare: (i - _activePage).abs() <= 1,
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
        decoration: const BoxDecoration(
          color: Colors.black54,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.close_rounded, color: Colors.white, size: 22),
      ),
    );
  }
}
