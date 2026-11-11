import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/saved_videos_service.dart';
import '../../../../core/utils/storage_image.dart';
import '../../../../di/injector.dart';
import '../../../../routes/app_router.dart';
import '../../../video/domain/entities/video_entity.dart';

class SavedVideosScreen extends StatefulWidget {
  const SavedVideosScreen({super.key});

  @override
  State<SavedVideosScreen> createState() => _SavedVideosScreenState();
}

class _SavedVideosScreenState extends State<SavedVideosScreen> {
  final SavedVideosService _savedService = sl<SavedVideosService>();
  List<VideoEntity> _videos = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
    _savedService.addListener(_load);
  }

  @override
  void dispose() {
    _savedService.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final list = await _savedService.fetchSavedVideos();
    if (!mounted) return;
    setState(() {
      _videos = list;
      _loading = false;
    });
  }

  String _fmtCount(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 19),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Nội dung đã lưu',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: Colors.black87,
          ),
        ),
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _videos.isEmpty
            ? ListView(
                children: [
                  SizedBox(height: MediaQuery.of(context).size.height * 0.22),
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 36),
                      child: Column(
                        children: [
                          Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.08),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.bookmark_border_rounded,
                              size: 36,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Chưa có video đã lưu',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Nhấn nút Chia sẻ trên bất kỳ video nào rồi chọn "Lưu video" để xem lại nhanh tại đây.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.black54,
                              height: 1.45,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              )
            : GridView.builder(
                padding: const EdgeInsets.all(2),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 2,
                  crossAxisSpacing: 2,
                  childAspectRatio: 0.72,
                ),
                itemCount: _videos.length,
                itemBuilder: (context, index) {
                  final video = _videos[index];
                  final thumb = StorageImage.videoThumbnail(
                    video.thumbnailPath,
                  );
                  return GestureDetector(
                    onTap: () {
                      context.push(
                        Routes.searchFeedViewer,
                        extra: {
                          'videos': _videos,
                          'initialIndex': index,
                        },
                      );
                    },
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Container(
                          color: Colors.black87,
                          child: thumb != null
                              ? CachedNetworkImage(
                                  imageUrl: thumb,
                                  fit: BoxFit.cover,
                                  errorWidget: (_, _, _) => const Icon(
                                    Icons.play_circle_outline_rounded,
                                    color: Colors.white54,
                                    size: 30,
                                  ),
                                )
                              : const Icon(
                                  Icons.play_circle_outline_rounded,
                                  color: Colors.white54,
                                  size: 30,
                                ),
                        ),
                        Positioned(
                          left: 6,
                          bottom: 6,
                          child: Row(
                            children: [
                              const Icon(
                                Icons.play_arrow_rounded,
                                color: Colors.white,
                                size: 15,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                _fmtCount(video.viewCount),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black54,
                                      blurRadius: 4,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Positioned(
                          top: 6,
                          right: 6,
                          child: GestureDetector(
                            onTap: () => _savedService.toggleSave(video.id),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.45),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.bookmark_rounded,
                                color: AppColors.primary,
                                size: 16,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }
}

