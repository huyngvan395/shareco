// features/feed/presentation/widgets/video_item.dart

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shareco/features/comment/presentation/screen/comment_sheet.dart';
import 'package:video_player/video_player.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/helpers/require_auth.dart';
import '../../../../core/utils/storage_image.dart';
import '../../../../routes/app_router.dart';
import '../../../video/domain/entities/video_entity.dart';
import '../bloc/feed_bloc.dart';
import '../bloc/feed_event.dart';

class VideoItem extends StatefulWidget {
  final VideoEntity video;
  final bool isActive;
  final Future<VideoPlayerController>? controllerFuture;

  const VideoItem({
    super.key,
    required this.video,
    required this.isActive,
    this.controllerFuture,
  });

  @override
  State<VideoItem> createState() => _VideoItemState();
}

class _VideoItemState extends State<VideoItem>
    with SingleTickerProviderStateMixin {
  VideoPlayerController? _ctrl;
  bool _initialized = false;
  bool _hasFirstFrame = false;
  bool _ownsController = false;
  Object? _initError;
  bool _isMuted = false;
  bool _showPlayIcon = false;

  late AnimationController _heartCtrl;
  late Animation<double> _heartScale;
  late Animation<double> _heartFade;
  bool _showHeart = false;

  @override
  void initState() {
    super.initState();
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
    _initController();
  }

  Future<void> _initController() async {
    try {
      if (widget.controllerFuture != null) {
        _ctrl = await widget.controllerFuture;
      } else {
        final url = StorageImage.videoUrl(widget.video.videoPath);
        _ctrl = VideoPlayerController.networkUrl(
          Uri.parse(url),
          videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
        );
        _ownsController = true;
        await _ctrl!.initialize();
      }
      if (!mounted) return;
      await _ctrl!.setLooping(true);
      await _ctrl!.setVolume(_isMuted ? 0 : 1);

      // 👇 Lắng nghe frame đầu tiên trước khi render
      _ctrl!.addListener(_onControllerUpdate);

      setState(() {
        _initialized = true;
        _initError = null;
      });
      if (widget.isActive) await _ctrl!.play();
      Future.delayed(const Duration(milliseconds: 2000), () {
        if (mounted && !_hasFirstFrame && _initialized) {
          setState(() => _hasFirstFrame = true);
          _ctrl?.removeListener(_onControllerUpdate);
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _initError = e);
    }
  }

  @override
  void didUpdateWidget(VideoItem old) {
    super.didUpdateWidget(old);
    if (!_initialized) return;
    if (widget.isActive != old.isActive) {
      widget.isActive ? _ctrl!.play() : _ctrl!.pause();
      setState(() {});
    }
  }

  void _onControllerUpdate() {
    if (!mounted || _hasFirstFrame) return;
    final value = _ctrl!.value;
    if (value.isInitialized && (value.isPlaying || value.position > Duration.zero || value.isBuffering)) {
      setState(() => _hasFirstFrame = true);
      _ctrl!.removeListener(_onControllerUpdate);
    }
  }

  @override
  void dispose() {
    _ctrl?.removeListener(_onControllerUpdate);
    _heartCtrl.dispose();
    if (_ownsController) _ctrl?.dispose();
    super.dispose();
  }

  void _onDoubleTap() {
    if (!widget.video.isLiked) {
      context.requireAuth(
        () =>
            context.read<FeedBloc>().add(FeedVideoLikeToggled(widget.video.id)),
      );
    }
    setState(() => _showHeart = true);
    _heartCtrl.forward(from: 0).then((_) {
      if (mounted) setState(() => _showHeart = false);
    });
  }

  void _onTap() {
    if (!_initialized) return;
    final wasPlaying = _ctrl!.value.isPlaying;
    wasPlaying ? _ctrl!.pause() : _ctrl!.play();
    if (!wasPlaying) {
      setState(() => _showPlayIcon = true);
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) setState(() => _showPlayIcon = false);
      });
    } else {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return GestureDetector(
      onDoubleTap: _onDoubleTap,
      onTap: _onTap,
      child: SizedBox(
        width: size.width,
        height: size.height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            _buildVideo(),
            _buildGradient(),
            _buildRightBar(),
            _buildBottomInfo(),
            if (_initialized) _buildPlayIcon(),
            if (_showHeart) _buildFloatingHeart(),
            _buildMuteBtn(),
            if (_initialized) _buildProgress(),
          ],
        ),
      ),
    );
  }

  Widget _buildVideo() {
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

        // Chỉ render VideoPlayer sau khi có frame đầu tiên
        if (_initialized && _hasFirstFrame)
          SizedBox.expand(
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: _ctrl!.value.size.width,
                height: _ctrl!.value.size.height,
                child: VideoPlayer(_ctrl!),
              ),
            ),
          ),

        // Loading / error overlay
        if (!_initialized || !_hasFirstFrame)
          if (_initError == null)
            const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation(Colors.white),
                strokeWidth: 2,
              ),
            )
          else
            const Center(
              child: Icon(Icons.videocam_off_outlined,
                  color: Colors.white54, size: 44),
            ),
      ],
    );
  }

  double _safeAspectRatio(VideoPlayerController controller) {
    final aspectRatio = controller.value.aspectRatio;
    if (aspectRatio.isFinite && aspectRatio > 0) return aspectRatio;

    final size = controller.value.size;
    if (size.width > 0 && size.height > 0) return size.width / size.height;

    return 9 / 16;
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

  Widget _buildRightBar() {
    final v = widget.video;
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
              () => context.read<FeedBloc>().add(FeedVideoLikeToggled(v.id)),
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
          _ActionBtn(
            icon: Icons.reply_rounded,
            label: StorageImage.formatCount(v.shareCount),
            color: Colors.white,
            onTap: () {},
            flip: true,
          ),
          const SizedBox(height: 15),
          _SpinningDisc(avatarUrl: v.author.avatarUrl, isPlaying: _ctrl?.value.isPlaying ?? false,),
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
                  'Âm thanh gốc · ${v.author.username}',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
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
        _ctrl?.setVolume(_isMuted ? 0 : 1);
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

  double get _progress {
    final dur = widget.controller.value.duration.inMilliseconds;
    if (dur == 0) return 0;
    if (_dragging) return _dragValue;
    return widget.controller.value.position.inMilliseconds / dur;
  }

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
    final dur = widget.controller.value.duration;
    final target = Duration(milliseconds: (_dragValue * dur.inMilliseconds).round());
    widget.controller.seekTo(target);
    setState(() => _dragging = false);
  }

  @override
  Widget build(BuildContext context) {
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
