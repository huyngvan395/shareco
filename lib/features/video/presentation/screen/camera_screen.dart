// features/video/presentation/screen/camera_screen.dart

import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shareco/core/services/video/video_processing_services.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../di/injector.dart';
import '../../data/datasources/music_search_service.dart';
import '../../domain/entities/filter_entity.dart';
import '../bloc/camera_bloc.dart';
import '../bloc/camera_event.dart';
import '../bloc/camera_state.dart';
import '../bloc/create_video_bloc.dart';
import '../widgets/camera_controls.dart';
import 'livestream_screen.dart';
import 'video_edit_screen.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});
  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  late final CameraBloc _bloc;
  RecordMode _mode = RecordMode.camera;
  bool _showSpeedBar = false;
  final AudioPlayer _bgMusicPlayer = AudioPlayer();
  String? _preloadedMusicUrl;
  Timer? _audioKeepAliveTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    MusicSearchService.prefetchAllCategories();
    _bloc = sl<CameraBloc>()..add(const CameraInitRequested());
  }

  @override
  void dispose() {
    _audioKeepAliveTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _bgMusicPlayer.dispose();
    _bloc.close();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive) {
      _bgMusicPlayer.pause();
      _bloc.add(const CameraDisposed());
    } else if (state == AppLifecycleState.resumed) {
      _bloc.add(const CameraInitRequested());
    }
  }

  /// Tải trước (preload) bài hát ngay khi người dùng chọn trong Kho nhạc
  /// để khi bấm nút Quay là nhạc phát tức thì (0ms trễ) giống TikTok.
  Future<void> _preloadMusicTrack(MusicTrack? track) async {
    final url = track?.previewUrl;
    if (url == null || url.isEmpty) {
      _preloadedMusicUrl = null;
      await _bgMusicPlayer.stop();
      return;
    }

    if (_preloadedMusicUrl == url) return;
    _preloadedMusicUrl = url;

    try {
      await _bgMusicPlayer.setUrl(url);
      await _bgMusicPlayer.setLoopMode(LoopMode.one);
      await _bgMusicPlayer.setVolume(1.0);
      await _bgMusicPlayer.seek(Duration.zero);
      await _bgMusicPlayer.pause();
    } catch (_) {}
  }

  /// Đồng bộ phát nhạc nền ngay trong lúc quay video
  Future<void> _syncRecordingMusic(CameraState state) async {
    final track = state.selectedMusic;
    final url = track?.previewUrl;
    if (url == null || url.isEmpty) {
      _audioKeepAliveTimer?.cancel();
      await _bgMusicPlayer.stop();
      return;
    }

    try {
      if (_preloadedMusicUrl != url) {
        _preloadedMusicUrl = url;
        await _bgMusicPlayer.setUrl(url);
        await _bgMusicPlayer.setLoopMode(LoopMode.one);
        await _bgMusicPlayer.setVolume(1.0);
      }

      if (state.isRecording && !state.isPaused) {
        if (!_bgMusicPlayer.playing) {
          await _bgMusicPlayer.play();
        }
        // Đảm bảo Android/iOS Camera AudioSession không ngắt nhạc khi vừa mở mic quay
        _audioKeepAliveTimer?.cancel();
        _audioKeepAliveTimer = Timer.periodic(
          const Duration(milliseconds: 350),
          (t) {
            if (!mounted ||
                !_bloc.state.isRecording ||
                _bloc.state.isPaused) {
              t.cancel();
              return;
            }
            if (!_bgMusicPlayer.playing) {
              _bgMusicPlayer.play();
            }
          },
        );
      } else if (state.isRecording && state.isPaused) {
        _audioKeepAliveTimer?.cancel();
        await _bgMusicPlayer.pause();
      } else {
        _audioKeepAliveTimer?.cancel();
        await _bgMusicPlayer.pause();
        await _bgMusicPlayer.seek(Duration.zero);
      }
    } catch (_) {}
  }

  VideoEffectMeta _buildEffectMetaFromCamera(CameraState st) {
    double getBeautyVal(String id) {
      for (final e in st.beautyEffects) {
        if (e.id == id) return e.value;
      }
      return 0.0;
    }

    return VideoEffectMeta(
      filterId: st.activeFilter.id,
      musicId: st.selectedMusic?.id,
      customMusic: st.selectedMusic,
      playbackSpeed: st.activeSpeed.value,
      beautyEnabled: st.beautyEnabled,
      beautySmooth: getBeautyVal('smooth'),
      beautyWhiten: getBeautyVal('whiten'),
      beautySlim: getBeautyVal('slim'),
      beautyEyes: getBeautyVal('eyes'),
      textOverlays: List.of(st.textOverlays),
      stickers: List.of(st.stickers),
    );
  }

  Future<void> _pickFromGallery() async {
    final file = await ImagePicker().pickVideo(
      source: ImageSource.gallery,
      maxDuration: const Duration(minutes: 10),
    );

    if (file == null || !mounted) return;

    final thumbnail = await VideoProcessingService.generateThumbnail(file.path);
    if (!mounted) return;

    final initialEffects = _buildEffectMetaFromCamera(_bloc.state);

    _audioKeepAliveTimer?.cancel();
    await _bgMusicPlayer.stop();
    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => BlocProvider(
          create: (_) => sl<CreateVideoBloc>(),
          child: VideoEditScreen(
            localVideoPath: file.path,
            thumbnailPath: thumbnail ?? '',
            initialEffects: initialEffects,
          ),
        ),
      ),
    );
  }

  void _onRecordingDone(CameraState state) {
    final videoPath = state.recordedFilePath;
    if (videoPath == null) return;

    _audioKeepAliveTimer?.cancel();
    _bgMusicPlayer.stop();

    final initialEffects = _buildEffectMetaFromCamera(state);

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => BlocProvider(
          create: (_) => sl<CreateVideoBloc>(),
          child: VideoEditScreen(
            localVideoPath: videoPath,
            thumbnailPath: state.thumbnailPath ?? '',
            initialEffects: initialEffects,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _bloc,
      child: BlocConsumer<CameraBloc, CameraState>(
        listenWhen: (p, c) =>
            (p.recordedFilePath != c.recordedFilePath &&
                c.recordedFilePath != null) ||
            p.isRecording != c.isRecording ||
            p.isPaused != c.isPaused ||
            p.selectedMusic != c.selectedMusic ||
            p.errorMessage != c.errorMessage,
        listener: (ctx, state) {
          if (!state.isRecording) {
            _preloadMusicTrack(state.selectedMusic);
          }
          _syncRecordingMusic(state);

          if (state.recordedFilePath != null && !state.isRecording) {
            _onRecordingDone(state);
          }
          if (state.errorMessage != null) {
            ScaffoldMessenger.of(ctx).showSnackBar(
              SnackBar(
                content: Text(state.errorMessage!),
                backgroundColor: Colors.redAccent,
              ),
            );
          }
        },
        builder: (ctx, state) => Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            fit: StackFit.expand,
            children: [
              // 1. Camera Preview với Bộ lọc màu + Làm đẹp thời gian thực (Mịn da, Sáng da, Thon gọn, Mắt to)
              _buildPreview(state),

              // 2. Stickers & Text Overlays
              const StickersOverlay(),
              const TextOverlaysLayer(),

              // 3. Top Bar: Nút Đóng + Viên thuốc Chọn Nhạc
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: CameraTopBar(
                  onClose: () => Navigator.of(context).pop(),
                  onOpenMusic: () => CameraRightToolbar.showMusicSheet(ctx),
                ),
              ),

              // 4. Thanh công cụ dọc bên phải
              Positioned(
                right: 12,
                top: MediaQuery.of(context).padding.top + 68,
                child: CameraRightToolbar(
                  showSpeedBar: _showSpeedBar,
                  onToggleSpeedBar: () =>
                      setState(() => _showSpeedBar = !_showSpeedBar),
                ),
              ),

              // 5. Cụm điều khiển phía dưới gọn gàng
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: _buildCleanBottomSection(ctx, state),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPreview(CameraState state) {
    if (!state.isInitialized || state.controller == null) {
      return Container(
        color: const Color(0xFF0D0D0D),
        child: const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation(AppColors.primary),
          ),
        ),
      );
    }

    Widget preview = SizedBox.expand(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: state.controller!.value.previewSize!.height,
          height: state.controller!.value.previewSize!.width,
          child: CameraPreview(state.controller!),
        ),
      ),
    );

    // Áp dụng hiệu ứng Làm đẹp thực tế (Mịn da, Sáng da, Thon gọn, Mắt to)
    preview = BeautyEffectProcessor.fromEffects(
      enabled: state.beautyEnabled,
      effects: state.beautyEffects,
      child: preview,
    );

    // Áp dụng Bộ lọc màu + Hiệu ứng ánh sáng (1994, Soft Bloom, AR, Mini Game)
    preview = VideoFilterEffectRenderer(
      filter: state.activeFilter,
      child: preview,
    );
    return preview;
  }

  Widget _buildCleanBottomSection(BuildContext context, CameraState state) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).padding.bottom + 14,
        top: 20,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Colors.black87, Colors.black45, Colors.transparent],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const RecordingProgressBar(),

          if (_showSpeedBar && !state.isRecording) ...[
            const SpeedSelector(),
            const SizedBox(height: 12),
          ],

          if (!state.isRecording) ...[
            const DurationLimitSelector(),
            const SizedBox(height: 14),
          ] else
            const SizedBox(height: 12),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Bên trái: Mở nhanh Bộ lọc màu & Hiệu ứng
                SizedBox(
                  width: 68,
                  child: state.isRecording && !state.isPaused
                      ? const SizedBox.shrink()
                      : GestureDetector(
                          onTap: () =>
                              CameraRightToolbar.showFilterSheet(context),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              state.activeFilter.id != 'none'
                                  ? FilterThumbnailBox(
                                      filter: state.activeFilter,
                                      size: 44,
                                      selected: true,
                                      borderRadius: 12,
                                    )
                                  : Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(
                                          colors: [
                                            Color(0xFFFF2D55),
                                            Color(0xFF7F00FF),
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: Colors.white,
                                          width: 1.5,
                                        ),
                                      ),
                                      child: const Icon(
                                        Icons.auto_awesome_rounded,
                                        color: Colors.white,
                                        size: 22,
                                      ),
                                    ),
                              const SizedBox(height: 5),
                              Text(
                                state.activeFilter.id != 'none'
                                    ? state.activeFilter.name
                                    : 'Hiệu ứng',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                ),

                // Ở giữa: Nút Quay — Khi bấm Quay sẽ phát nhạc nền ngay lập tức
                RecordButton(
                  onStart: () async {
                    if (state.selectedMusic?.previewUrl != null) {
                      try {
                        await _bgMusicPlayer.seek(Duration.zero);
                        _bgMusicPlayer.play();
                      } catch (_) {}
                    }
                    if (context.mounted) {
                      context
                          .read<CameraBloc>()
                          .add(const CameraRecordStarted());
                    }
                  },
                  onStop: () {
                    _audioKeepAliveTimer?.cancel();
                    _bgMusicPlayer.pause();
                    context.read<CameraBloc>().add(const CameraRecordStopped());
                  },
                  onPause: () {
                    _audioKeepAliveTimer?.cancel();
                    _bgMusicPlayer.pause();
                    context.read<CameraBloc>().add(const CameraRecordPaused());
                  },
                  onResume: () {
                    if (state.selectedMusic?.previewUrl != null) {
                      _bgMusicPlayer.play();
                    }
                    context.read<CameraBloc>().add(const CameraRecordResumed());
                  },
                ),

                // Bên phải: Nút Tiếp tục (khi đang quay/tạm dừng) hoặc Tải lên từ Thư viện
                SizedBox(
                  width: 68,
                  child: state.isRecording
                      ? GestureDetector(
                          onTap: () {
                            _audioKeepAliveTimer?.cancel();
                            _bgMusicPlayer.stop();
                            context
                                .read<CameraBloc>()
                                .add(const CameraRecordStopped());
                          },
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: const BoxDecoration(
                                  color: AppColors.primary,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.check_rounded,
                                  color: Colors.white,
                                  size: 26,
                                ),
                              ),
                              const SizedBox(height: 5),
                              const Text(
                                'Tiếp tục',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        )
                      : GestureDetector(
                          onTap: _pickFromGallery,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.white70,
                                    width: 1.5,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.photo_library_rounded,
                                  color: Colors.white,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(height: 5),
                              const Text(
                                'Tải lên',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
              ],
            ),
          ),

          if (!state.isRecording) ...[
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                (RecordMode.camera, 'Máy ảnh'),
                (RecordMode.upload, 'Tải lên'),
                (RecordMode.live, 'LIVE'),
              ].map((m) {
                final active = _mode == m.$1;
                return GestureDetector(
                  onTap: () {
                    setState(() => _mode = m.$1);
                    if (m.$1 == RecordMode.upload) _pickFromGallery();
                    if (m.$1 == RecordMode.live) {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          fullscreenDialog: true,
                          builder: (_) => LivestreamScreen(
                            channelName:
                                'live_${DateTime.now().millisecondsSinceEpoch}',
                            isHost: true,
                          ),
                        ),
                      );
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          m.$2,
                          style: TextStyle(
                            color: active ? Colors.white : Colors.white54,
                            fontWeight: active
                                ? FontWeight.w700
                                : FontWeight.w400,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 4),
                        if (active)
                          Container(
                            width: 18,
                            height: 2.5,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}
