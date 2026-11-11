// features/feed/presentation/widgets/video_item.dart

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:just_audio/just_audio.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shareco/features/comment/presentation/screen/comment_sheet.dart';
import 'package:video_player/video_player.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/helpers/require_auth.dart';
import '../../../../core/navigation/app_route_observer.dart';
import '../../../../core/services/saved_videos_service.dart';
import '../../../../core/services/supabase/index.dart';
import '../../../../core/utils/storage_image.dart';
import '../../../../core/utils/video_controller_cache.dart';
import '../../../../di/injector.dart';
import '../../../../routes/app_router.dart';
import '../../../../shared/widgets/report_bottom_sheet.dart';
import '../../../chat/domain/usecases/chat_usecases.dart';
import '../../../ecommerce/product/domain/entities/product.dart';
import '../../../video/domain/entities/filter_entity.dart';
import '../../../video/domain/entities/video_entity.dart';
import '../bloc/feed_bloc.dart';
import '../bloc/feed_event.dart';

class VideoItem extends StatefulWidget {
  final VideoEntity video;
  final bool isActive;
  final bool shouldPrepare;
  final VideoControllerCache? cache;
  final Future<VideoPlayerController>? controllerFuture;

  const VideoItem({
    super.key,
    required this.video,
    required this.isActive,
    this.shouldPrepare = true,
    this.cache,
    this.controllerFuture,
  });

  @override
  State<VideoItem> createState() => _VideoItemState();
}

class _VideoItemState extends State<VideoItem>
    with SingleTickerProviderStateMixin {
  VideoPlayerController? _ctrl;
  AudioPlayer? _bgMusicPlayer;
  String? _loadedMusicUrl;
  late VideoEffectMeta _fx;
  bool _initialized = false;
  bool _hasFirstFrame = false;
  bool _ownsController = false;
  bool _acquiredFromCache = false;
  String? _acquiredPath;
  int _attachGeneration = 0;
  Duration _savedPosition = Duration.zero;
  Object? _initError;
  bool _isMuted = false;
  bool _showPlayIcon = false;
  int _localShareBonus = 0;

  late AnimationController _heartCtrl;
  late Animation<double> _heartScale;
  late Animation<double> _heartFade;
  bool _showHeart = false;

  bool get _hasUsableController =>
      _initialized &&
      _ctrl != null &&
      !VideoControllerCache.isControllerDisposed(_ctrl) &&
      _ctrl!.value.isInitialized;

  @override
  void initState() {
    super.initState();
    _fx = VideoEffectMeta.fromVideoPath(widget.video.videoPath);
    routeObserver.addRouteListener(_onRouteObserverEvent);
    _heartCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _heartScale = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.3), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.3, end: 1.0), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 40),
    ]).animate(CurvedAnimation(parent: _heartCtrl, curve: Curves.easeOut));
    _heartFade = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 30),
    ]).animate(_heartCtrl);

    if (widget.isActive || widget.shouldPrepare) {
      _attachController();
    }
  }

  Future<void> _attachController() async {
    if (_ctrl != null && !VideoControllerCache.isControllerDisposed(_ctrl)) {
      _syncPlaybackState();
      return;
    }

    final gen = ++_attachGeneration;
    final path = widget.video.videoPath;

    try {
      VideoPlayerController resolved;
      bool acquired = false;
      bool owned = false;

      if (widget.cache != null) {
        resolved = await widget.cache!.acquire(path);
        acquired = true;
      } else if (widget.controllerFuture != null) {
        resolved = await widget.controllerFuture!;
      } else {
        final url = StorageImage.videoUrl(path);
        resolved = VideoPlayerController.networkUrl(
          Uri.parse(url),
          videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
        );
        owned = true;
        await resolved.initialize();
      }

      if (!mounted ||
          gen != _attachGeneration ||
          (!widget.isActive && !widget.shouldPrepare)) {
        if (acquired) {
          widget.cache?.release(path);
        } else if (owned) {
          await resolved.dispose();
        }
        return;
      }

      if (VideoControllerCache.isControllerDisposed(resolved)) {
        if (acquired) widget.cache?.release(path);
        return;
      }

      _ctrl = resolved;
      _acquiredFromCache = acquired;
      _acquiredPath = acquired ? path : null;
      _ownsController = owned;

      await resolved.setLooping(true);
      await resolved.setVolume(_isMuted ? 0 : _fx.originalVolume);
      if ((_fx.playbackSpeed - 1.0).abs() > 0.01) {
        try {
          await resolved.setPlaybackSpeed(_fx.playbackSpeed);
        } catch (_) {}
      }

      if (_savedPosition > Duration.zero &&
          resolved.value.duration > _savedPosition) {
        try {
          await resolved.seekTo(_savedPosition);
        } catch (_) {}
      }

      final alreadyReady = resolved.value.isInitialized &&
          (resolved.value.position > Duration.zero ||
              resolved.value.size.width > 0);
      if (!alreadyReady) {
        resolved.addListener(_onControllerUpdate);
      }

      if (!mounted || gen != _attachGeneration) return;
      setState(() {
        _initialized = true;
        _hasFirstFrame = alreadyReady;
        _initError = null;
      });

      await _syncPlaybackState();

      if (!alreadyReady) {
        Future.delayed(const Duration(milliseconds: 1200), () {
          if (mounted &&
              gen == _attachGeneration &&
              !_hasFirstFrame &&
              _hasUsableController) {
            setState(() => _hasFirstFrame = true);
            _ctrl?.removeListener(_onControllerUpdate);
          }
        });
      }
    } catch (e) {
      if (!mounted || gen != _attachGeneration) return;
      setState(() => _initError = e);
    }
  }

  void _onRouteObserverEvent() {
    if (!mounted) return;
    _syncPlaybackState();
  }

  Future<void> _syncPlaybackState() async {
    final ctrl = _ctrl;
    if (ctrl == null || VideoControllerCache.isControllerDisposed(ctrl)) return;
    try {
      final isRouteActive = ModalRoute.of(context)?.isCurrent ?? true;
      if (mounted && widget.isActive && isRouteActive) {
        await ctrl.setVolume(_isMuted ? 0 : _fx.originalVolume);
        await ctrl.play();
        await _syncBgMusic(shouldPlay: true);
        final stillActive = ModalRoute.of(context)?.isCurrent ?? true;
        if (!mounted || !widget.isActive || !stillActive) {
          await ctrl.pause();
          await _syncBgMusic(shouldPlay: false);
        }
      } else {
        await ctrl.pause();
        await _syncBgMusic(shouldPlay: false);
      }
      if (mounted) setState(() {});
    } catch (_) {}
  }

  Future<void> _syncBgMusic({required bool shouldPlay}) async {
    final track = _fx.music;
    final url = track?.previewUrl;
    if (url == null || url.isEmpty) {
      await _bgMusicPlayer?.pause();
      return;
    }

    try {
      if (!shouldPlay) {
        await _bgMusicPlayer?.pause();
        return;
      }

      _bgMusicPlayer ??= AudioPlayer();
      if (_loadedMusicUrl != url) {
        _loadedMusicUrl = url;
        await _bgMusicPlayer!.setUrl(url);
        await _bgMusicPlayer!.setLoopMode(LoopMode.one);
      }
      await _bgMusicPlayer!.setVolume(_isMuted ? 0 : _fx.musicVolume);
      await _bgMusicPlayer!.play();
    } catch (_) {}
  }

  void _detachController({bool notifyUi = true}) {
    _attachGeneration++;
    final ctrl = _ctrl;
    if (ctrl == null) return;

    if (!VideoControllerCache.isControllerDisposed(ctrl)) {
      try {
        _savedPosition = ctrl.value.position;
      } catch (_) {}
      try {
        ctrl.removeListener(_onControllerUpdate);
      } catch (_) {}
      try {
        ctrl.pause();
      } catch (_) {}
    }

    final acquired = _acquiredFromCache;
    final path = _acquiredPath;
    final owned = _ownsController;

    // Gỡ tham chiếu khỏi State TRƯỚC KHI giải phóng để tránh lỗi ValueNotifier used after dispose
    _ctrl = null;
    _initialized = false;
    _hasFirstFrame = false;
    _acquiredFromCache = false;
    _acquiredPath = null;
    _ownsController = false;

    if (notifyUi && mounted) {
      setState(() {});
    }

    if (acquired && path != null) {
      widget.cache?.release(path);
    } else if (owned && !VideoControllerCache.isControllerDisposed(ctrl)) {
      ctrl.dispose();
    }
  }

  @override
  void didUpdateWidget(VideoItem old) {
    super.didUpdateWidget(old);

    if (widget.video.videoPath != old.video.videoPath) {
      _fx = VideoEffectMeta.fromVideoPath(widget.video.videoPath);
      _savedPosition = Duration.zero;
      _bgMusicPlayer?.stop();
      _loadedMusicUrl = null;
      _detachController(notifyUi: false);
      if (widget.isActive || widget.shouldPrepare) {
        _attachController();
      }
      return;
    }

    final wantsController = widget.isActive || widget.shouldPrepare;
    if (!wantsController) {
      if (_ctrl != null) {
        _detachController();
      }
      return;
    }

    if (_ctrl == null || VideoControllerCache.isControllerDisposed(_ctrl)) {
      _attachController();
      return;
    }

    if (widget.isActive != old.isActive) {
      _syncPlaybackState();
    }
  }

  void _onControllerUpdate() {
    if (!mounted || _hasFirstFrame) return;
    final ctrl = _ctrl;
    if (ctrl == null || VideoControllerCache.isControllerDisposed(ctrl)) return;
    final value = ctrl.value;
    if (value.isInitialized &&
        (value.isPlaying ||
            value.position > Duration.zero ||
            value.isBuffering ||
            value.size.width > 0)) {
      setState(() => _hasFirstFrame = true);
      ctrl.removeListener(_onControllerUpdate);
    }
  }

  @override
  void dispose() {
    routeObserver.removeRouteListener(_onRouteObserverEvent);
    _bgMusicPlayer?.dispose();
    _detachController(notifyUi: false);
    _heartCtrl.dispose();
    super.dispose();
  }

  void _safeToggleVideoLike(String videoId) {
    try {
      context.read<FeedBloc>().add(FeedVideoLikeToggled(videoId));
    } catch (_) {}
  }

  void _onDoubleTap() {
    if (!widget.video.isLiked) {
      context.requireAuth(() => _safeToggleVideoLike(widget.video.id));
    }
    setState(() => _showHeart = true);
    _heartCtrl.forward(from: 0).then((_) {
      if (mounted) setState(() => _showHeart = false);
    });
  }

  void _onTap() {
    if (!_hasUsableController) return;
    try {
      final wasPlaying = _ctrl!.value.isPlaying;
      if (wasPlaying) {
        _ctrl!.pause();
        _bgMusicPlayer?.pause();
      } else {
        _ctrl!.play();
        _syncBgMusic(shouldPlay: true);
      }
      if (!wasPlaying) {
        setState(() => _showPlayIcon = true);
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) setState(() => _showPlayIcon = false);
        });
      } else {
        setState(() {});
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final usable = _hasUsableController;
    return GestureDetector(
      onDoubleTap: _onDoubleTap,
      onTap: _onTap,
      child: SizedBox(
        width: size.width,
        height: size.height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            _buildVideo(usable),
            _buildGradient(),
            _buildRightBar(usable),
            _buildBottomInfo(),
            if (usable) _buildPlayIcon(),
            if (_showHeart) _buildFloatingHeart(),
            _buildMuteBtn(),
            if (usable) _buildProgress(),
          ],
        ),
      ),
    );
  }

  Widget _buildVideo(bool usable) {
    final thumbUrl = widget.video.thumbnailPath != null
        ? StorageImage.thumbnailUrl(widget.video.thumbnailPath!)
        : null;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Thumbnail luôn hiện ở dưới
        if (thumbUrl != null)
          CachedNetworkImage(
            imageUrl: thumbUrl,
            fit: BoxFit.cover,
            placeholder: (context, url) => Container(color: Colors.black),
            errorWidget: (context, url, error) =>
                Container(color: const Color(0xFF111111)),
          )
        else
          Container(color: Colors.black),

        // Chỉ render VideoPlayer khi controller còn hiệu lực và sẵn sàng
        if (usable && _hasFirstFrame)
          SizedBox.expand(
            child: BeautyEffectProcessor(
              smooth: _fx.beautySmooth,
              whiten: _fx.beautyWhiten,
              slim: _fx.beautySlim,
              eyes: _fx.beautyEyes,
              child: VideoFilterEffectRenderer(
                filter: _fx.filter,
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: _ctrl!.value.size.width > 0
                        ? _ctrl!.value.size.width
                        : 1080,
                    height: _ctrl!.value.size.height > 0
                        ? _ctrl!.value.size.height
                        : 1920,
                    child: VideoPlayer(_ctrl!),
                  ),
                ),
              ),
            ),
          ),

        // Render Stickers & Text Overlays đã gắn khi xuất video
        if (usable && _hasFirstFrame) ...[
          ..._fx.stickers.map(
            (s) => Positioned(
              left: s.position.dx,
              top: s.position.dy,
              child: IgnorePointer(
                child: Transform.rotate(
                  angle: s.rotation,
                  child: Transform.scale(
                    scale: s.scale,
                    child: Text(
                      s.emoji,
                      style: const TextStyle(fontSize: 40),
                    ),
                  ),
                ),
              ),
            ),
          ),
          ..._fx.textOverlays.map(
            (t) => Positioned(
              left: t.position.dx,
              top: t.position.dy,
              child: IgnorePointer(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black45,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    t.text,
                    textAlign: t.align,
                    style: TextStyle(
                      color: t.color,
                      fontSize: t.fontSize,
                      fontWeight: FontWeight.w700,
                      shadows: const [
                        Shadow(color: Colors.black54, blurRadius: 4),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],

        // Loading / error overlay (chỉ hiển thị vòng xoay cho trang đang active)
        if (!usable || !_hasFirstFrame)
          if (_initError == null && widget.isActive)
            const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation(AppColors.primary),
                strokeWidth: 2,
              ),
            )
          else if (_initError != null)
            const Center(
              child: Icon(Icons.videocam_off_outlined,
                  color: Colors.white54, size: 44),
            ),
      ],
    );
  }

  Widget _buildGradient() => Positioned.fill(
    child: DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Colors.transparent,
            Color(0x80000000),
            Color(0xCC000000),
          ],
          stops: [0, 0.5, 0.75, 1],
        ),
      ),
    ),
  );

  Widget _buildRightBar(bool usable) {
    final v = widget.video;
    final playing = usable && (_ctrl?.value.isPlaying ?? false);
    return Positioned(
      right: 12,
      bottom: 20,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _AvatarFollow(
            url: v.author.avatarUrl,
            onTap: () => context.push(Routes.profileOf(v.authorId)),
          ),
          const SizedBox(height: 25),
          _ActionBtn(
            icon: Icons.favorite,
            label: StorageImage.formatCount(v.likeCount),
            color: v.isLiked ? AppColors.like : Colors.white,
            onTap: () => context.requireAuth(
              () => _safeToggleVideoLike(v.id),
            ),
          ),
          const SizedBox(height: 10),
          _ActionBtn(
            icon: Icons.chat_bubble_rounded,
            label: StorageImage.formatCount(v.commentCount),
            color: Colors.white,
            onTap: () => CommentSheet.show(context, videoId: v.id),
          ),
          const SizedBox(height: 10),
          ListenableBuilder(
            listenable: sl<SavedVideosService>(),
            builder: (_, _) {
              final saved = sl<SavedVideosService>().isSaved(v.id);
              return _ActionBtn(
                icon: saved
                    ? Icons.bookmark_rounded
                    : Icons.bookmark_border_rounded,
                label: saved ? 'Đã lưu' : 'Lưu',
                color: saved ? AppColors.gold : Colors.white,
                onTap: () => context.requireAuth(() async {
                  final nowSaved = await sl<SavedVideosService>().toggleSave(
                    v.id,
                  );
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        nowSaved
                            ? 'Đã lưu vào Nội dung đã lưu'
                            : 'Đã bỏ lưu video',
                      ),
                      duration: const Duration(milliseconds: 1400),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }),
              );
            },
          ),
          const SizedBox(height: 10),
          _ActionBtn(
            icon: Icons.reply_rounded,
            label: StorageImage.formatCount(v.shareCount + _localShareBonus),
            color: Colors.white,
            onTap: () => _showShareVideoSheet(v),
            flip: true,
          ),
          const SizedBox(height: 15),
          _SpinningDisc(
            avatarUrl: v.author.avatarUrl,
            isPlaying: playing,
          ),
        ],
      ),
    );
  }

  Widget _buildBottomInfo() {
    final v = widget.video;
    return Positioned(
      left: 16,
      right: 80,
      bottom: 20,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (v.taggedProducts.isNotEmpty) ...[
            _VideoProductTagBanner(products: v.taggedProducts),
            const SizedBox(height: 10),
          ],
          GestureDetector(
            onTap: () => context.push(Routes.profileOf(v.authorId)),
            child: Row(
              children: [
                Text(
                  '@${v.author.username}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                if (v.author.isVerified) ...[
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.verified,
                    color: AppColors.verified,
                    size: 14,
                  ),
                ],
              ],
            ),
          ),
          if (v.caption?.isNotEmpty == true) ...[
            const SizedBox(height: 6),
            Text(
              v.caption!,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                height: 1.4,
                shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(
                Icons.music_note_rounded,
                color: Colors.white,
                size: 14,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  _fx.music != null
                      ? '${_fx.music!.title} · ${_fx.music!.artist}'
                      : 'Âm thanh gốc · ${v.author.username}',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (_fx.filterId != 'none') ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.16),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.auto_awesome_rounded,
                        color: AppColors.primary,
                        size: 11,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        _fx.filter.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPlayIcon() {
    final isPaused = _ctrl != null && !_ctrl!.value.isPlaying;
    final visible = isPaused || _showPlayIcon;   // thường trực khi paused

    return AnimatedOpacity(
      opacity: visible ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 100),
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            color: Colors.black45,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.play_arrow_rounded,            // luôn là play
            color: Colors.white,
            size: 48,
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingHeart() => Center(
    child: AnimatedBuilder(
      animation: _heartCtrl,
      builder: (context, child) => Opacity(
        opacity: _heartFade.value,
        child: Transform.scale(scale: _heartScale.value, child: child),
      ),
      child: const Icon(Icons.favorite, color: AppColors.like, size: 100),
    ),
  );

  Widget _buildMuteBtn() => Positioned(
    top: 60,
    right: 16,
    child: GestureDetector(
      onTap: () => setState(() {
        _isMuted = !_isMuted;
        _ctrl?.setVolume(_isMuted ? 0 : _fx.originalVolume);
        _bgMusicPlayer?.setVolume(_isMuted ? 0 : _fx.musicVolume);
      }),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: const BoxDecoration(
          color: Colors.black38,
          shape: BoxShape.circle,
        ),
        child: Icon(
          _isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
          color: Colors.white,
          size: 20,
        ),
      ),
    ),
  );

  Widget _buildProgress() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: _TikTokScrubber(
        controller: _ctrl!,
      ),
    );
  }

  void _incrementShareCountBestEffort(VideoEntity v) {
    setState(() => _localShareBonus += 1);
    SupabaseService.from('videos')
        .update({'share_count': v.shareCount + _localShareBonus})
        .eq('id', v.id)
        .catchError((_) {});
  }

  Future<void> _showShareVideoSheet(VideoEntity v) async {
    final shareLink = 'https://shareco/video/${v.id}';
    final shareText = v.caption?.trim().isNotEmpty == true
        ? '${v.caption!.trim()} — Xem video của @${v.author.username} trên ShareCo: $shareLink'
        : 'Xem video của @${v.author.username} trên ShareCo: $shareLink';

    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      backgroundColor: AppColors.surfaceSheet,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) {
        final saved = sl<SavedVideosService>().isSaved(v.id);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
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
                const SizedBox(height: 16),
                const Text(
                  'Chia sẻ & Tùy chọn video',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _ShareOptionItem(
                      icon: Icons.ios_share_rounded,
                      color: AppColors.primary,
                      label: 'Chia sẻ',
                      onTap: () async {
                        Navigator.pop(sheetCtx);
                        _incrementShareCountBestEffort(v);
                        await SharePlus.instance.share(
                          ShareParams(text: shareText),
                        );
                      },
                    ),
                    _ShareOptionItem(
                      icon: Icons.link_rounded,
                      color: AppColors.secondary,
                      label: 'Sao chép link',
                      onTap: () async {
                        Navigator.pop(sheetCtx);
                        await Clipboard.setData(ClipboardData(text: shareLink));
                        _incrementShareCountBestEffort(v);
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Đã sao chép liên kết video'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                    ),
                    _ShareOptionItem(
                      icon: Icons.send_rounded,
                      color: const Color(0xFF10B981),
                      label: 'Gửi bạn bè',
                      onTap: () {
                        Navigator.pop(sheetCtx);
                        context.requireAuth(
                          () => _showSendVideoToChatSheet(v, shareText),
                        );
                      },
                    ),
                    _ShareOptionItem(
                      icon: saved
                          ? Icons.bookmark_rounded
                          : Icons.bookmark_add_outlined,
                      color: AppColors.gold,
                      label: saved ? 'Bỏ lưu' : 'Lưu video',
                      onTap: () {
                        Navigator.pop(sheetCtx);
                        context.requireAuth(() async {
                          final nowSaved = await sl<SavedVideosService>()
                              .toggleSave(v.id);
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                nowSaved
                                    ? 'Đã lưu vào Nội dung đã lưu'
                                    : 'Đã bỏ lưu video',
                              ),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        });
                      },
                    ),
                    _ShareOptionItem(
                      icon: Icons.flag_outlined,
                      color: AppColors.error,
                      label: 'Báo cáo',
                      onTap: () {
                        Navigator.pop(sheetCtx);
                        ReportBottomSheet.show(
                          context,
                          targetType: 'video',
                          targetId: v.id,
                          title: 'Báo cáo video vi phạm',
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showSendVideoToChatSheet(
    VideoEntity v,
    String shareText,
  ) async {
    final res = await sl<GetConversationsUseCase>()();
    if (!mounted) return;
    res.fold(
      (_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Chưa thể tải danh sách hội thoại'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
      (conversations) {
        final uid = SupabaseService.currentUserId ?? '';
        showModalBottomSheet<void>(
          context: context,
          useRootNavigator: true,
          backgroundColor: Colors.white,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
          ),
          builder: (sheetCtx) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Gửi video đến cuộc trò chuyện',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (conversations.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Bạn chưa có cuộc trò chuyện nào. Hãy nhắn tin với bạn bè trước nhé!',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.black54),
                      ),
                    )
                  else
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: conversations.length,
                        itemBuilder: (_, idx) {
                          final conv = conversations[idx];
                          final other = conv.otherUser(uid);
                          final name = other?.displayName.isNotEmpty == true
                              ? other!.displayName
                              : (other?.username ?? 'Cuộc trò chuyện');
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: AppColors.bgInput,
                              backgroundImage: other?.avatarUrl != null
                                  ? CachedNetworkImageProvider(
                                      other!.avatarUrl!,
                                    )
                                  : null,
                              child: other?.avatarUrl == null
                                  ? Text(name[0].toUpperCase())
                                  : null,
                            ),
                            title: Text(
                              name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            trailing: ElevatedButton(
                              onPressed: () async {
                                Navigator.pop(sheetCtx);
                                await sl<SendMessageUseCase>()(
                                  conversationId: conv.id,
                                  content: shareText,
                                );
                                _incrementShareCountBestEffort(v);
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Đã gửi video cho $name'),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 6,
                                ),
                              ),
                              child: const Text('Gửi'),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool flip;
  const _ActionBtn({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.flip = false,
  });
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Transform(
          alignment: Alignment.center,
          transform: flip
              ? (Matrix4.identity()..scaleByDouble(-1.0, 1.0, 1.0, 1.0))
              : Matrix4.identity(),
          child: Icon(
            icon,
            color: color,
            size: 32,
            shadows: const [Shadow(color: Colors.black26, blurRadius: 4)],
          ),
        ),
        const SizedBox(height: 1),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            shadows: [Shadow(color: Colors.black45, blurRadius: 4)],
          ),
        ),
      ],
    ),
  );
}

class _ShareOptionItem extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  const _ShareOptionItem({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.16),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 23),
          ),
          const SizedBox(height: 7),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _AvatarFollow extends StatelessWidget {
  final String? url;
  final VoidCallback onTap;
  const _AvatarFollow({this.url, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: SizedBox(
      width: 52,
      height: 62,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.bottomCenter,
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: ClipOval(
              child: url != null
                  ? CachedNetworkImage(
                      imageUrl: url!,
                      fit: BoxFit.cover,
                      placeholder: (context, url) =>
                          Container(color: Colors.grey[800]),
                      errorWidget: (context, url, error) =>
                          const Icon(Icons.person, color: Colors.white70),
                    )
                  : const Icon(Icons.person, color: Colors.white70),
            ),
          ),
          Positioned(
            bottom: -10,
            child: Container(
              width: 22,
              height: 22,
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.add, color: Colors.white, size: 14),
            ),
          ),
        ],
      ),
    ),
  );
}

class _SpinningDisc extends StatefulWidget {
  final String? avatarUrl;
  final bool isPlaying;
  const _SpinningDisc({this.avatarUrl, required this.isPlaying});
  @override
  State<_SpinningDisc> createState() => _SpinningDiscState();
}

class _SpinningDiscState extends State<_SpinningDisc>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    );
    if (widget.isPlaying) _ctrl.repeat();
  }

  @override
  void didUpdateWidget(_SpinningDisc old) {
    super.didUpdateWidget(old);
    if (widget.isPlaying != old.isPlaying) {
      widget.isPlaying ? _ctrl.repeat() : _ctrl.stop();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RotationTransition(
    turns: _ctrl,
    child: Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white30, width: 6),
        color: Colors.black,
      ),
      child: ClipOval(
        child: widget.avatarUrl != null
            ? CachedNetworkImage(imageUrl: widget.avatarUrl!, fit: BoxFit.cover)
            : const Icon(Icons.music_note, color: Colors.white38),
      ),
    ),
  );
}

class _TikTokScrubber extends StatefulWidget {
  final VideoPlayerController controller;
  const _TikTokScrubber({required this.controller});

  @override
  State<_TikTokScrubber> createState() => _TikTokScrubberState();
}

class _TikTokScrubberState extends State<_TikTokScrubber> {
  bool _dragging = false;
  double _dragValue = 0;

  void _onDragStart(double dx, double width) {
    final p = (dx / width).clamp(0.0, 1.0);
    setState(() {
      _dragging = true;
      _dragValue = p;
    });
  }

  void _onDragUpdate(double dx, double width) {
    final p = (dx / width).clamp(0.0, 1.0);
    setState(() => _dragValue = p);
  }

  void _onDragEnd() {
    if (!VideoControllerCache.isControllerDisposed(widget.controller)) {
      try {
        final dur = widget.controller.value.duration;
        final target =
            Duration(milliseconds: (_dragValue * dur.inMilliseconds).round());
        widget.controller.seekTo(target);
      } catch (_) {}
    }
    if (mounted) {
      setState(() => _dragging = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (VideoControllerCache.isControllerDisposed(widget.controller)) {
      return const SizedBox.shrink();
    }
    return ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: widget.controller,
      builder: (context, value, _) {
        final dur = value.duration.inMilliseconds;
        final pos = dur > 0 ? value.position.inMilliseconds / dur : 0.0;
        final display = _dragging ? _dragValue : pos;
        final screenWidth = MediaQuery.of(context).size.width;

        // Tính thời gian hiển thị
        final currentMs = (display.clamp(0.0, 1.0) * dur).round();
        final currentSec = currentMs ~/ 1000;
        final totalSec = dur ~/ 1000;
        final timeText =
            '${_fmt(currentSec)} / ${_fmt(totalSec)}';

        // Vị trí thumb (px), giới hạn để không tràn ra ngoài màn hình
        final thumbX = (display.clamp(0.0, 1.0) * (screenWidth - 14)).clamp(0.0, screenWidth - 14);

        return SizedBox(
          height: 52, // tăng chiều cao để chứa timestamp
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragStart: (d) {
              _onDragStart(d.localPosition.dx, screenWidth);
            },
            onHorizontalDragUpdate: (d) {
              _onDragUpdate(d.localPosition.dx, screenWidth);
            },
            onHorizontalDragEnd: (_) => _onDragEnd(),
            onTapDown: (d) {
              _onDragStart(d.localPosition.dx, screenWidth);
            },
            onTapUp: (_) => _onDragEnd(),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Track + played + buffered — căn bottom
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  height: 28,
                  child: Stack(
                    alignment: Alignment.centerLeft,
                    children: [
                      // Track nền
                      Container(
                        height: _dragging ? 3 : 2,
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      // Buffered
                      FractionallySizedBox(
                        widthFactor: dur > 0
                            ? (value.buffered.isNotEmpty
                            ? (value.buffered.last.end.inMilliseconds / dur).clamp(0.0, 1.0)
                            : 0.0)
                            : 0.0,
                        child: Container(
                          height: _dragging ? 3 : 2,
                          decoration: BoxDecoration(
                            color: Colors.white38,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      // Played
                      FractionallySizedBox(
                        widthFactor: display.clamp(0.0, 1.0),
                        child: Container(
                          height: _dragging ? 3 : 2,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      // Thumb
                      Positioned(
                        left: thumbX,
                        child: AnimatedScale(
                          scale: _dragging ? 1.0 : 0.0,
                          duration: const Duration(milliseconds: 150),
                          curve: Curves.easeOutBack,
                          child: Container(
                            width: 14,
                            height: 14,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Timestamp — hiện phía trên thumb khi đang kéo
                if (_dragging)
                  Positioned(
                    bottom: 28 + 8, // 8px gap trên thanh track
                    // Clamp để không tràn trái/phải
                    left: (thumbX - 36).clamp(0.0, screenWidth - 80),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        timeText,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _fmt(int totalSeconds) {
    final m = totalSeconds ~/ 60;
    final s = totalSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}

// ─── TikTok Shop Product Link Banner & Bottom Sheet ──────────────────────────

class _VideoProductTagBanner extends StatelessWidget {
  final List<Product> products;
  const _VideoProductTagBanner({required this.products});

  void _onTapBanner(BuildContext context) {
    if (products.length == 1) {
      context.push('/products/${products.first.id}');
      return;
    }
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _VideoProductsBottomSheet(products: products),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primary = products.first;
    final imageUrl = StorageImage.publicUrl(primary.displayImagePath);
    final vndFormat = NumberFormat.currency(locale: 'vi_VN', symbol: '₫');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Top pill link (Modern glass shopping bag link)
        GestureDetector(
          onTap: () => _onTapBanner(context),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.surfaceGlass.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.borderSubtle),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    gradient: AppColors.shopGradient,
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: const Icon(
                    Icons.shopping_bag_rounded,
                    color: Colors.white,
                    size: 11,
                  ),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    products.length > 1
                        ? 'Giỏ hàng (${products.length}) · ${primary.title}'
                        : 'Sản phẩm · ${primary.title}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.gold,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.gold,
                  size: 14,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),

        // Product showcase card with direct Buy button
        GestureDetector(
          onTap: () => context.push('/products/${primary.id}'),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 290),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.surfaceGlass.withValues(alpha: 0.82),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.warning.withValues(alpha: 0.4),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: 44,
                    height: 44,
                    color: AppColors.surfaceElevated,
                    child: imageUrl != null
                        ? CachedNetworkImage(
                            imageUrl: imageUrl,
                            fit: BoxFit.cover,
                            errorWidget: (_, _, _) => const Icon(
                              Icons.shopping_bag_outlined,
                              color: Colors.white54,
                              size: 20,
                            ),
                          )
                        : const Icon(
                            Icons.shopping_bag_outlined,
                            color: Colors.white54,
                            size: 20,
                          ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        primary.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Text(
                            vndFormat.format(primary.priceMin),
                            style: const TextStyle(
                              color: AppColors.warning,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          if (primary.discountPercent > 0) ...[
                            const SizedBox(width: 5),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '-${primary.discountPercent}%',
                                style: const TextStyle(
                                  color: AppColors.primarySoft,
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.bold,
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    gradient: AppColors.shopGradient,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Mua',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _VideoProductsBottomSheet extends StatelessWidget {
  final List<Product> products;
  const _VideoProductsBottomSheet({required this.products});

  @override
  Widget build(BuildContext context) {
    final vndFormat = NumberFormat.currency(locale: 'vi_VN', symbol: '₫');

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.65,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surfaceSheet,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
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
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    gradient: AppColors.shopGradient,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.shopping_bag_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Sản phẩm trong video (${products.length})',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, color: Colors.white54),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.borderSubtle),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.all(16),
              itemCount: products.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (ctx, i) {
                final product = products[i];
                final imageUrl =
                    StorageImage.publicUrl(product.displayImagePath);

                return InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/products/${product.id}');
                  },
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceCard,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.borderSubtle),
                    ),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            width: 60,
                            height: 60,
                            color: AppColors.surfaceElevated,
                            child: imageUrl != null
                                ? CachedNetworkImage(
                                    imageUrl: imageUrl,
                                    fit: BoxFit.cover,
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
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                vndFormat.format(product.priceMin),
                                style: const TextStyle(
                                  color: AppColors.warning,
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            gradient: AppColors.shopGradient,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text(
                            'Mua ngay',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
