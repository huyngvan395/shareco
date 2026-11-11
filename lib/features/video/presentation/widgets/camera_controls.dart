import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shareco/core/constants/app_colors.dart';
import 'package:shareco/features/video/data/datasources/music_search_service.dart';
import 'package:shareco/features/video/domain/entities/filter_entity.dart';
import 'package:shareco/features/video/presentation/bloc/camera_bloc.dart';
import 'package:shareco/features/video/presentation/bloc/camera_event.dart';
import 'package:shareco/features/video/presentation/bloc/camera_state.dart';

// ─── Top Bar (Close + Music Pill) ────────────────────────────────────────────

class CameraTopBar extends StatelessWidget {
  final VoidCallback onClose;
  final VoidCallback onOpenMusic;

  const CameraTopBar({
    super.key,
    required this.onClose,
    required this.onOpenMusic,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CameraBloc, CameraState>(
      buildWhen: (p, c) =>
          p.selectedMusic != c.selectedMusic ||
          p.activeFilter != c.activeFilter ||
          p.isRecording != c.isRecording ||
          p.isPaused != c.isPaused,
      builder: (ctx, state) {
        final activelyRecording = state.isRecording && !state.isPaused;
        final music = state.selectedMusic;
        final activeFilter = state.activeFilter;

        return SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    AnimatedOpacity(
                      opacity: activelyRecording ? 0.0 : 1.0,
                      duration: const Duration(milliseconds: 200),
                      child: IgnorePointer(
                        ignoring: activelyRecording,
                        child: activeFilter.id != 'none'
                            ? GestureDetector(
                                onTap: () =>
                                    CameraRightToolbar.showFilterSheet(ctx),
                                child: FilterThumbnailBox(
                                  filter: activeFilter,
                                  size: 42,
                                  borderRadius: 10,
                                ),
                              )
                            : _CircleIconBtn(
                                icon: Icons.close_rounded,
                                onTap: onClose,
                              ),
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: activelyRecording ? null : onOpenMusic,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        constraints: const BoxConstraints(maxWidth: 245),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: music != null
                              ? Colors.black.withValues(alpha: 0.48)
                              : Colors.black.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: music != null
                                ? Colors.white.withValues(alpha: 0.28)
                                : Colors.white.withValues(alpha: 0.15),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.25),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              activelyRecording && music != null
                                  ? Icons.graphic_eq_rounded
                                  : Icons.music_note_rounded,
                              color: Colors.white,
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                music != null
                                    ? music.title
                                    : 'Thêm âm thanh',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            if (music != null && !activelyRecording) ...[
                              const SizedBox(width: 8),
                              Container(
                                width: 1,
                                height: 14,
                                color: Colors.white30,
                              ),
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: () => ctx
                                    .read<CameraBloc>()
                                    .add(const CameraMusicSelected(null)),
                                child: const Icon(
                                  Icons.close_rounded,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const Spacer(),
                    if (activeFilter.id != 'none' && !activelyRecording)
                      _CircleIconBtn(
                        icon: Icons.close_rounded,
                        onTap: onClose,
                      )
                    else
                      const SizedBox(width: 38),
                  ],
                ),
                // Hiển thị tên hiệu ứng & người tạo ở góc trên bên trái khi chọn Filter
                if (activeFilter.id != 'none') ...[
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () => CameraRightToolbar.showFilterSheet(ctx),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          activeFilter.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            shadows: [
                              Shadow(color: Colors.black54, blurRadius: 6),
                            ],
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Người tạo: ${activeFilter.creator} ›',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            shadows: [
                              Shadow(color: Colors.black54, blurRadius: 6),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─── Right Toolbar ───────────────────────────────────────────────────────────

class CameraRightToolbar extends StatelessWidget {
  final bool showSpeedBar;
  final VoidCallback onToggleSpeedBar;

  const CameraRightToolbar({
    super.key,
    required this.showSpeedBar,
    required this.onToggleSpeedBar,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CameraBloc, CameraState>(
      builder: (ctx, state) {
        final activelyRecording = state.isRecording && !state.isPaused;
        return AnimatedOpacity(
          opacity: activelyRecording ? 0.0 : 1.0,
          duration: const Duration(milliseconds: 200),
          child: IgnorePointer(
            ignoring: activelyRecording,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.42),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.12),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _Tool(
                    icon: Icons.flip_camera_ios_rounded,
                    label: 'Lật',
                    onTap: () => ctx
                        .read<CameraBloc>()
                        .add(const CameraFlipRequested()),
                  ),
                  const SizedBox(height: 14),
                  _Tool(
                    icon: Icons.speed_rounded,
                    label: state.activeSpeed.label,
                    active: showSpeedBar || state.activeSpeed.value != 1.0,
                    onTap: onToggleSpeedBar,
                  ),
                  const SizedBox(height: 14),
                  _Tool(
                    icon: Icons.color_lens_rounded,
                    label: 'Bộ lọc',
                    active: state.activeFilter.id != 'none',
                    onTap: () => showFilterSheet(context),
                  ),
                  const SizedBox(height: 14),
                  _Tool(
                    icon: Icons.face_retouching_natural_rounded,
                    label: 'Làm đẹp',
                    active: state.beautyEnabled,
                    onTap: () {
                      if (!state.beautyEnabled) {
                        ctx.read<CameraBloc>().add(const CameraBeautyToggled());
                      }
                      showBeautySheet(context);
                    },
                  ),
                  const SizedBox(height: 14),
                  _Tool(
                    icon: Icons.text_fields_rounded,
                    label: 'Chữ',
                    active: state.textOverlays.isNotEmpty,
                    onTap: () => showTextSheet(context),
                  ),
                  const SizedBox(height: 14),
                  _Tool(
                    icon: Icons.emoji_emotions_outlined,
                    label: 'Nhãn dán',
                    active: state.stickers.isNotEmpty,
                    onTap: () => showStickerSheet(context),
                  ),
                  const SizedBox(height: 14),
                  _Tool(
                    icon: switch (state.flashMode) {
                      FlashMode.off => Icons.flash_off_rounded,
                      FlashMode.on => Icons.flash_on_rounded,
                      FlashMode.auto => Icons.flash_auto_rounded,
                    },
                    label: 'Flash',
                    active: state.flashMode != FlashMode.off,
                    onTap: () => ctx
                        .read<CameraBloc>()
                        .add(const CameraFlashToggled()),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  static void showFilterSheet(BuildContext ctx) {
    final bloc = ctx.read<CameraBloc>();
    showModalBottomSheet(
      context: ctx,
      barrierColor: Colors.transparent,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => BlocProvider.value(
        value: bloc,
        child: const _FilterSheet(),
      ),
    );
  }

  static void showStickerSheet(BuildContext ctx) {
    final bloc = ctx.read<CameraBloc>();
    showModalBottomSheet(
      context: ctx,
      backgroundColor: Colors.transparent,
      builder: (_) => BlocProvider.value(
        value: bloc,
        child: const _StickerSheet(),
      ),
    );
  }

  static void showTextSheet(BuildContext ctx) {
    final bloc = ctx.read<CameraBloc>();
    showModalBottomSheet(
      context: ctx,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => BlocProvider.value(
        value: bloc,
        child: const _TextSheet(),
      ),
    );
  }

  static void showBeautySheet(BuildContext ctx) {
    final bloc = ctx.read<CameraBloc>();
    showModalBottomSheet(
      context: ctx,
      barrierColor: Colors.transparent,
      backgroundColor: Colors.transparent,
      builder: (_) => BlocProvider.value(
        value: bloc,
        child: const _BeautySheet(),
      ),
    );
  }

  static void showMusicSheet(BuildContext ctx) {
    final bloc = ctx.read<CameraBloc>();
    showModalBottomSheet(
      context: ctx,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => BlocProvider.value(
        value: bloc,
        child: const _MusicSheet(),
      ),
    );
  }
}

// ─── Speed Selector ──────────────────────────────────────────────────────────

class SpeedSelector extends StatelessWidget {
  const SpeedSelector({super.key});
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CameraBloc, CameraState>(
      buildWhen: (p, c) =>
          p.activeSpeed != c.activeSpeed || p.isRecording != c.isRecording,
      builder: (ctx, state) {
        if (state.isRecording) return const SizedBox.shrink();
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: AppSpeeds.speeds.map((s) {
              final active = state.activeSpeed.value == s.value;
              return GestureDetector(
                onTap: () =>
                    ctx.read<CameraBloc>().add(CameraSpeedChanged(s)),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: active ? Colors.white : Colors.transparent,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Text(
                    s.label,
                    style: TextStyle(
                      color: active ? Colors.black : Colors.white70,
                      fontWeight: active ? FontWeight.w800 : FontWeight.w500,
                      fontSize: 12,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }
}

// ─── Duration limit selector ──────────────────────────────────────────────────

class DurationLimitSelector extends StatelessWidget {
  const DurationLimitSelector({super.key});
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CameraBloc, CameraState>(
      buildWhen: (p, c) =>
          p.durationLimit != c.durationLimit || p.isRecording != c.isRecording,
      builder: (ctx, state) {
        if (state.isRecording) return const SizedBox.shrink();
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: AppDurationLimits.limits.map((lim) {
            final active = state.durationLimit.label == lim.label;
            return GestureDetector(
              onTap: () =>
                  ctx.read<CameraBloc>().add(CameraDurationLimitChanged(lim)),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      lim.label,
                      style: TextStyle(
                        color: active ? Colors.white : Colors.white54,
                        fontWeight: active ? FontWeight.w800 : FontWeight.w500,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 4),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: active ? 5 : 0,
                      height: active ? 5 : 0,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

// ─── Recording progress bar ───────────────────────────────────────────────────

class RecordingProgressBar extends StatelessWidget {
  const RecordingProgressBar({super.key});
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CameraBloc, CameraState>(
      buildWhen: (p, c) =>
          p.recordedDuration != c.recordedDuration ||
          p.isRecording != c.isRecording,
      builder: (_, state) {
        if (!state.isRecording) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${_fmt(state.recordedDuration)} / ${_fmt(state.durationLimit.max)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: state.recordingProgress,
                  backgroundColor: Colors.white24,
                  valueColor: const AlwaysStoppedAnimation(AppColors.primary),
                  minHeight: 4,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _fmt(Duration d) =>
      '${d.inMinutes.remainder(60).toString().padLeft(2, '0')}:'
      '${d.inSeconds.remainder(60).toString().padLeft(2, '0')}';
}

// ─── Record button ────────────────────────────────────────────────────────────

class RecordButton extends StatefulWidget {
  final VoidCallback onStart;
  final VoidCallback onStop;
  final VoidCallback onPause;
  final VoidCallback onResume;
  const RecordButton({
    super.key,
    required this.onStart,
    required this.onStop,
    required this.onPause,
    required this.onResume,
  });
  @override
  State<RecordButton> createState() => _RecordButtonState();
}

class _RecordButtonState extends State<RecordButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulse;
  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CameraBloc, CameraState>(
      buildWhen: (p, c) =>
          p.isRecording != c.isRecording || p.isPaused != c.isPaused,
      builder: (_, state) => GestureDetector(
        onTap: () {
          if (!state.isRecording) {
            widget.onStart();
          } else if (state.isPaused) {
            widget.onResume();
          } else {
            widget.onPause();
          }
        },
        child: SizedBox(
          width: 82,
          height: 82,
          child: Stack(
            alignment: Alignment.center,
            children: [
              AnimatedBuilder(
                animation: _pulse,
                builder: (_, _) => Container(
                  width: state.isRecording && !state.isPaused
                      ? 76 + _pulse.value * 6
                      : 78,
                  height: state.isRecording && !state.isPaused
                      ? 76 + _pulse.value * 6
                      : 78,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: state.isRecording
                          ? AppColors.primary
                          : Colors.white,
                      width: 4,
                    ),
                  ),
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: state.isRecording && !state.isPaused ? 32 : 62,
                height: state.isRecording && !state.isPaused ? 32 : 62,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(
                    state.isRecording && !state.isPaused ? 8 : 34,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Stickers overlay ─────────────────────────────────────────────────────────

class StickersOverlay extends StatelessWidget {
  const StickersOverlay({super.key});
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CameraBloc, CameraState>(
      buildWhen: (p, c) => p.stickers != c.stickers,
      builder: (ctx, state) => Stack(
        children: state.stickers
            .map(
              (s) => Positioned(
                left: s.position.dx,
                top: s.position.dy,
                child: GestureDetector(
                  onPanUpdate: (d) => ctx.read<CameraBloc>().add(
                    CameraStickerMoved(
                      stickerId: s.id,
                      position: s.position + d.delta,
                    ),
                  ),
                  onDoubleTap: () =>
                      ctx.read<CameraBloc>().add(CameraStickerRemoved(s.id)),
                  child: Transform.rotate(
                    angle: s.rotation,
                    child: Transform.scale(
                      scale: s.scale,
                      child: Text(
                        s.emoji,
                        style: const TextStyle(fontSize: 42),
                      ),
                    ),
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

// ─── Text overlays ────────────────────────────────────────────────────────────

class TextOverlaysLayer extends StatelessWidget {
  const TextOverlaysLayer({super.key});
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CameraBloc, CameraState>(
      buildWhen: (p, c) => p.textOverlays != c.textOverlays,
      builder: (ctx, state) => Stack(
        children: state.textOverlays
            .map(
              (t) => Positioned(
                left: t.position.dx,
                top: t.position.dy,
                child: GestureDetector(
                  onDoubleTap: () =>
                      ctx.read<CameraBloc>().add(CameraTextRemoved(t.id)),
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
                      style: TextStyle(
                        color: t.color,
                        fontSize: t.fontSize,
                        fontWeight: FontWeight.w700,
                        shadows: const [
                          Shadow(color: Colors.black54, blurRadius: 4),
                        ],
                      ),
                      textAlign: t.align,
                    ),
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

// ─── Sheet widgets ────────────────────────────────────────────────────────────

class _FilterSheet extends StatefulWidget {
  const _FilterSheet();

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  String _selectedTab = 'Thịnh hành';
  bool _showSearch = false;
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<VideoFilter> _filteredList() {
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isNotEmpty) {
      return AppFilters.all
          .where(
            (f) =>
                f.id != 'none' &&
                (f.name.toLowerCase().contains(q) ||
                    f.subtitle.toLowerCase().contains(q) ||
                    f.creator.toLowerCase().contains(q)),
          )
          .toList();
    }
    return AppFilters.byCategory(_selectedTab);
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CameraBloc, CameraState>(
      builder: (ctx, state) {
        final activeFilter = state.activeFilter;
        final isSaved = AppFilters.isSaved(activeFilter.id);
        final items = _filteredList();

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Nút "Đã lưu" nổi phía trên góc trái của bảng hiệu ứng (như ảnh mẫu)
            if (activeFilter.id != 'none')
              Padding(
                padding: const EdgeInsets.only(left: 14, bottom: 10),
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      AppFilters.toggleSaved(activeFilter.id);
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.14),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isSaved
                              ? Icons.bookmark_rounded
                              : Icons.bookmark_border_rounded,
                          color: isSaved
                              ? const Color(0xFFFFB300)
                              : Colors.white,
                          size: 18,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          isSaved ? 'Đã lưu' : 'Lưu hiệu ứng',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // Bảng chọn Hiệu ứng & Bộ lọc 4 cột trong suốt
            Container(
              height: MediaQuery.of(context).size.height * 0.42,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xFF1A1A1A).withValues(alpha: 0.78),
                    const Color(0xFF0E0E10).withValues(alpha: 0.94),
                  ],
                ),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(22),
                ),
              ),
              child: SafeArea(
                top: false,
                child: Stack(
                  children: [
                    Column(
                      children: [
                        // Thanh điều hướng: 🚫 (Bỏ chọn) | 🔍 (Tìm kiếm) | 🔖 (Đã lưu) | Các tab danh mục
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
                          child: Row(
                            children: [
                              // Nút 🚫 Bỏ hiệu ứng
                              IconButton(
                                onPressed: () => ctx
                                    .read<CameraBloc>()
                                    .add(const CameraFilterChanged(AppFilters.none)),
                                icon: Icon(
                                  Icons.block_rounded,
                                  color: activeFilter.id == 'none'
                                      ? Colors.white
                                      : Colors.white54,
                                  size: 22,
                                ),
                                tooltip: 'Tắt bộ lọc',
                              ),
                              // Nút 🔍 Tìm hiệu ứng
                              IconButton(
                                onPressed: () => setState(() {
                                  _showSearch = !_showSearch;
                                  if (!_showSearch) _searchCtrl.clear();
                                }),
                                icon: Icon(
                                  Icons.search_rounded,
                                  color: _showSearch
                                      ? Colors.white
                                      : Colors.white60,
                                  size: 22,
                                ),
                                tooltip: 'Tìm hiệu ứng',
                              ),
                              // Nút 🔖 Đã lưu
                              IconButton(
                                onPressed: () => setState(() {
                                  _selectedTab = 'Đã lưu';
                                  _showSearch = false;
                                  _searchCtrl.clear();
                                }),
                                icon: Icon(
                                  Icons.bookmark_rounded,
                                  color: _selectedTab == 'Đã lưu'
                                      ? Colors.white
                                      : Colors.white54,
                                  size: 21,
                                ),
                                tooltip: 'Hiệu ứng đã lưu',
                              ),
                              const SizedBox(width: 4),
                              // Danh sách Tab: Thịnh hành | Game | Vui nhộn | Chân dung | Vintage | Điện ảnh
                              Expanded(
                                child: SizedBox(
                                  height: 36,
                                  child: ListView.builder(
                                    scrollDirection: Axis.horizontal,
                                    itemCount: AppFilters.categories.length,
                                    itemBuilder: (_, i) {
                                      final cat = AppFilters.categories[i];
                                      final selected =
                                          _selectedTab == cat && !_showSearch;
                                      return GestureDetector(
                                        onTap: () => setState(() {
                                          _selectedTab = cat;
                                          _showSearch = false;
                                          _searchCtrl.clear();
                                        }),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                          ),
                                          child: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Text(
                                                cat,
                                                style: TextStyle(
                                                  color: selected
                                                      ? Colors.white
                                                      : Colors.white54,
                                                  fontSize: 15,
                                                  fontWeight: selected
                                                      ? FontWeight.w800
                                                      : FontWeight.w500,
                                                ),
                                              ),
                                              const SizedBox(height: 5),
                                              AnimatedContainer(
                                                duration: const Duration(
                                                  milliseconds: 180,
                                                ),
                                                width: selected ? 46 : 0,
                                                height: 2.5,
                                                decoration: BoxDecoration(
                                                  color: Colors.white,
                                                  borderRadius:
                                                      BorderRadius.circular(2),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Ô tìm kiếm nhanh hiệu ứng (khi bấm kính lúp)
                        if (_showSearch)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                            child: TextField(
                              controller: _searchCtrl,
                              autofocus: true,
                              onChanged: (_) => setState(() {}),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                              ),
                              decoration: InputDecoration(
                                hintText:
                                    'Tìm hiệu ứng (1994, Khóc nhè, F1, Hàn Quốc, Kodak...)',
                                hintStyle: const TextStyle(
                                  color: Colors.white38,
                                  fontSize: 12.5,
                                ),
                                prefixIcon: const Icon(
                                  Icons.search_rounded,
                                  color: Colors.white54,
                                  size: 18,
                                ),
                                filled: true,
                                fillColor: Colors.white.withValues(alpha: 0.1),
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                          ),

                        // Lưới 4 cột hiển thị các thẻ hiệu ứng vuông bo góc (như ảnh mẫu)
                        Expanded(
                          child: items.isEmpty
                              ? const Center(
                                  child: Text(
                                    'Chưa có hiệu ứng nào trong mục này',
                                    style: TextStyle(
                                      color: Colors.white54,
                                      fontSize: 13,
                                    ),
                                  ),
                                )
                              : GridView.builder(
                                  padding: const EdgeInsets.fromLTRB(
                                    18,
                                    8,
                                    18,
                                    84,
                                  ),
                                  gridDelegate:
                                      const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 4,
                                    mainAxisSpacing: 14,
                                    crossAxisSpacing: 14,
                                    childAspectRatio: 0.78,
                                  ),
                                  itemCount: items.length,
                                  itemBuilder: (_, i) {
                                    final f = items[i];
                                    final active = activeFilter.id == f.id;
                                    return GestureDetector(
                                      onTap: () {
                                        ctx.read<CameraBloc>().add(
                                          CameraFilterChanged(
                                            active ? AppFilters.none : f,
                                          ),
                                        );
                                      },
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          FilterThumbnailBox(
                                            filter: f,
                                            size: 66,
                                            selected: active,
                                            borderRadius: 15,
                                          ),
                                          const SizedBox(height: 5),
                                          Text(
                                            f.name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: active
                                                  ? Colors.white
                                                  : Colors.white70,
                                              fontSize: 11,
                                              fontWeight: active
                                                  ? FontWeight.w800
                                                  : FontWeight.w500,
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

                    // Nút tròn trắng chính giữa phía dưới (như ảnh mẫu) để đóng bảng & sẵn sàng quay
                    Positioned(
                      bottom: 12,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: GestureDetector(
                          onTap: () => Navigator.of(context).pop(),
                          child: Container(
                            width: 64,
                            height: 64,
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.65),
                                width: 3.5,
                              ),
                            ),
                            child: Container(
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _StickerSheet extends StatelessWidget {
  const _StickerSheet();
  static const _emojis = [
    '🔥', '❤️', '😂', '🎉', '✨', '💯', '👑', '🌈',
    '🎵', '🌟', '💪', '🙌', '😍', '🤩', '👏', '🎊',
    '🦋', '🌸', '💥', '🎯', '🚀', '💎', '🌙', '⚡️',
  ];
  @override
  Widget build(BuildContext context) => Container(
    height: 260,
    decoration: BoxDecoration(
      color: const Color(0xFF141414).withValues(alpha: 0.96),
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
    ),
    child: Column(
      children: [
        const SizedBox(height: 10),
        Container(
          width: 38,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.white24,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const Padding(
          padding: EdgeInsets.all(14),
          child: Text(
            'Nhãn dán cảm xúc (Chạm đúp để xóa)',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 6,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
            ),
            itemCount: _emojis.length,
            itemBuilder: (ctx, i) => GestureDetector(
              onTap: () {
                context.read<CameraBloc>().add(
                  CameraStickerAdded(
                    StickerItem(
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      emoji: _emojis[i],
                      label: _emojis[i],
                      position: const Offset(120, 220),
                    ),
                  ),
                );
                Navigator.pop(context);
              },
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    _emojis[i],
                    style: const TextStyle(fontSize: 28),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _TextSheet extends StatefulWidget {
  const _TextSheet();
  @override
  State<_TextSheet> createState() => _TextSheetState();
}

class _TextSheetState extends State<_TextSheet> {
  final _ctrl = TextEditingController();
  Color _color = Colors.white;
  double _size = 24;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _ctrl.text.trim();
    if (text.isEmpty) {
      Navigator.pop(context);
      return;
    }
    context.read<CameraBloc>().add(
      CameraTextAdded(
        TextOverlay(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          text: text,
          color: _color,
          fontSize: _size,
          position: const Offset(60, 180),
        ),
      ),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: const Color(0xFF141414).withValues(alpha: 0.96),
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
    ),
    child: SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 12,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(
                children: [
                  const Text(
                    'Thêm chữ lên video',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _submit,
                    style: TextButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    child: const Text(
                      'Xong',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                children: [
                  Colors.white,
                  const Color(0xFFFF2D55),
                  Colors.amber,
                  Colors.greenAccent,
                  Colors.lightBlueAccent,
                  Colors.pinkAccent,
                  Colors.orangeAccent,
                  Colors.purpleAccent,
                ]
                    .map(
                      (c) => GestureDetector(
                        onTap: () => setState(() => _color = c),
                        child: Container(
                          width: 30,
                          height: 30,
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const Text(
                    'Cỡ chữ',
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  Expanded(
                    child: Slider(
                      value: _size,
                      min: 16,
                      max: 48,
                      activeColor: AppColors.primary,
                      onChanged: (v) => setState(() => _size = v),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _ctrl,
                autofocus: true,
                maxLines: 2,
                style: TextStyle(
                  color: _color,
                  fontSize: _size,
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  hintText: 'Nhập nội dung chữ...',
                  hintStyle: const TextStyle(
                    color: Colors.white30,
                    fontSize: 18,
                  ),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.05),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                onSubmitted: (_) => _submit(),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

// ─── Real-Time Interactive Beauty Sheet ──────────────────────────────────────

class _BeautySheet extends StatelessWidget {
  const _BeautySheet();

  @override
  Widget build(BuildContext context) => BlocBuilder<CameraBloc, CameraState>(
    builder: (ctx, state) {
      final effects = state.beautyEffects.isEmpty
          ? AppBeautyEffects.defaults()
          : state.beautyEffects;

      return Container(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 20),
        decoration: BoxDecoration(
          // Nền bán trong suốt để người dùng nhìn trực tiếp gương mặt khi kéo thanh trượt
          color: const Color(0xFF101014).withValues(alpha: 0.82),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(
            top: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(
                    Icons.face_retouching_natural_rounded,
                    color: AppColors.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Làm đẹp gương mặt',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      for (final e in effects) {
                        ctx.read<CameraBloc>().add(
                          CameraBeautyEffectChanged(effectId: e.id, value: 0.0),
                        );
                      }
                    },
                    child: const Text(
                      'Đặt lại',
                      style: TextStyle(color: Colors.white60, fontSize: 12),
                    ),
                  ),
                  Switch(
                    value: state.beautyEnabled,
                    activeThumbColor: AppColors.primary,
                    onChanged: (_) =>
                        ctx.read<CameraBloc>().add(const CameraBeautyToggled()),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ...effects.map(
                (e) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            e.icon,
                            color: state.beautyEnabled
                                ? AppColors.primary
                                : Colors.white38,
                            size: 17,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            e.name,
                            style: TextStyle(
                              color: state.beautyEnabled
                                  ? Colors.white
                                  : Colors.white54,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${(e.value * 100).round()}%',
                              style: TextStyle(
                                color: state.beautyEnabled
                                    ? AppColors.primary
                                    : Colors.white38,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 4,
                          thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 8,
                          ),
                          overlayShape: const RoundSliderOverlayShape(
                            overlayRadius: 16,
                          ),
                        ),
                        child: Slider(
                          value: e.value.clamp(0.0, 1.0),
                          min: 0.0,
                          max: 1.0,
                          activeColor: AppColors.primary,
                          inactiveColor: Colors.white24,
                          onChanged: (v) => ctx.read<CameraBloc>().add(
                            CameraBeautyEffectChanged(effectId: e.id, value: v),
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
      );
    },
  );
}

// ─── Real Online Music Sheet (V-Pop, US-UK, K-Pop, Remix) ────────────────────

class _MusicSheet extends StatefulWidget {
  const _MusicSheet();

  @override
  State<_MusicSheet> createState() => _MusicSheetState();
}

class _MusicSheetState extends State<_MusicSheet> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  final TextEditingController _searchCtrl = TextEditingController();
  Timer? _debounce;

  String? _playingTrackId;
  bool _isLoadingAudio = false;
  bool _isFetchingTracks = true;
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
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _loadCategory(String category) async {
    setState(() {
      _selectedCategory = category;
      _isFetchingTracks = true;
    });
    final list = await MusicSearchService.getTracksByCategory(category);
    if (!mounted) return;
    setState(() {
      _tracks = list;
      _isFetchingTracks = false;
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
      setState(() => _isFetchingTracks = true);
      final results = await MusicSearchService.searchTracks(
        q,
        categoryLabel: _selectedCategory,
      );
      if (!mounted) return;
      setState(() {
        _tracks = results;
        _isFetchingTracks = false;
      });
    });
  }

  Future<void> _togglePreview(MusicTrack track) async {
    if (_playingTrackId == track.id) {
      await _audioPlayer.stop();
      if (mounted) setState(() => _playingTrackId = null);
      return;
    }

    if (track.previewUrl == null || track.previewUrl!.isEmpty) return;

    setState(() {
      _playingTrackId = track.id;
      _isLoadingAudio = true;
    });

    try {
      await _audioPlayer.setUrl(track.previewUrl!);
      await _audioPlayer.setLoopMode(LoopMode.one);
      await _audioPlayer.play();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Không thể phát bản nghe thử lúc này'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingAudio = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CameraBloc, CameraState>(
      builder: (ctx, state) => Container(
        height: MediaQuery.of(context).size.height * 0.76,
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
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 10),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF2D55), Color(0xFFFF6B00)],
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.library_music_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Kho âm nhạc ShareCo',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          'Chọn nhạc trước — Nhạc sẽ tự động phát ngay khi bấm Quay',
                          style: TextStyle(color: Colors.white54, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  if (state.selectedMusic != null)
                    TextButton(
                      onPressed: () {
                        _audioPlayer.stop();
                        ctx
                            .read<CameraBloc>()
                            .add(const CameraMusicSelected(null));
                        Navigator.pop(context);
                      },
                      child: const Text(
                        'Bỏ chọn',
                        style: TextStyle(color: Colors.redAccent, fontSize: 12),
                      ),
                    ),
                ],
              ),
            ),
            // Thanh tìm kiếm bài hát Việt, Anh, Hàn...
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _searchCtrl,
                onChanged: _onSearchChanged,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  hintText:
                      'Tìm bài hát Việt, US-UK, K-Pop, ca sĩ (Sơn Tùng, Rosé, BTS...)',
                  hintStyle: const TextStyle(
                    color: Colors.white30,
                    fontSize: 12.5,
                  ),
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    color: Colors.white38,
                    size: 18,
                  ),
                  suffixIcon: _searchCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(
                            Icons.clear_rounded,
                            color: Colors.white38,
                            size: 16,
                          ),
                          onPressed: () {
                            _searchCtrl.clear();
                            _loadCategory(_selectedCategory);
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: const Color(0xFF1E1E26),
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            // Danh mục nhạc: Thịnh hành | Nhạc Việt | Nhạc Anh | Nhạc Hàn | Remix / EDM
            SizedBox(
              height: 34,
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
                        horizontal: 14,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: active
                            ? AppColors.primary
                            : const Color(0xFF1E1E26),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Text(
                        cat,
                        style: TextStyle(
                          color: active ? Colors.white : Colors.white60,
                          fontSize: 12,
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
            const SizedBox(height: 10),
            const Divider(height: 1, color: Color(0xFF22222A)),
            Expanded(
              child: _isFetchingTracks
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                        strokeWidth: 2,
                      ),
                    )
                  : _tracks.isEmpty
                  ? const Center(
                      child: Text(
                        'Không tìm thấy bài hát phù hợp',
                        style: TextStyle(color: Colors.white54, fontSize: 13),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      itemCount: _tracks.length,
                      itemBuilder: (_, i) {
                        final t = _tracks[i];
                        final selected = state.selectedMusic?.id == t.id;
                        final isPlaying = _playingTrackId == t.id;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: selected
                                ? AppColors.primary.withValues(alpha: 0.14)
                                : const Color(0xFF1A1A22),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: selected
                                  ? AppColors.primary.withValues(alpha: 0.6)
                                  : Colors.white.withValues(alpha: 0.05),
                            ),
                          ),
                          child: Row(
                            children: [
                              GestureDetector(
                                onTap: () => _togglePreview(t),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    width: 48,
                                    height: 48,
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
                                        Center(
                                          child: isPlaying && _isLoadingAudio
                                              ? const SizedBox(
                                                  width: 20,
                                                  height: 20,
                                                  child:
                                                      CircularProgressIndicator(
                                                        color: Colors.white,
                                                        strokeWidth: 2,
                                                      ),
                                                )
                                              : Icon(
                                                  isPlaying
                                                      ? Icons.pause_rounded
                                                      : Icons
                                                            .play_arrow_rounded,
                                                  color: Colors.white,
                                                  size: 26,
                                                ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => _togglePreview(t),
                                  behavior: HitTestBehavior.opaque,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Flexible(
                                            child: Text(
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
                                          ),
                                          if (isPlaying) ...[
                                            const SizedBox(width: 6),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 6,
                                                    vertical: 2,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: AppColors.primary
                                                    .withValues(alpha: 0.2),
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                              child: const Text(
                                                'Đang nghe',
                                                style: TextStyle(
                                                  color: AppColors.primary,
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: 3),
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
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                onPressed: () {
                                  _audioPlayer.stop();
                                  AppMusicTracks.registerDynamicTracks([t]);
                                  ctx.read<CameraBloc>().add(
                                    CameraMusicSelected(selected ? null : t),
                                  );
                                  Navigator.pop(context);
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
                                  selected ? 'Đã chọn' : 'Dùng nhạc',
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
      ),
    );
  }
}

// ─── Helper widgets ───────────────────────────────────────────────────────────

class _CircleIconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _CircleIconBtn({required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white12),
      ),
      child: Icon(icon, color: Colors.white, size: 20),
    ),
  );
}

class _Tool extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool active;
  const _Tool({
    required this.icon,
    required this.label,
    this.onTap,
    this.active = false,
  });
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: active
                ? AppColors.primary.withValues(alpha: 0.35)
                : Colors.white.withValues(alpha: 0.1),
            shape: BoxShape.circle,
            border: active
                ? Border.all(color: AppColors.primary, width: 1.5)
                : null,
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: active ? AppColors.primary : Colors.white,
            fontSize: 10,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            shadows: const [Shadow(color: Colors.black87, blurRadius: 4)],
          ),
        ),
      ],
    ),
  );
}
