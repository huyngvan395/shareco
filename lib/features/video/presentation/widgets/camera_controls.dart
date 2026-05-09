// features/video/presentation/widgets/camera_controls.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shareco/features/video/presentation/bloc/camera_event.dart';
import 'package:shareco/features/video/presentation/bloc/camera_state.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../domain/entities/filter_entity.dart';
import '../bloc/camera_bloc.dart';

// ─── Top bar ──────────────────────────────────────────────────────────────────

class CameraTopBar extends StatelessWidget {
  final VoidCallback onClose;
  const CameraTopBar({super.key, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CameraBloc, CameraState>(
      builder: (ctx, state) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(children: [
            _Btn(icon: Icons.close, onTap: onClose),
            const Spacer(),
            _Btn(
              icon: switch (state.flashMode) {
                FlashMode.off  => Icons.flash_off,
                FlashMode.on   => Icons.flash_on,
                FlashMode.auto => Icons.flash_auto,
              },
              onTap: () => ctx.read<CameraBloc>().add(const CameraFlashToggled()),
            ),
            const SizedBox(width: 10),
            _Btn(
              icon: Icons.face_retouching_natural,
              onTap: () => ctx.read<CameraBloc>().add(const CameraBeautyToggled()),
              active: state.beautyEnabled,
            ),
            const SizedBox(width: 10),
            _Btn(
              icon: Icons.music_note_rounded,
              onTap: () => _showMusic(context),
              active: state.selectedMusic != null,
            ),
            const SizedBox(width: 10),
            _Btn(icon: Icons.timer_outlined, onTap: () {}),
          ]),
        ),
      ),
    );
  }

  void _showMusic(BuildContext ctx) => showModalBottomSheet(
    context: ctx,
    backgroundColor: AppColors.bgCard,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    builder: (_) => BlocProvider.value(value: ctx.read<CameraBloc>(), child: const _MusicSheet()),
  );
}

// ─── Right tools ──────────────────────────────────────────────────────────────

class CameraRightTools extends StatelessWidget {
  const CameraRightTools({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CameraBloc, CameraState>(
      builder: (ctx, state) => Column(mainAxisSize: MainAxisSize.min, children: [
        _Tool(icon: Icons.flip_camera_ios_outlined, label: 'Flip',
            onTap: state.isRecording ? null
                : () => ctx.read<CameraBloc>().add(const CameraFlipRequested())),
        const SizedBox(height: 20),
        _Tool(icon: Icons.emoji_emotions_outlined, label: 'Stickers',
            onTap: () => _showStickers(context)),
        const SizedBox(height: 20),
        _Tool(icon: Icons.text_fields_rounded, label: 'Text',
            onTap: () => _showText(context)),
        const SizedBox(height: 20),
        _Tool(icon: Icons.auto_awesome, label: 'Filters',
            onTap: () => _showFilters(context)),
        const SizedBox(height: 20),
        _Tool(icon: Icons.face_retouching_natural, label: 'Beauty',
            active: state.beautyEnabled,
            onTap: () => state.beautyEnabled
                ? _showBeauty(context)
                : ctx.read<CameraBloc>().add(const CameraBeautyToggled())),
      ]),
    );
  }

  void _showStickers(BuildContext ctx) => showModalBottomSheet(
    context: ctx,
    backgroundColor: AppColors.bgCard,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    builder: (_) => BlocProvider.value(value: ctx.read<CameraBloc>(), child: const _StickerSheet()),
  );

  void _showText(BuildContext ctx) => showModalBottomSheet(
    context: ctx,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => BlocProvider.value(value: ctx.read<CameraBloc>(), child: const _TextSheet()),
  );

  void _showFilters(BuildContext ctx) => showModalBottomSheet(
    context: ctx,
    backgroundColor: AppColors.bgCard,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    builder: (_) => BlocProvider.value(value: ctx.read<CameraBloc>(), child: const _FilterSheet()),
  );

  void _showBeauty(BuildContext ctx) => showModalBottomSheet(
    context: ctx,
    backgroundColor: AppColors.bgCard,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    builder: (_) => BlocProvider.value(value: ctx.read<CameraBloc>(), child: const _BeautySheet()),
  );
}

// ─── Duration selector ────────────────────────────────────────────────────────

class DurationLimitSelector extends StatelessWidget {
  const DurationLimitSelector({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CameraBloc, CameraState>(
      builder: (ctx, state) => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: AppDurationLimits.limits.map((limit) {
          final selected = state.durationLimit.label == limit.label;
          return GestureDetector(
            onTap: state.isRecording ? null
                : () => ctx.read<CameraBloc>().add(CameraDurationLimitChanged(limit)),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 5),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: selected ? Colors.white : Colors.white24,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(limit.label, style: TextStyle(
                  color: selected ? Colors.black : Colors.white,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                  fontSize: 13)),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─── Speed selector ───────────────────────────────────────────────────────────

class SpeedSelector extends StatelessWidget {
  const SpeedSelector({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CameraBloc, CameraState>(
      builder: (ctx, state) => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: AppSpeeds.speeds.map((speed) {
          final selected = state.activeSpeed.value == speed.value;
          return GestureDetector(
            onTap: state.isRecording ? null
                : () => ctx.read<CameraBloc>().add(CameraSpeedChanged(speed)),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: selected ? AppColors.primary : Colors.white24,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(speed.label, style: TextStyle(
                  color: Colors.white,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                  fontSize: 12)),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─── Progress bar ─────────────────────────────────────────────────────────────

class RecordingProgressBar extends StatelessWidget {
  const RecordingProgressBar({super.key});

  String _fmt(Duration d) {
    if (d.inSeconds < 0) return '0:00';
    return '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CameraBloc, CameraState>(
      buildWhen: (p, c) =>
      p.recordedDuration != c.recordedDuration || p.isRecording != c.isRecording,
      builder: (_, state) {
        if (!state.isRecording && state.recordedDuration == Duration.zero) {
          return const SizedBox.shrink();
        }
        final remaining = state.durationLimit.max - state.recordedDuration;
        return Column(children: [
          Text(_fmt(remaining),
              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: state.recordingProgress,
            backgroundColor: Colors.white24,
            valueColor: AlwaysStoppedAnimation(
                state.recordingProgress > 0.8 ? Colors.red : AppColors.primary),
            minHeight: 4,
          ),
        ]);
      },
    );
  }
}

// ─── Record button ────────────────────────────────────────────────────────────

class RecordButton extends StatefulWidget {
  const RecordButton({super.key});
  @override State<RecordButton> createState() => _RecordButtonState();
}

class _RecordButtonState extends State<RecordButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _anim;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 150));
    _scale = Tween(begin: 1.0, end: 0.87)
        .animate(CurvedAnimation(parent: _anim, curve: Curves.easeOut));
  }

  @override
  void dispose() { _anim.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CameraBloc, CameraState>(
      builder: (ctx, state) {
        final isRec = state.isRecording;
        final isPaused = state.isPaused;
        return GestureDetector(
          onTapDown: (_) => _anim.forward(),
          onTapUp: (_) {
            _anim.reverse();
            if (!isRec) {
              ctx.read<CameraBloc>().add(const CameraRecordStarted());
            } else if (isPaused) {
              ctx.read<CameraBloc>().add(const CameraRecordResumed());
            } else {
              ctx.read<CameraBloc>().add(const CameraRecordPaused());
            }
          },
          onTapCancel: () => _anim.reverse(),
          child: ScaleTransition(
            scale: _scale,
            child: Stack(alignment: Alignment.center, children: [
              Container(
                width: 80, height: 80,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: isRec ? AppColors.primary : Colors.white, width: 4)),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: isRec ? 34 : 64, height: isRec ? 34 : 64,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: isRec ? BoxShape.rectangle : BoxShape.circle,
                  borderRadius: isRec ? BorderRadius.circular(8) : null,
                ),
              ),
              if (isRec && !isPaused) const Icon(Icons.pause, color: Colors.white, size: 18),
              if (isPaused) const Icon(Icons.play_arrow, color: Colors.white, size: 22),
            ]),
          ),
        );
      },
    );
  }
}

// ─── Stop button ──────────────────────────────────────────────────────────────

class StopRecordButton extends StatelessWidget {
  const StopRecordButton({super.key});
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CameraBloc, CameraState>(
      builder: (ctx, state) => AnimatedOpacity(
        opacity: state.isRecording ? 1 : 0,
        duration: const Duration(milliseconds: 200),
        child: GestureDetector(
          onTap: state.isRecording
              ? () => ctx.read<CameraBloc>().add(const CameraRecordStopped()) : null,
          child: Container(
            width: 48, height: 48,
            decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle,
                border: Border.all(color: Colors.white30, width: 2)),
            child: const Icon(Icons.stop_rounded, color: Colors.red, size: 28),
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
        children: state.stickers.map((s) => Positioned(
          left: s.position.dx, top: s.position.dy,
          child: GestureDetector(
            onPanUpdate: (d) => ctx.read<CameraBloc>().add(
                CameraStickerMoved(stickerId: s.id, position: s.position + d.delta)),
            onDoubleTap: () => ctx.read<CameraBloc>().add(CameraStickerRemoved(s.id)),
            child: Transform.rotate(angle: s.rotation,
                child: Transform.scale(scale: s.scale,
                    child: Text(s.emoji, style: const TextStyle(fontSize: 40)))),
          ),
        )).toList(),
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
        children: state.textOverlays.map((t) => Positioned(
          left: t.position.dx, top: t.position.dy,
          child: GestureDetector(
            onDoubleTap: () => ctx.read<CameraBloc>().add(CameraTextRemoved(t.id)),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: Colors.black38, borderRadius: BorderRadius.circular(4)),
              child: Text(t.text, style: TextStyle(color: t.color, fontSize: t.fontSize,
                  fontWeight: FontWeight.w700,
                  shadows: const [Shadow(color: Colors.black54, blurRadius: 4)]),
                  textAlign: t.align),
            ),
          ),
        )).toList(),
      ),
    );
  }
}

// ─── Music bar ────────────────────────────────────────────────────────────────

class MusicBar extends StatelessWidget {
  const MusicBar({super.key});
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CameraBloc, CameraState>(
      buildWhen: (p, c) => p.selectedMusic != c.selectedMusic,
      builder: (ctx, state) {
        if (state.selectedMusic == null) return const SizedBox.shrink();
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(20)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.music_note_rounded, color: Colors.white, size: 14),
            const SizedBox(width: 6),
            Text('${state.selectedMusic!.title} · ${state.selectedMusic!.artist}',
                style: const TextStyle(color: Colors.white, fontSize: 12)),
            const SizedBox(width: 8),
            GestureDetector(
                onTap: () => ctx.read<CameraBloc>().add(const CameraMusicSelected(null)),
                child: const Icon(Icons.close, color: Colors.white70, size: 14)),
          ]),
        );
      },
    );
  }
}

// ─── Sheet widgets ────────────────────────────────────────────────────────────

class _FilterSheet extends StatelessWidget {
  const _FilterSheet();
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CameraBloc, CameraState>(
      builder: (ctx, state) => SizedBox(
        height: 160,
        child: Column(children: [
          const Padding(padding: EdgeInsets.all(12),
              child: Text('Filters', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16))),
          Expanded(child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: AppFilters.all.length,
            itemBuilder: (_, i) {
              final f = AppFilters.all[i];
              final active = state.activeFilter.id == f.id;
              return GestureDetector(
                onTap: () { ctx.read<CameraBloc>().add(CameraFilterChanged(f)); Navigator.pop(context); },
                child: Container(
                  margin: const EdgeInsets.only(right: 12),
                  child: Column(children: [
                    Container(
                        width: 64, height: 80,
                        decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: active ? AppColors.primary : Colors.transparent, width: 2),
                            color: AppColors.bgInput),
                        child: f.colorFilter != null
                            ? ColorFiltered(colorFilter: f.colorFilter!,
                            child: Container(color: Colors.teal.shade200)) : null),
                    const SizedBox(height: 5),
                    Text(f.name, style: TextStyle(
                        color: active ? AppColors.primary : Colors.white54, fontSize: 11)),
                  ]),
                ),
              );
            },
          )),
        ]),
      ),
    );
  }
}

class _StickerSheet extends StatelessWidget {
  const _StickerSheet();
  static const _emojis = ['🔥','❤️','😂','🎉','✨','💯','👑','🌈','🎵','🌟',
    '💪','🙌','😍','🤩','👏','🎊','🦋','🌸','💥','🎯','🚀','💎','🌙','⚡️'];
  @override
  Widget build(BuildContext context) => SizedBox(
    height: 220,
    child: Column(children: [
      const Padding(padding: EdgeInsets.all(12),
          child: Text('Stickers', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16))),
      Expanded(child: GridView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 8, mainAxisSpacing: 8, crossAxisSpacing: 8),
        itemCount: _emojis.length,
        itemBuilder: (ctx, i) => GestureDetector(
          onTap: () {
            context.read<CameraBloc>().add(CameraStickerAdded(StickerItem(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                emoji: _emojis[i], label: _emojis[i], position: const Offset(100, 200))));
            Navigator.pop(context);
          },
          child: Center(child: Text(_emojis[i], style: const TextStyle(fontSize: 28))),
        ),
      )),
    ]),
  );
}

class _TextSheet extends StatefulWidget {
  const _TextSheet();
  @override State<_TextSheet> createState() => _TextSheetState();
}

class _TextSheetState extends State<_TextSheet> {
  final _ctrl = TextEditingController();
  Color _color = Colors.white;
  double _size = 24;

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Container(
    color: Colors.black87,
    child: SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
      SizedBox(height: 48, child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          children: [Colors.white, Colors.red, Colors.yellow, Colors.green,
            Colors.blue, Colors.pink, Colors.orange, Colors.purple]
              .map((c) => GestureDetector(
            onTap: () => setState(() => _color = c),
            child: Container(width: 28, height: 28, margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(color: c, shape: BoxShape.circle,
                    border: Border.all(color: _color == c ? Colors.white : Colors.transparent, width: 2))),
          )).toList())),
      Slider(value: _size, min: 14, max: 60, activeColor: AppColors.primary,
          onChanged: (v) => setState(() => _size = v)),
      Padding(
        padding: EdgeInsets.only(left: 16, right: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16),
        child: TextField(
          controller: _ctrl, autofocus: true, maxLines: 3,
          style: TextStyle(color: _color, fontSize: _size),
          textAlign: TextAlign.center,
          decoration: const InputDecoration(
              hintText: 'Add text...', hintStyle: TextStyle(color: Colors.white38), border: InputBorder.none),
          onSubmitted: (text) {
            if (text.trim().isEmpty) return;
            context.read<CameraBloc>().add(CameraTextAdded(TextOverlay(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                text: text.trim(), color: _color, fontSize: _size, position: const Offset(60, 180))));
            Navigator.pop(context);
          },
        ),
      ),
    ])),
  );
}

class _BeautySheet extends StatelessWidget {
  const _BeautySheet();
  @override
  Widget build(BuildContext context) => BlocBuilder<CameraBloc, CameraState>(
    builder: (ctx, state) => Padding(
      padding: const EdgeInsets.all(16),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Beauty', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
        const SizedBox(height: 16),
        ...state.beautyEffects.map((e) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(e.icon, color: AppColors.primary, size: 18),
            const SizedBox(width: 8),
            Text(e.name, style: const TextStyle(color: Colors.white, fontSize: 14)),
            const Spacer(),
            Text('${(e.value * 100).round()}', style: const TextStyle(color: Colors.white38, fontSize: 12)),
          ]),
          Slider(value: e.value, min: 0, max: 1, activeColor: AppColors.primary,
              onChanged: (v) => ctx.read<CameraBloc>()
                  .add(CameraBeautyEffectChanged(effectId: e.id, value: v))),
        ])),
      ]),
    ),
  );
}

class _MusicSheet extends StatelessWidget {
  const _MusicSheet();
  @override
  Widget build(BuildContext context) => BlocBuilder<CameraBloc, CameraState>(
    builder: (ctx, state) => SizedBox(
      height: 300,
      child: Column(children: [
        const Padding(padding: EdgeInsets.all(16),
            child: Text('Add Music', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16))),
        const Divider(color: AppColors.divider),
        Expanded(child: ListView.builder(
          itemCount: AppMusicTracks.trending.length,
          itemBuilder: (_, i) {
            final t = AppMusicTracks.trending[i];
            final selected = state.selectedMusic?.id == t.id;
            return ListTile(
              leading: Container(width: 44, height: 44,
                  decoration: BoxDecoration(color: AppColors.bgInput, borderRadius: BorderRadius.circular(8)),
                  child: Icon(Icons.music_note_rounded,
                      color: selected ? AppColors.primary : Colors.white38)),
              title: Text(t.title, style: TextStyle(
                  color: selected ? AppColors.primary : Colors.white,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w400)),
              subtitle: Text(t.artist, style: const TextStyle(color: Colors.white38, fontSize: 12)),
              trailing: selected
                  ? const Icon(Icons.check_circle, color: AppColors.primary)
                  : const Icon(Icons.play_circle_outline, color: Colors.white38),
              onTap: () {
                ctx.read<CameraBloc>().add(CameraMusicSelected(selected ? null : t));
                Navigator.pop(context);
              },
            );
          },
        )),
      ]),
    ),
  );
}

// ─── Helper widgets ───────────────────────────────────────────────────────────

class _Btn extends StatelessWidget {
  final IconData icon; final VoidCallback onTap; final bool active;
  const _Btn({required this.icon, required this.onTap, this.active = false});
  @override
  Widget build(BuildContext context) => GestureDetector(
      onTap: onTap,
      child: Container(width: 36, height: 36,
          decoration: BoxDecoration(color: active ? AppColors.primary : Colors.black38, shape: BoxShape.circle),
          child: Icon(icon, color: Colors.white, size: 20)));
}

class _Tool extends StatelessWidget {
  final IconData icon; final String label; final VoidCallback? onTap; final bool active;
  const _Tool({required this.icon, required this.label, this.onTap, this.active = false});
  @override
  Widget build(BuildContext context) => GestureDetector(
      onTap: onTap,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 44, height: 44,
            decoration: BoxDecoration(color: active ? AppColors.primary.withOpacity(0.3) : Colors.black38, shape: BoxShape.circle),
            child: Icon(icon, color: active ? AppColors.primary : Colors.white, size: 22)),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(color: active ? AppColors.primary : Colors.white60, fontSize: 10)),
      ]));
}