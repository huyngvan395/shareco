// features/video/presentation/screen/video_edit_screen.dart

import 'dart:async';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shareco/core/notifier/video_posted_notifier.dart';
import 'package:shareco/core/services/cloudinary/cloudinary_service.dart';
import 'package:shareco/features/video/data/datasources/music_search_service.dart';
import 'package:shareco/features/video/domain/entities/filter_entity.dart';
import 'package:shareco/features/video/presentation/bloc/create_video_event.dart';
import 'package:shareco/features/video/presentation/bloc/create_video_state.dart';
import 'package:video_player/video_player.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/storage_image.dart';
import '../../../../di/injector.dart';
import '../../../ecommerce/product/domain/entities/product.dart';
import '../../../ecommerce/product/domain/usecases/get_products_usecase.dart';
import '../bloc/create_video_bloc.dart';

class VideoEditScreen extends StatefulWidget {
  final String localVideoPath;
  final String? thumbnailPath;
  final VideoEffectMeta? initialEffects;
  final VoidCallback? onVideoPosted;

  const VideoEditScreen({
    super.key,
    required this.localVideoPath,
    this.thumbnailPath,
    this.initialEffects,
    this.onVideoPosted,
  });

  @override
  State<VideoEditScreen> createState() => _VideoEditScreenState();
}

class _VideoEditScreenState extends State<VideoEditScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  final _captionCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 4, vsync: this);
    context.read<CreateVideoBloc>().add(
      CreateVideoPickedFromPath(
        localPath: widget.localVideoPath,
        thumbnailPath: widget.thumbnailPath ?? '',
        initialEffects: widget.initialEffects,
      ),
    );
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _captionCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<CreateVideoBloc, CreateVideoState>(
      listener: (ctx, state) {
        if (state is CreateVideoSuccess) {
          VideoPostedNotifier.instance.notify();
          widget.onVideoPosted?.call();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Xuất & đăng tải video thành công! Video đang chờ Admin kiểm duyệt để lên Xu hướng.',
              ),
              backgroundColor: AppColors.success,
            ),
          );
          Navigator.of(context).popUntil((r) => r.isFirst);
        } else if (state is CreateVideoError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: AppColors.error,
            ),
          );
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.surfaceDark,
        appBar: _buildAppBar(),
        body: BlocBuilder<CreateVideoBloc, CreateVideoState>(
          builder: (_, state) {
            if (state is CreateVideoUploading) {
              return _buildUploading(state);
            }
            final picked = state is CreateVideoPickedFile ? state : null;
            final taggedCount = picked?.taggedProducts.length ?? 0;

            return Column(
              children: [
                // ── Interactive TikTok Studio Preview & Effect Editor ─────────
                _VideoPreviewStrip(
                  localVideoPath: widget.localVideoPath,
                  thumbnailPath: picked?.thumbnailPath ?? widget.thumbnailPath,
                  pickedState: picked,
                ),
                const Divider(height: 1, color: AppColors.borderSubtle),

                // ── Edit panels ────────────────────────────────────────────
                TabBar(
                  controller: _tabCtrl,
                  indicatorColor: AppColors.primary,
                  indicatorWeight: 2.5,
                  labelColor: Colors.white,
                  unselectedLabelColor: AppColors.textMuted,
                  dividerColor: AppColors.borderSubtle,
                  labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                  labelStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  tabs: [
                    const Tab(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text('Mô tả'),
                      ),
                    ),
                    Tab(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('Sản phẩm'),
                            if (taggedCount > 0) ...[
                              const SizedBox(width: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                  vertical: 1,
                                ),
                                decoration: BoxDecoration(
                                  gradient: AppColors.shopGradient,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '$taggedCount',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const Tab(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text('Ảnh bìa'),
                      ),
                    ),
                    const Tab(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text('Cài đặt'),
                      ),
                    ),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabCtrl,
                    children: [
                      _CaptionTab(ctrl: _captionCtrl),
                      const _ProductTagTab(),
                      const _ThumbnailTab(),
                      const _SettingsTab(),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() => AppBar(
    backgroundColor: AppColors.surfaceDark,
    foregroundColor: Colors.white,
    elevation: 0,
    centerTitle: false,
    titleSpacing: 0,
    title: const Text(
      'Đăng video',
      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
    ),
    actions: [
      BlocBuilder<CreateVideoBloc, CreateVideoState>(
        builder: (ctx, state) {
          final isTooLarge =
              state is CreateVideoPickedFile &&
              state.fileSizeBytes > CloudinaryService.maxVideoSizeBytes;

          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: state is CreateVideoUploading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                        strokeWidth: 2,
                      ),
                    )
                  : InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: isTooLarge
                          ? () {
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Video vượt quá giới hạn tối đa 100 MB. Vui lòng chọn video nhẹ hơn.',
                                  ),
                                  backgroundColor: AppColors.error,
                                ),
                              );
                            }
                          : () => ctx.read<CreateVideoBloc>().add(
                              CreateVideoPostRequested(
                                caption: _captionCtrl.text.trim(),
                              ),
                            ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          gradient: isTooLarge
                              ? null
                              : AppColors.primaryGradient,
                          color: isTooLarge ? Colors.white12 : null,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: isTooLarge
                              ? null
                              : [
                                  BoxShadow(
                                    color: AppColors.primary.withValues(
                                      alpha: 0.3,
                                    ),
                                    blurRadius: 10,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.movie_creation_outlined,
                              color: isTooLarge
                                  ? Colors.white38
                                  : Colors.white,
                              size: 15,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              'Xuất & Đăng',
                              style: TextStyle(
                                color: isTooLarge
                                    ? Colors.white38
                                    : Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
            ),
          );
        },
      ),
    ],
  );

  Widget _buildUploading(CreateVideoUploading uploading) {
    final progress = uploading.progress.clamp(0.0, 1.0);
    final percentText = '${(progress * 100).toStringAsFixed(0)}%';
    final totalMB = uploading.totalBytes / (1024 * 1024);
    final videoUploadRatio = (progress / 0.88).clamp(0.0, 1.0);
    final uploadedMB = totalMB * videoUploadRatio;

    String stageTitle;
    String stageSubtitle;
    if (progress < 0.08) {
      stageTitle = 'Đang kết xuất hiệu ứng & âm thanh...';
      stageSubtitle = uploading.effectMeta.hasAnyEffect
          ? 'Áp dụng bộ lọc "${uploading.effectMeta.filter.name}"${uploading.effectMeta.music != null ? ' & ghép nhạc "${uploading.effectMeta.music!.title}"' : ''}'
          : 'Đang chuẩn bị luồng dữ liệu video gốc...';
    } else if (progress < 0.88) {
      stageTitle = 'Đang tải video lên máy chủ...';
      stageSubtitle = totalMB > 0
          ? 'Đã truyền tải ${uploadedMB.toStringAsFixed(2)} MB / ${totalMB.toStringAsFixed(2)} MB (Giới hạn tối đa ${CloudinaryService.maxVideoSizeMB} MB)'
          : 'Đang truyền tải dữ liệu video lên đám mây...';
    } else if (progress < 0.95) {
      stageTitle = 'Đang tạo & tải lên ảnh bìa...';
      stageSubtitle = 'Tối ưu hóa ảnh đại diện độ phân giải cao cho video';
    } else {
      stageTitle = 'Đang hoàn tất xuất bản...';
      stageSubtitle = 'Lưu siêu dữ liệu hiệu ứng, âm nhạc và gắn thẻ sản phẩm';
    }

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF141418),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.4),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Vòng tròn hiển thị % thực tế
              SizedBox(
                width: 112,
                height: 112,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 104,
                      height: 104,
                      child: CircularProgressIndicator(
                        value: progress,
                        backgroundColor: Colors.white.withOpacity(0.08),
                        valueColor: const AlwaysStoppedAnimation(
                          AppColors.primary,
                        ),
                        strokeWidth: 7,
                        strokeCap: StrokeCap.round,
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          percentText,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const Text(
                          'TIẾN ĐỘ',
                          style: TextStyle(
                            color: Colors.white38,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.1,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              Text(
                stageTitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                stageSubtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.55),
                  fontSize: 12.5,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),

              // Thanh tiến độ Linear + số MB thực tế
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: const Color(0xFF22222A),
                  valueColor: const AlwaysStoppedAnimation(AppColors.primary),
                  minHeight: 8,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    totalMB > 0
                        ? '${uploadedMB.toStringAsFixed(2)} MB / ${totalMB.toStringAsFixed(2)} MB'
                        : 'Đang đồng bộ...',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    percentText,
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              const Divider(color: Color(0xFF25252E), height: 1),
              const SizedBox(height: 14),

              // Các bước xử lý trực quan
              _UploadStepRow(
                label: 'Áp dụng Filter màu & đồng bộ nhạc nền',
                done: progress >= 0.08,
                active: progress < 0.08,
              ),
              const SizedBox(height: 8),
              _UploadStepRow(
                label: 'Tải tệp video lên đám mây (Thực tế theo Byte)',
                done: progress >= 0.88,
                active: progress >= 0.08 && progress < 0.88,
              ),
              const SizedBox(height: 8),
              _UploadStepRow(
                label: 'Tải ảnh bìa & xuất bản lên hệ thống',
                done: progress >= 0.99,
                active: progress >= 0.88 && progress < 0.99,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UploadStepRow extends StatelessWidget {
  final String label;
  final bool done;
  final bool active;

  const _UploadStepRow({
    required this.label,
    required this.done,
    required this.active,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (done)
          const Icon(
            Icons.check_circle_rounded,
            color: AppColors.success,
            size: 16,
          )
        else if (active)
          const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              color: AppColors.primary,
              strokeWidth: 2,
            ),
          )
        else
          const Icon(
            Icons.radio_button_unchecked_rounded,
            color: Colors.white24,
            size: 16,
          ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: done
                  ? Colors.white
                  : active
                  ? AppColors.primary
                  : Colors.white38,
              fontSize: 12,
              fontWeight: active || done ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Interactive Video Studio Preview & Effects Bar ──────────────────────────

class _VideoPreviewStrip extends StatefulWidget {
  final String localVideoPath;
  final String? thumbnailPath;
  final CreateVideoPickedFile? pickedState;

  const _VideoPreviewStrip({
    required this.localVideoPath,
    this.thumbnailPath,
    this.pickedState,
  });

  @override
  State<_VideoPreviewStrip> createState() => _VideoPreviewStripState();
}

class _VideoPreviewStripState extends State<_VideoPreviewStrip> {
  VideoPlayerController? _videoCtrl;
  final AudioPlayer _musicPlayer = AudioPlayer();
  bool _videoInitialized = false;
  String? _loadedMusicId;

  VideoEffectMeta get _fx =>
      widget.pickedState?.effectMeta ?? const VideoEffectMeta();

  @override
  void initState() {
    super.initState();
    _initPlayers();
  }

  Future<void> _initPlayers() async {
    final file = File(widget.localVideoPath);
    if (!file.existsSync()) return;

    try {
      final ctrl = VideoPlayerController.file(
        file,
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
      );
      await ctrl.initialize();
      await ctrl.setLooping(true);
      await ctrl.setVolume(_fx.originalVolume);
      await ctrl.setPlaybackSpeed(_fx.playbackSpeed);
      await ctrl.play();

      if (!mounted) {
        await ctrl.dispose();
        return;
      }

      setState(() {
        _videoCtrl = ctrl;
        _videoInitialized = true;
      });

      await _syncMusicWithEffect(_fx);
    } catch (_) {}
  }

  @override
  void didUpdateWidget(covariant _VideoPreviewStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldFx = oldWidget.pickedState?.effectMeta;
    final newFx = _fx;
    if (oldFx != newFx) {
      _videoCtrl?.setVolume(newFx.originalVolume);
      _videoCtrl?.setPlaybackSpeed(newFx.playbackSpeed);
      _syncMusicWithEffect(newFx);
    }
  }

  Future<void> _syncMusicWithEffect(VideoEffectMeta fx) async {
    final track = fx.music;
    if (track == null || track.previewUrl == null || track.previewUrl!.isEmpty) {
      _loadedMusicId = null;
      await _musicPlayer.stop();
      return;
    }

    try {
      await _musicPlayer.setVolume(fx.musicVolume);
      if (_loadedMusicId != track.id) {
        _loadedMusicId = track.id;
        await _musicPlayer.setUrl(track.previewUrl!);
        await _musicPlayer.setLoopMode(LoopMode.one);
      }
      if (_videoCtrl?.value.isPlaying ?? true) {
        await _musicPlayer.play();
      }
    } catch (_) {}
  }

  void _togglePlayPause() {
    final ctrl = _videoCtrl;
    if (ctrl == null || !_videoInitialized) return;
    if (ctrl.value.isPlaying) {
      ctrl.pause();
      _musicPlayer.pause();
    } else {
      ctrl.play();
      if (_fx.music != null) _musicPlayer.play();
    }
    setState(() {});
  }

  @override
  void dispose() {
    _musicPlayer.dispose();
    _videoCtrl?.dispose();
    super.dispose();
  }

  void _updateEffects(BuildContext context, VideoEffectMeta updated) {
    context.read<CreateVideoBloc>().add(CreateVideoEffectUpdated(updated));
  }

  @override
  Widget build(BuildContext context) {
    final fx = _fx;
    final sizeMB = widget.pickedState?.fileSizeMB ?? 0.0;
    final maxMB = CloudinaryService.maxVideoSizeMB;
    final isOverLimit = sizeMB > maxMB;
    final sizeRatio = (sizeMB / maxMB).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      color: const Color(0xFF0E0E12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Khung phát Video Preview trực tiếp có Filter, Text, Sticker ──
          GestureDetector(
            onTap: _togglePlayPause,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Container(
                width: 112,
                height: 184,
                color: const Color(0xFF1A1A1A),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _buildLiveVideoOrThumb(fx),

                    // Stickers trên khung preview
                    ...fx.stickers.map(
                      (s) => Positioned(
                        left: (s.position.dx * 0.3).clamp(4.0, 82.0),
                        top: (s.position.dy * 0.3).clamp(8.0, 140.0),
                        child: Text(
                          s.emoji,
                          style: const TextStyle(fontSize: 22),
                        ),
                      ),
                    ),

                    // Text overlays trên khung preview
                    ...fx.textOverlays.map(
                      (t) => Positioned(
                        left: 6,
                        right: 6,
                        top: (t.position.dy * 0.3).clamp(16.0, 136.0),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            t.text,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: t.color,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Badge Filter góc trên trái
                    if (fx.filterId != 'none')
                      Positioned(
                        top: 6,
                        left: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.85),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            fx.filter.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),

                    // Play / Pause icon
                    if (!_videoInitialized ||
                        !(_videoCtrl?.value.isPlaying ?? false))
                      Center(
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.55),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                      ),

                    // Thanh nhạc chạy dưới đáy preview
                    if (fx.music != null)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 4,
                          ),
                          color: Colors.black.withOpacity(0.68),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.music_note_rounded,
                                color: AppColors.primary,
                                size: 11,
                              ),
                              const SizedBox(width: 3),
                              Expanded(
                                child: Text(
                                  fx.music!.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),

          // ── Cột phải: Thông tin dung lượng + Công cụ Studio (Filter, Nhạc, Chữ, Sticker) ──
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Hộp kiểm tra dung lượng Video & Giới hạn tối đa 100 MB
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isOverLimit
                        ? Colors.red.withOpacity(0.12)
                        : const Color(0xFF181820),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isOverLimit
                          ? Colors.redAccent.withOpacity(0.5)
                          : Colors.white.withOpacity(0.07),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            isOverLimit
                                ? Icons.warning_amber_rounded
                                : Icons.sd_storage_rounded,
                            size: 13,
                            color: isOverLimit
                                ? Colors.redAccent
                                : AppColors.primary,
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              'Dung lượng: ${sizeMB.toStringAsFixed(1)} MB / Tối đa $maxMB MB',
                              style: TextStyle(
                                color: isOverLimit
                                    ? Colors.redAccent
                                    : Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: sizeRatio,
                          minHeight: 4,
                          backgroundColor: Colors.white10,
                          valueColor: AlwaysStoppedAnimation(
                            isOverLimit
                                ? Colors.redAccent
                                : sizeMB > 75
                                ? Colors.orangeAccent
                                : const Color(0xFF00E676),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // 2. Tiêu đề Studio Hiệu ứng (Không bị tràn lề phải)
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'HIỆU ỨNG & ÂM THANH',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                    if (fx.hasAnyEffect)
                      GestureDetector(
                        onTap: () =>
                            _updateEffects(context, const VideoEffectMeta()),
                        child: const Padding(
                          padding: EdgeInsets.only(left: 6),
                          child: Text(
                            'Đặt lại',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),

                // 3. Lưới 4 nút công cụ Studio (Bộ lọc, Nhạc nền, Chèn chữ, Nhãn dán)
                Row(
                  children: [
                    Expanded(
                      child: _StudioActionTile(
                        icon: Icons.color_lens_rounded,
                        title: 'Bộ lọc',
                        subtitle:
                            fx.filterId != 'none' ||
                                fx.playbackSpeed != 1.0 ||
                                fx.hasBeautyEffect
                            ? '${fx.filter.name} · ${fx.playbackSpeed}x'
                            : 'Màu & Làm đẹp',
                        isActive:
                            fx.filterId != 'none' ||
                            fx.playbackSpeed != 1.0 ||
                            fx.hasBeautyEffect,
                        accentColor: const Color(0xFFFF2D55),
                        onTap: () => _openFilterSpeedSheet(context, fx),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _StudioActionTile(
                        icon: Icons.music_note_rounded,
                        title: 'Nhạc nền',
                        subtitle: fx.music != null
                            ? fx.music!.title
                            : 'Việt, Anh, Hàn...',
                        isActive: fx.music != null,
                        accentColor: const Color(0xFF00C6FF),
                        onTap: () => _openMusicMixerSheet(context, fx),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _StudioActionTile(
                        icon: Icons.text_fields_rounded,
                        title: 'Chèn chữ',
                        subtitle: fx.textOverlays.isNotEmpty
                            ? 'Đã thêm ${fx.textOverlays.length} dòng'
                            : 'Thêm tiêu đề',
                        isActive: fx.textOverlays.isNotEmpty,
                        accentColor: const Color(0xFFFFB300),
                        onTap: () => _openTextEditorSheet(context, fx),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _StudioActionTile(
                        icon: Icons.emoji_emotions_rounded,
                        title: 'Nhãn dán',
                        subtitle: fx.stickers.isNotEmpty
                            ? 'Đã gắn ${fx.stickers.length} nhãn'
                            : 'Thêm sticker',
                        isActive: fx.stickers.isNotEmpty,
                        accentColor: const Color(0xFFAB47BC),
                        onTap: () => _openStickerPickerSheet(context, fx),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveVideoOrThumb(VideoEffectMeta fx) {
    Widget content;
    if (_videoInitialized && _videoCtrl != null) {
      content = FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: _videoCtrl!.value.size.width > 0
              ? _videoCtrl!.value.size.width
              : 720,
          height: _videoCtrl!.value.size.height > 0
              ? _videoCtrl!.value.size.height
              : 1280,
          child: VideoPlayer(_videoCtrl!),
        ),
      );
    } else if (widget.thumbnailPath != null &&
        widget.thumbnailPath!.isNotEmpty &&
        File(widget.thumbnailPath!).existsSync()) {
      content = Image.file(File(widget.thumbnailPath!), fit: BoxFit.cover);
    } else {
      content = Container(
        color: const Color(0xFF141414),
        child: const Center(
          child: Icon(
            Icons.video_file_rounded,
            color: Color(0xFF333333),
            size: 36,
          ),
        ),
      );
    }

    if (fx.hasBeautyEffect) {
      content = BeautyEffectProcessor(
        enabled: fx.beautyEnabled,
        smooth: fx.beautySmooth,
        whiten: fx.beautyWhiten,
        slim: fx.beautySlim,
        eyes: fx.beautyEyes,
        child: content,
      );
    }

    content = VideoFilterEffectRenderer(
      filter: fx.filter,
      child: content,
    );
    return content;
  }

  void _openFilterSpeedSheet(BuildContext context, VideoEffectMeta currentFx) {
    final bloc = context.read<CreateVideoBloc>();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => BlocProvider.value(
        value: bloc,
        child: const _StudioFilterSpeedSheet(),
      ),
    );
  }

  void _openMusicMixerSheet(BuildContext context, VideoEffectMeta currentFx) {
    final bloc = context.read<CreateVideoBloc>();
    // Tạm dừng nhạc nền preview bên ngoài khi mở sheet chọn nhạc
    _musicPlayer.pause();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BlocProvider.value(
        value: bloc,
        child: const _StudioMusicMixerSheet(),
      ),
    ).whenComplete(() {
      if (mounted) _syncMusicWithEffect(_fx);
    });
  }

  void _openTextEditorSheet(BuildContext context, VideoEffectMeta currentFx) {
    final bloc = context.read<CreateVideoBloc>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BlocProvider.value(
        value: bloc,
        child: const _StudioTextSheet(),
      ),
    );
  }

  void _openStickerPickerSheet(BuildContext context, VideoEffectMeta currentFx) {
    final bloc = context.read<CreateVideoBloc>();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => BlocProvider.value(
        value: bloc,
        child: const _StudioStickerSheet(),
      ),
    );
  }
}

class _StudioActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isActive;
  final Color accentColor;
  final VoidCallback onTap;

  const _StudioActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isActive,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
        decoration: BoxDecoration(
          color: isActive
              ? accentColor.withValues(alpha: 0.14)
              : const Color(0xFF181820),
          borderRadius: BorderRadius.circular(11),
          border: Border.all(
            color: isActive
                ? accentColor.withValues(alpha: 0.6)
                : Colors.white.withValues(alpha: 0.07),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: isActive
                        ? accentColor
                        : Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    icon,
                    color: isActive ? Colors.white : accentColor,
                    size: 13,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isActive ? accentColor : Colors.white54,
                fontSize: 10,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Studio Bottom Sheets (Filter/Speed, Music Mixer, Text, Sticker) ─────────

class _StudioFilterSpeedSheet extends StatelessWidget {
  const _StudioFilterSpeedSheet();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CreateVideoBloc, CreateVideoState>(
      builder: (ctx, state) {
        final fx = state is CreateVideoPickedFile
            ? state.effectMeta
            : const VideoEffectMeta();

        return Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          decoration: const BoxDecoration(
            color: Color(0xFF141418),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    const Icon(
                      Icons.color_lens_rounded,
                      color: AppColors.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Bộ lọc màu & Tốc độ video',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        'Xong',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 106,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: AppFilters.all.length,
                    itemBuilder: (_, i) {
                      final f = AppFilters.all[i];
                      final active = fx.filterId == f.id;
                      return GestureDetector(
                        onTap: () => ctx.read<CreateVideoBloc>().add(
                          CreateVideoEffectUpdated(
                            fx.copyWith(filterId: f.id),
                          ),
                        ),
                        child: Container(
                          width: 66,
                          margin: const EdgeInsets.only(right: 10),
                          child: Column(
                            children: [
                              FilterThumbnailBox(
                                filter: f,
                                size: 62,
                                selected: active,
                                borderRadius: 14,
                              ),
                              const SizedBox(height: 5),
                              Text(
                                f.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: active
                                      ? AppColors.primary
                                      : Colors.white70,
                                  fontSize: 11,
                                  fontWeight: active
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                ),
                              ),
                              Text(
                                f.subtitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white38,
                                  fontSize: 9,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'TỐC ĐỘ PHÁT VIDEO',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: AppSpeeds.speeds.map((s) {
                    final active = (fx.playbackSpeed - s.value).abs() < 0.01;
                    return Expanded(
                      child: GestureDetector(
                        onTap: () => ctx.read<CreateVideoBloc>().add(
                          CreateVideoEffectUpdated(
                            fx.copyWith(playbackSpeed: s.value),
                          ),
                        ),
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          padding: const EdgeInsets.symmetric(vertical: 9),
                          decoration: BoxDecoration(
                            color: active
                                ? AppColors.primary
                                : const Color(0xFF22222A),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(
                            child: Text(
                              s.label,
                              style: TextStyle(
                                color: active ? Colors.white : Colors.white70,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _StudioMusicMixerSheet extends StatefulWidget {
  const _StudioMusicMixerSheet();

  @override
  State<_StudioMusicMixerSheet> createState() => _StudioMusicMixerSheetState();
}

class _StudioMusicMixerSheetState extends State<_StudioMusicMixerSheet> {
  final AudioPlayer _previewPlayer = AudioPlayer();
  final TextEditingController _searchCtrl = TextEditingController();
  Timer? _debounce;
  String? _playingId;
  bool _isLoadingTracks = true;
  String _selectedCategory = 'Thịnh hành';
  List<MusicTrack> _tracks = const [];

  static const _categories = [
    'Thịnh hành',
    'Nhạc Việt',
    'Nhạc Anh',
    'Nhạc Hàn',
    'Nhạc Trung',
    'Remix / EDM',
  ];

  @override
  void initState() {
    super.initState();
    MusicSearchService.prefetchAllCategories();
    _loadCategory(_selectedCategory);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    _previewPlayer.dispose();
    super.dispose();
  }

  Future<void> _loadCategory(String category) async {
    setState(() {
      _selectedCategory = category;
      _isLoadingTracks = true;
    });
    final list = await MusicSearchService.getTracksByCategory(category);
    if (!mounted) return;
    setState(() {
      _tracks = list;
      _isLoadingTracks = false;
    });
  }

  void _onSearchChanged(String val) {
    _debounce?.cancel();
    final q = val.trim();
    if (q.isEmpty) {
      _loadCategory(_selectedCategory);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      if (!mounted) return;
      setState(() => _isLoadingTracks = true);
      final res = await MusicSearchService.searchTracks(
        q,
        categoryLabel: _selectedCategory,
      );
      if (!mounted) return;
      setState(() {
        _tracks = res;
        _isLoadingTracks = false;
      });
    });
  }

  Future<void> _togglePreview(MusicTrack track) async {
    if (_playingId == track.id) {
      await _previewPlayer.stop();
      if (mounted) setState(() => _playingId = null);
      return;
    }
    if (track.previewUrl == null) return;
    setState(() => _playingId = track.id);
    try {
      await _previewPlayer.setUrl(track.previewUrl!);
      await _previewPlayer.setLoopMode(LoopMode.one);
      await _previewPlayer.play();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CreateVideoBloc, CreateVideoState>(
      builder: (ctx, state) {
        final fx = state is CreateVideoPickedFile
            ? state.effectMeta
            : const VideoEffectMeta();

        return Container(
          height: MediaQuery.of(context).size.height * 0.82,
          decoration: const BoxDecoration(
            color: Color(0xFF121216),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                child: Row(
                  children: [
                    const Icon(
                      Icons.library_music_rounded,
                      color: Color(0xFF00C6FF),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Kho nhạc nền & Hòa âm',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (fx.music != null)
                      TextButton(
                        onPressed: () {
                          _previewPlayer.stop();
                          ctx.read<CreateVideoBloc>().add(
                            CreateVideoEffectUpdated(
                              fx.copyWith(clearMusic: true),
                            ),
                          );
                        },
                        child: const Text(
                          'Gỡ nhạc',
                          style: TextStyle(color: Colors.redAccent),
                        ),
                      ),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        'Xong',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Bộ trộn âm lượng (Audio Mixer)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF1B1B22),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white10),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.mic_rounded,
                          color: Colors.white70,
                          size: 15,
                        ),
                        const SizedBox(width: 6),
                        const SizedBox(
                          width: 88,
                          child: Text(
                            'Âm thanh gốc',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Slider(
                            value: fx.originalVolume,
                            min: 0,
                            max: 1,
                            activeColor: Colors.white,
                            onChanged: (v) => ctx.read<CreateVideoBloc>().add(
                              CreateVideoEffectUpdated(
                                fx.copyWith(originalVolume: v),
                              ),
                            ),
                          ),
                        ),
                        Text(
                          '${(fx.originalVolume * 100).round()}%',
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        const Icon(
                          Icons.music_note_rounded,
                          color: Color(0xFF00C6FF),
                          size: 15,
                        ),
                        const SizedBox(width: 6),
                        const SizedBox(
                          width: 88,
                          child: Text(
                            'Nhạc nền ghép',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Slider(
                            value: fx.musicVolume,
                            min: 0,
                            max: 1,
                            activeColor: const Color(0xFF00C6FF),
                            onChanged: (v) {
                              _previewPlayer.setVolume(v);
                              ctx.read<CreateVideoBloc>().add(
                                CreateVideoEffectUpdated(
                                  fx.copyWith(musicVolume: v),
                                ),
                              );
                            },
                          ),
                        ),
                        Text(
                          '${(fx.musicVolume * 100).round()}%',
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Tìm kiếm bài hát Việt, Anh, Hàn
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: _onSearchChanged,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Tìm bài hát Việt, Anh, Hàn, tên ca sĩ...',
                    hintStyle: const TextStyle(
                      color: Colors.white30,
                      fontSize: 12.5,
                    ),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: Colors.white38,
                      size: 18,
                    ),
                    filled: true,
                    fillColor: const Color(0xFF1E1E26),
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),

              // Tabs danh mục nhạc
              SizedBox(
                height: 32,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _categories.length,
                  itemBuilder: (_, i) {
                    final cat = _categories[i];
                    final active = _selectedCategory == cat;
                    return GestureDetector(
                      onTap: () {
                        _searchCtrl.clear();
                        _loadCategory(cat);
                      },
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: active
                              ? AppColors.primary
                              : const Color(0xFF1E1E26),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          cat,
                          style: TextStyle(
                            color: active ? Colors.white : Colors.white60,
                            fontSize: 11.5,
                            fontWeight: active
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              const Divider(height: 1, color: Color(0xFF22222A)),
              Expanded(
                child: _isLoadingTracks
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.primary,
                          strokeWidth: 2,
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
                        itemCount: _tracks.length,
                        itemBuilder: (_, i) {
                          final t = _tracks[i];
                          final selected = fx.music?.id == t.id;
                          final playing = _playingId == t.id;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: selected
                                  ? AppColors.primary.withValues(alpha: 0.14)
                                  : const Color(0xFF1A1A22),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: selected
                                    ? AppColors.primary
                                    : Colors.white.withValues(alpha: 0.05),
                              ),
                            ),
                            child: Row(
                              children: [
                                GestureDetector(
                                  onTap: () => _togglePreview(t),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: t.coverColors,
                                        ),
                                      ),
                                      child: Stack(
                                        fit: StackFit.expand,
                                        children: [
                                          if (t.artworkUrl != null &&
                                              t.artworkUrl!.isNotEmpty)
                                            CachedNetworkImage(
                                              imageUrl: t.artworkUrl!,
                                              fit: BoxFit.cover,
                                              errorWidget: (_, _, _) =>
                                                  const SizedBox.shrink(),
                                            ),
                                          Container(color: Colors.black26),
                                          Icon(
                                            playing
                                                ? Icons.pause_rounded
                                                : Icons.play_arrow_rounded,
                                            color: Colors.white,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        t.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: selected
                                              ? AppColors.primary
                                              : Colors.white,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13.5,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${t.artist} · ${t.category}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.white54,
                                          fontSize: 11.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton(
                                  onPressed: () {
                                    _previewPlayer.stop();
                                    AppMusicTracks.registerDynamicTracks([t]);
                                    ctx.read<CreateVideoBloc>().add(
                                      CreateVideoEffectUpdated(
                                        fx.copyWith(
                                          musicId: selected ? null : t.id,
                                          customMusic: selected ? null : t,
                                          clearMusic: selected,
                                        ),
                                      ),
                                    );
                                    if (!selected) {
                                      Navigator.pop(context);
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: selected
                                        ? Colors.white12
                                        : AppColors.primary,
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  child: Text(
                                    selected ? 'Đang dùng' : 'Chọn nhạc',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StudioTextSheet extends StatefulWidget {
  const _StudioTextSheet();

  @override
  State<_StudioTextSheet> createState() => _StudioTextSheetState();
}

class _StudioTextSheetState extends State<_StudioTextSheet> {
  final _ctrl = TextEditingController();
  Color _color = Colors.white;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CreateVideoBloc, CreateVideoState>(
      builder: (ctx, state) {
        final fx = state is CreateVideoPickedFile
            ? state.effectMeta
            : const VideoEffectMeta();

        return Container(
          padding: EdgeInsets.fromLTRB(
            16,
            14,
            16,
            MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          decoration: const BoxDecoration(
            color: Color(0xFF141418),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    'Chèn chữ nổi bật vào Video',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  if (fx.textOverlays.isNotEmpty)
                    TextButton(
                      onPressed: () => ctx.read<CreateVideoBloc>().add(
                        CreateVideoEffectUpdated(
                          fx.copyWith(textOverlays: const []),
                        ),
                      ),
                      child: const Text(
                        'Xóa hết',
                        style: TextStyle(color: Colors.redAccent),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 36,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    Colors.white,
                    const Color(0xFFFF2D55),
                    Colors.amber,
                    Colors.greenAccent,
                    Colors.lightBlueAccent,
                    Colors.orangeAccent,
                    Colors.purpleAccent,
                  ]
                      .map(
                        (c) => GestureDetector(
                          onTap: () => setState(() => _color = c),
                          child: Container(
                            width: 28,
                            height: 28,
                            margin: const EdgeInsets.only(right: 10),
                            decoration: BoxDecoration(
                              color: c,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: _color == c
                                    ? Colors.white
                                    : Colors.white24,
                                width: _color == c ? 2.5 : 1,
                              ),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      autofocus: true,
                      style: TextStyle(
                        color: _color,
                        fontWeight: FontWeight.w700,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Nhập tiêu đề hiển thị trên video...',
                        hintStyle: const TextStyle(color: Colors.white30),
                        filled: true,
                        fillColor: const Color(0xFF22222A),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: () {
                      final text = _ctrl.text.trim();
                      if (text.isNotEmpty) {
                        final updated = [
                          ...fx.textOverlays,
                          TextOverlay(
                            id: DateTime.now().millisecondsSinceEpoch
                                .toString(),
                            text: text,
                            color: _color,
                            position: Offset(
                              50,
                              120.0 + fx.textOverlays.length * 45,
                            ),
                          ),
                        ];
                        ctx.read<CreateVideoBloc>().add(
                          CreateVideoEffectUpdated(
                            fx.copyWith(textOverlays: updated),
                          ),
                        );
                      }
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Thêm',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StudioStickerSheet extends StatelessWidget {
  const _StudioStickerSheet();
  static const _emojis = [
    '🔥', '❤️', '😂', '🎉', '✨', '💯', '👑', '🌈',
    '🎵', '🌟', '💪', '🙌', '😍', '🤩', '👏', '🎊',
    '🦋', '🌸', '💥', '🎯', '🚀', '💎', '🌙', '⚡️',
  ];

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CreateVideoBloc, CreateVideoState>(
      builder: (ctx, state) {
        final fx = state is CreateVideoPickedFile
            ? state.effectMeta
            : const VideoEffectMeta();

        return Container(
          height: 270,
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            color: Color(0xFF141418),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  const Text(
                    'Chọn nhãn dán',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  if (fx.stickers.isNotEmpty)
                    TextButton(
                      onPressed: () => ctx.read<CreateVideoBloc>().add(
                        CreateVideoEffectUpdated(
                          fx.copyWith(stickers: const []),
                        ),
                      ),
                      child: const Text(
                        'Xóa hết',
                        style: TextStyle(color: Colors.redAccent),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 6,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                  ),
                  itemCount: _emojis.length,
                  itemBuilder: (_, i) => GestureDetector(
                    onTap: () {
                      final updated = [
                        ...fx.stickers,
                        StickerItem(
                          id: DateTime.now().millisecondsSinceEpoch.toString(),
                          emoji: _emojis[i],
                          label: _emojis[i],
                          position: Offset(
                            80.0 + (fx.stickers.length * 35) % 160,
                            140.0 + (fx.stickers.length * 40) % 200,
                          ),
                        ),
                      ];
                      ctx.read<CreateVideoBloc>().add(
                        CreateVideoEffectUpdated(
                          fx.copyWith(stickers: updated),
                        ),
                      );
                      Navigator.pop(context);
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Text(
                          _emojis[i],
                          style: const TextStyle(fontSize: 26),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}


// ─── Caption tab ───────────────────────────────────────────────────────────────

class _CaptionTab extends StatelessWidget {
  final TextEditingController ctrl;
  const _CaptionTab({required this.ctrl});

  static const _tags = [
    '#fyp', '#viral', '#trending', '#foryou',
    '#dance', '#funny', '#music', '#life',
  ];

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: ctrl,
          maxLines: 5,
          maxLength: 2200,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            height: 1.5,
          ),
          decoration: InputDecoration(
            hintText: 'Viết mô tả...\nThêm hashtag để tăng lượt tiếp cận',
            hintStyle: TextStyle(
              color: Colors.white.withOpacity(0.25),
              height: 1.6,
              fontSize: 13,
            ),
            filled: true,
            fillColor: const Color(0xFF141414),
            counterStyle: TextStyle(
              color: Colors.white.withOpacity(0.3),
              fontSize: 11,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(
                color: Color(0xFF2A2A2A),
                width: 1,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(
                color: Color(0xFF2A2A2A),
                width: 1,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color: AppColors.primary.withOpacity(0.6),
                width: 1.5,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'HASHTAG THỊNH HÀNH',
          style: TextStyle(
            color: Colors.white.withOpacity(0.3),
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: _tags
              .map((tag) => _HashtagChip(tag: tag, ctrl: ctrl))
              .toList(),
        ),
        const SizedBox(height: 24),
        const Divider(color: Color(0xFF1E1E1E)),
        const SizedBox(height: 16),
        // ── TikTok Shop Product Link Section ──────────────────────────────
        const _CaptionProductLinkSection(),
      ],
    ),
  );
}

class _CaptionProductLinkSection extends StatelessWidget {
  const _CaptionProductLinkSection();

  void _openProductPicker(BuildContext context) {
    final bloc = context.read<CreateVideoBloc>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BlocProvider.value(
        value: bloc,
        child: const _ProductPickerBottomSheet(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CreateVideoBloc, CreateVideoState>(
      builder: (ctx, state) {
        final picked = state is CreateVideoPickedFile ? state : null;
        final tagged = picked?.taggedProducts ?? const <Product>[];
        final vndFormat = NumberFormat.currency(locale: 'vi_VN', symbol: '₫');

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'GẮN LINK SẢN PHẨM (SHARECO SHOP)',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.3),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
                const Spacer(),
                if (tagged.isNotEmpty)
                  Text(
                    'Đã chọn ${tagged.length} sản phẩm',
                    style: const TextStyle(
                      color: Color(0xFFFF6B00),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () => _openProductPicker(ctx),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFFFF6B00).withOpacity(0.16),
                      const Color(0xFFFF2D55).withOpacity(0.12),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFFFF6B00).withOpacity(0.45),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFF6B00), Color(0xFFFF2D55)],
                        ),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: const Icon(
                        Icons.shopping_bag_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tagged.isEmpty
                                ? 'Thêm sản phẩm / Gắn link mua hàng'
                                : 'Thêm hoặc chỉnh sửa sản phẩm đã gắn',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Người xem có thể bấm vào link sản phẩm ngay dưới video',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.55),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.add_circle_outline_rounded,
                      color: Color(0xFFFF6B00),
                      size: 22,
                    ),
                  ],
                ),
              ),
            ),
            if (tagged.isNotEmpty) ...[
              const SizedBox(height: 12),
              ...tagged.map((product) {
                final imageUrl =
                    StorageImage.publicUrl(product.displayImagePath);
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF161616),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF2A2A2A)),
                  ),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          width: 48,
                          height: 48,
                          color: const Color(0xFF222222),
                          child: imageUrl != null
                              ? CachedNetworkImage(
                                  imageUrl: imageUrl,
                                  fit: BoxFit.cover,
                                  errorWidget: (_, __, ___) => const Icon(
                                    Icons.shopping_bag_outlined,
                                    color: Colors.white38,
                                  ),
                                )
                              : const Icon(
                                  Icons.shopping_bag_outlined,
                                  color: Colors.white38,
                                ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              product.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                Text(
                                  vndFormat.format(product.priceMin),
                                  style: const TextStyle(
                                    color: Color(0xFFFF6B00),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                if (product.shopName != null &&
                                    product.shopName!.isNotEmpty) ...[
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      '· ${product.shopName}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.45),
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => ctx
                            .read<CreateVideoBloc>()
                            .add(CreateVideoProductTagToggled(product)),
                        icon: const Icon(
                          Icons.close_rounded,
                          color: Colors.white54,
                          size: 18,
                        ),
                        tooltip: 'Gỡ sản phẩm',
                      ),
                    ],
                  ),
                );
              }),
            ],
          ],
        );
      },
    );
  }
}

// ─── Product Tag Tab & Picker Sheet ───────────────────────────────────────────

class _ProductTagTab extends StatelessWidget {
  const _ProductTagTab();

  @override
  Widget build(BuildContext context) {
    return const _ProductSelectorView(isBottomSheet: false);
  }
}

class _ProductPickerBottomSheet extends StatelessWidget {
  const _ProductPickerBottomSheet();

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height * 0.82;
    return Container(
      height: height,
      decoration: const BoxDecoration(
        color: Color(0xFF121212),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF6B00), Color(0xFFFF2D55)],
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.shopping_bag_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Gắn sản phẩm vào video',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                BlocBuilder<CreateVideoBloc, CreateVideoState>(
                  builder: (ctx, state) {
                    final count = state is CreateVideoPickedFile
                        ? state.taggedProducts.length
                        : 0;
                    return TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        backgroundColor: const Color(0xFFFF6B00),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 6),
                      ),
                      child: Text(
                        count > 0 ? 'Xong ($count)' : 'Đóng',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFF222222)),
          const Expanded(
            child: _ProductSelectorView(isBottomSheet: true),
          ),
        ],
      ),
    );
  }
}

class _ProductSelectorView extends StatefulWidget {
  final bool isBottomSheet;
  const _ProductSelectorView({required this.isBottomSheet});

  @override
  State<_ProductSelectorView> createState() => _ProductSelectorViewState();
}

class _ProductSelectorViewState extends State<_ProductSelectorView> {
  final _searchCtrl = TextEditingController();
  Timer? _debounce;
  List<Product> _products = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchProducts();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchProducts({String? query}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final getProducts = sl<GetProductsUseCase>();
    final res = await getProducts(limit: 40, search: query);
    if (!mounted) return;
    res.fold(
      (f) => setState(() {
        _loading = false;
        _error = f.message;
      }),
      (items) => setState(() {
        _loading = false;
        _products = items;
      }),
    );
  }

  void _onSearchChanged(String val) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      _fetchProducts(query: val.trim());
    });
  }

  @override
  Widget build(BuildContext context) {
    final vndFormat = NumberFormat.currency(locale: 'vi_VN', symbol: '₫');

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            controller: _searchCtrl,
            onChanged: _onSearchChanged,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Tìm sản phẩm để gắn link vào video...',
              hintStyle: TextStyle(
                color: Colors.white.withOpacity(0.35),
                fontSize: 13,
              ),
              prefixIcon: const Icon(
                Icons.search_rounded,
                color: Colors.white54,
                size: 20,
              ),
              suffixIcon: _searchCtrl.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded,
                          color: Colors.white54, size: 18),
                      onPressed: () {
                        _searchCtrl.clear();
                        _fetchProducts();
                      },
                    )
                  : null,
              filled: true,
              fillColor: const Color(0xFF1A1A1A),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFF2C2C2C)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFF2C2C2C)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFFF6B00)),
              ),
            ),
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(
                    color: Color(0xFFFF6B00),
                    strokeWidth: 2,
                  ),
                )
              : _error != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.error_outline_rounded,
                                color: Colors.white38, size: 40),
                            const SizedBox(height: 10),
                            Text(
                              'Không tải được danh sách sản phẩm:\n$_error',
                              style: const TextStyle(
                                  color: Colors.white54, fontSize: 13),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 12),
                            TextButton(
                              onPressed: () =>
                                  _fetchProducts(query: _searchCtrl.text),
                              child: const Text('Thử lại',
                                  style: TextStyle(color: Color(0xFFFF6B00))),
                            ),
                          ],
                        ),
                      ),
                    )
                  : _products.isEmpty
                      ? const Center(
                          child: Text(
                            'Không tìm thấy sản phẩm phù hợp',
                            style:
                                TextStyle(color: Colors.white54, fontSize: 13),
                          ),
                        )
                      : BlocBuilder<CreateVideoBloc, CreateVideoState>(
                          builder: (ctx, state) {
                            final tagged = state is CreateVideoPickedFile
                                ? state.taggedProducts
                                : const <Product>[];
                            final taggedIds = {
                              for (final p in tagged) p.id,
                            };

                            return ListView.separated(
                              padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                              itemCount: _products.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 8),
                              itemBuilder: (_, i) {
                                final product = _products[i];
                                final isSelected =
                                    taggedIds.contains(product.id);
                                final imageUrl = StorageImage.publicUrl(
                                    product.displayImagePath);

                                return InkWell(
                                  borderRadius: BorderRadius.circular(12),
                                  onTap: () => ctx
                                      .read<CreateVideoBloc>()
                                      .add(CreateVideoProductTagToggled(
                                          product)),
                                  child: Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? const Color(0xFFFF6B00)
                                              .withOpacity(0.1)
                                          : const Color(0xFF161616),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: isSelected
                                            ? const Color(0xFFFF6B00)
                                            : const Color(0xFF262626),
                                        width: isSelected ? 1.5 : 1,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          child: Container(
                                            width: 56,
                                            height: 56,
                                            color: const Color(0xFF222222),
                                            child: imageUrl != null
                                                ? CachedNetworkImage(
                                                    imageUrl: imageUrl,
                                                    fit: BoxFit.cover,
                                                    errorWidget: (_, __, ___) =>
                                                        const Icon(
                                                      Icons
                                                          .shopping_bag_outlined,
                                                      color: Colors.white38,
                                                    ),
                                                  )
                                                : const Icon(
                                                    Icons.shopping_bag_outlined,
                                                    color: Colors.white38,
                                                  ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                product.title,
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Row(
                                                children: [
                                                  Text(
                                                    vndFormat.format(
                                                        product.priceMin),
                                                    style: const TextStyle(
                                                      color: Color(0xFFFF6B00),
                                                      fontSize: 13,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                                  ),
                                                  if (product.shopName !=
                                                          null &&
                                                      product.shopName!
                                                          .isNotEmpty) ...[
                                                    const SizedBox(width: 6),
                                                    Flexible(
                                                      child: Text(
                                                        '· ${product.shopName}',
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                        style: TextStyle(
                                                          color: Colors.white
                                                              .withOpacity(0.4),
                                                          fontSize: 11,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 12, vertical: 7),
                                          decoration: BoxDecoration(
                                            gradient: isSelected
                                                ? null
                                                : const LinearGradient(
                                                    colors: [
                                                      Color(0xFFFF6B00),
                                                      Color(0xFFFF2D55),
                                                    ],
                                                  ),
                                            color: isSelected
                                                ? const Color(0xFF2A2A2A)
                                                : null,
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                isSelected
                                                    ? Icons.check_rounded
                                                    : Icons.add_link_rounded,
                                                color: Colors.white,
                                                size: 15,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                isSelected
                                                    ? 'Đã gắn'
                                                    : 'Gắn link',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
        ),
      ],
    );
  }
}

class _HashtagChip extends StatelessWidget {
  final String tag;
  final TextEditingController ctrl;

  const _HashtagChip({required this.tag, required this.ctrl});

  void _appendTag() {
    final t = ctrl.text;
    ctrl.text =
    '$t${t.isEmpty || t.endsWith(' ') ? '' : ' '}$tag ';
    ctrl.selection =
        TextSelection.fromPosition(TextPosition(offset: ctrl.text.length));
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: _appendTag,
    child: Container(
      padding:
      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.primary.withOpacity(0.25),
        ),
      ),
      child: Text(
        tag,
        style: TextStyle(
          color: AppColors.primary.withOpacity(0.9),
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    ),
  );
}

// ─── Thumbnail tab ─────────────────────────────────────────────────────────────

class _ThumbnailTab extends StatelessWidget {
  const _ThumbnailTab();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CreateVideoBloc, CreateVideoState>(
      builder: (ctx, state) {
        final picked = state is CreateVideoPickedFile ? state : null;
        final currentThumbnail = picked?.thumbnailPath;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ẢNH BÌA',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.3),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 12),

              // Thumbnail preview + pick buttons
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Preview
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      width: 100,
                      height: 140,
                      color: const Color(0xFF141414),
                      child: _buildThumbnailPreview(currentThumbnail),
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Actions
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Chọn ảnh bìa thu hút người xem',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Ảnh bìa đẹp có thể tăng lượt xem lên đến 3 lần',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.4),
                            fontSize: 12,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _ThumbnailButton(
                          icon: Icons.photo_library_outlined,
                          label: 'Tải từ thư viện',
                          onTap: () async {
                            final file = await ImagePicker()
                                .pickImage(source: ImageSource.gallery);
                            if (file != null && ctx.mounted) {
                              ctx.read<CreateVideoBloc>().add(
                                CreateVideoThumbnailChanged(
                                  thumbnailPath: file.path,
                                ),
                              );
                            }
                          },
                        ),
                        const SizedBox(height: 8),
                        _ThumbnailButton(
                          icon: Icons.camera_alt_outlined,
                          label: 'Chụp ảnh',
                          onTap: () async {
                            final file = await ImagePicker()
                                .pickImage(source: ImageSource.camera);
                            if (file != null && ctx.mounted) {
                              ctx.read<CreateVideoBloc>().add(
                                CreateVideoThumbnailChanged(
                                  thumbnailPath: file.path,
                                ),
                              );
                            }
                          },
                        ),
                        if (currentThumbnail != null &&
                            currentThumbnail.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          _ThumbnailButton(
                            icon: Icons.close_rounded,
                            label: 'Xóa ảnh bìa',
                            isDestructive: true,
                            onTap: () => ctx
                                .read<CreateVideoBloc>()
                                .add(const CreateVideoThumbnailChanged(
                                thumbnailPath: '')),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),
              const Divider(color: Color(0xFF1E1E1E)),
              const SizedBox(height: 16),

              // Tips
              Text(
                'MẸO',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.3),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 10),
              ..._tips.map((tip) => _TipRow(tip: tip)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildThumbnailPreview(String? path) {
    if (path != null && path.isNotEmpty) {
      final file = File(path);
      if (file.existsSync()) {
        return Image.file(file, fit: BoxFit.cover);
      }
    }
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.image_outlined,
          color: Colors.white.withOpacity(0.2),
          size: 28,
        ),
        const SizedBox(height: 6),
        Text(
          'Chưa có ảnh bìa',
          style: TextStyle(
            color: Colors.white.withOpacity(0.25),
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  static const _tips = [
    'Sử dụng ảnh sáng và có độ tương phản cao',
    'Có khuôn mặt sẽ thu hút nhiều lượt nhấn hơn',
    'Hiển thị khoảnh khắc hấp dẫn nhất',
    'Tránh quá nhiều chữ trên ảnh bìa',
  ];
}

class _ThumbnailButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDestructive;

  const _ThumbnailButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding:
      const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: isDestructive
            ? Colors.red.withOpacity(0.08)
            : const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDestructive
              ? Colors.red.withOpacity(0.2)
              : const Color(0xFF2A2A2A),
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: isDestructive
                ? Colors.redAccent
                : Colors.white54,
            size: 16,
          ),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(
              color: isDestructive
                  ? Colors.redAccent
                  : Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    ),
  );
}

class _TipRow extends StatelessWidget {
  final String tip;
  const _TipRow({required this.tip});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      children: [
        Container(
          width: 4,
          height: 4,
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.6),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            tip,
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ),
      ],
    ),
  );
}

// ─── Settings tab ──────────────────────────────────────────────────────────────

class _SettingsTab extends StatelessWidget {
  const _SettingsTab();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CreateVideoBloc, CreateVideoState>(
      builder: (ctx, state) {
        final picked = state is CreateVideoPickedFile ? state : null;
        if (picked == null) return const SizedBox.shrink();

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _SectionLabel('Ai có thể xem'),
            const SizedBox(height: 10),
            ...[
              ('public', Icons.public_rounded, 'Mọi người',
              'Hiển thị với tất cả người dùng'),
              ('followers', Icons.people_outline_rounded, 'Chỉ người theo dõi',
              'Chỉ những người theo dõi bạn'),
              ('private', Icons.lock_outline_rounded, 'Chỉ mình tôi',
              'Chỉ bạn mới có thể xem'),
            ].map(
                  (o) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _VisibilityTile(
                  icon: o.$2,
                  label: o.$3,
                  subtitle: o.$4,
                  selected: picked.visibility == o.$1,
                  onTap: () => ctx
                      .read<CreateVideoBloc>()
                      .add(CreateVideoVisibilityChanged(o.$1)),
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Divider(color: Color(0xFF1E1E1E)),
            const SizedBox(height: 8),
            _SectionLabel('Tương tác'),
            const SizedBox(height: 10),
            _ToggleRow(
              icon: Icons.chat_bubble_outline_rounded,
              label: 'Cho phép bình luận',
              value: picked.allowComment,
              onChanged: (v) => ctx.read<CreateVideoBloc>().add(
                CreateVideoSettingChanged(allowComment: v),
              ),
            ),
            _ToggleRow(
              icon: Icons.people_alt_outlined,
              label: 'Cho phép duet',
              value: picked.allowDuet,
              onChanged: (v) => ctx.read<CreateVideoBloc>().add(
                CreateVideoSettingChanged(allowDuet: v),
              ),
            ),
            _ToggleRow(
              icon: Icons.cut_outlined,
              label: 'Cho phép stitch',
              value: picked.allowStitch,
              onChanged: (v) => ctx.read<CreateVideoBloc>().add(
                CreateVideoSettingChanged(allowStitch: v),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(
    text.toUpperCase(),
    style: TextStyle(
      color: Colors.white.withOpacity(0.3),
      fontSize: 10,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.2,
    ),
  );
}

class _VisibilityTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _VisibilityTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: selected
            ? AppColors.primary.withOpacity(0.08)
            : const Color(0xFF141414),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: selected
              ? AppColors.primary.withOpacity(0.5)
              : const Color(0xFF2A2A2A),
          width: selected ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: selected
                  ? AppColors.primary.withOpacity(0.15)
                  : Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: selected ? AppColors.primary : Colors.white38,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: selected ? Colors.white : Colors.white70,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.3),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          if (selected)
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_rounded,
                color: Colors.white,
                size: 13,
              ),
            )
          else
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white24),
              ),
            ),
        ],
      ),
    ),
  );
}

class _ToggleRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(
      children: [
        Icon(icon, color: Colors.white38, size: 18),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
            ),
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeColor: AppColors.primary,
          inactiveThumbColor: Colors.white38,
          inactiveTrackColor: Colors.white12,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ],
    ),
  );
}