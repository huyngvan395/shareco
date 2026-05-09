// features/video/presentation/screen/video_edit_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shareco/features/video/presentation/bloc/create_video_event.dart';
import 'package:shareco/features/video/presentation/bloc/create_video_state.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../domain/entities/filter_entity.dart';
import '../bloc/create_video_bloc.dart';

class VideoEditScreen extends StatefulWidget {
  final String localVideoPath;
  final String? thumbnailPath;

  const VideoEditScreen({
    super.key,
    required this.localVideoPath,
    this.thumbnailPath,
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
    _tabCtrl = TabController(length: 3, vsync: this);
    context.read<CreateVideoBloc>().add(CreateVideoPickedFromPath(
      localPath: widget.localVideoPath,
      thumbnailPath: widget.thumbnailPath ?? '',
    ));
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
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Video posted! 🎉'), backgroundColor: AppColors.success));
          Navigator.of(context).popUntil((r) => r.isFirst);
        } else if (state is CreateVideoError) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(state.message), backgroundColor: AppColors.error));
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          title: const Text('Post Video', style: TextStyle(fontWeight: FontWeight.w700)),
          actions: [
            BlocBuilder<CreateVideoBloc, CreateVideoState>(
              builder: (ctx, state) => TextButton(
                onPressed: state is CreateVideoUploading
                    ? null
                    : () => ctx.read<CreateVideoBloc>().add(
                    CreateVideoPostRequested(caption: _captionCtrl.text.trim())),
                child: state is CreateVideoUploading
                    ? const SizedBox(width: 18, height: 18,
                    child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2))
                    : const Text('Post', style: TextStyle(
                    color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 16)),
              ),
            ),
          ],
        ),
        body: BlocBuilder<CreateVideoBloc, CreateVideoState>(
          builder: (_, state) {
            if (state is CreateVideoUploading) {
              return _buildUploading(state.progress);
            }
            return Row(children: [
              // Left: Video thumbnail preview
              Container(
                width: 130, color: Colors.black,
                child: Stack(fit: StackFit.expand, children: [
                  widget.thumbnailPath != null
                      ? Image.asset(widget.thumbnailPath!, fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => _thumbPlaceholder())
                      : _thumbPlaceholder(),
                  Positioned(
                    bottom: 8, left: 0, right: 0,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                            color: Colors.black54, borderRadius: BorderRadius.circular(12)),
                        child: const Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.play_circle_outline, color: Colors.white, size: 16),
                          SizedBox(width: 4),
                          Text('Preview', style: TextStyle(color: Colors.white, fontSize: 11)),
                        ]),
                      ),
                    ),
                  ),
                ]),
              ),

              // Right: Edit tabs
              Expanded(
                child: Column(children: [
                  TabBar(
                    controller: _tabCtrl,
                    indicatorColor: AppColors.primary,
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white38,
                    dividerColor: AppColors.divider,
                    tabs: const [Tab(text: 'Caption'), Tab(text: 'Settings'), Tab(text: 'Effects')],
                  ),
                  Expanded(
                    child: TabBarView(
                      controller: _tabCtrl,
                      children: [
                        _CaptionTab(ctrl: _captionCtrl),
                        const _SettingsTab(),
                        const _EffectsTab(),
                      ],
                    ),
                  ),
                ]),
              ),
            ]);
          },
        ),
      ),
    );
  }

  Widget _thumbPlaceholder() => Container(
      color: AppColors.bgInput,
      child: const Center(
          child: Icon(Icons.video_file_rounded, color: Colors.white24, size: 40)));

  Widget _buildUploading(double progress) => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.cloud_upload_outlined, color: AppColors.primary, size: 56),
      const SizedBox(height: 20),
      const Text('Uploading video...', style: TextStyle(color: Colors.white, fontSize: 16)),
      const SizedBox(height: 20),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 48),
        child: Column(children: [
          LinearProgressIndicator(
            value: progress,
            backgroundColor: AppColors.bgInput,
            valueColor: const AlwaysStoppedAnimation(AppColors.primary),
            minHeight: 6,
          ),
          const SizedBox(height: 8),
          Text('${(progress * 100).round()}%',
              style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
        ]),
      ),
    ]),
  );
}

// ─── Caption tab ──────────────────────────────────────────────────────────────

class _CaptionTab extends StatelessWidget {
  final TextEditingController ctrl;
  const _CaptionTab({required this.ctrl});

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(14),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      TextField(
        controller: ctrl,
        maxLines: 5, maxLength: 2200,
        style: const TextStyle(color: Colors.white, fontSize: 13),
        decoration: InputDecoration(
          hintText: 'Describe your video...\n#trending #fyp',
          hintStyle: const TextStyle(color: Colors.white24, height: 1.6, fontSize: 12),
          filled: true, fillColor: AppColors.bgInput,
          counterStyle: const TextStyle(color: Colors.white38),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
        ),
      ),
      const SizedBox(height: 12),
      const Text('Trending', style: TextStyle(color: Colors.white38, fontSize: 11)),
      const SizedBox(height: 6),
      Wrap(spacing: 6, runSpacing: 6,
          children: ['#fyp','#viral','#trending','#foryou','#dance','#funny','#music','#life']
              .map((tag) => GestureDetector(
            onTap: () {
              final t = ctrl.text;
              ctrl.text = '$t${t.isEmpty || t.endsWith(' ') ? '' : ' '}$tag ';
              ctrl.selection = TextSelection.fromPosition(
                  TextPosition(offset: ctrl.text.length));
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.primary.withOpacity(0.3)),
              ),
              child: Text(tag, style: const TextStyle(color: AppColors.primary, fontSize: 11)),
            ),
          )).toList()),
    ]),
  );
}

// ─── Settings tab ─────────────────────────────────────────────────────────────

class _SettingsTab extends StatelessWidget {
  const _SettingsTab();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CreateVideoBloc, CreateVideoState>(
      builder: (ctx, state) {
        final picked = state is CreateVideoPickedFile ? state : null;
        if (picked == null) return const SizedBox.shrink();
        return ListView(padding: const EdgeInsets.all(14), children: [
          const _SLabel('Who can watch'),
          const SizedBox(height: 8),
          ...[
            ('public',    Icons.public,       'Everyone'),
            ('followers', Icons.people_outline,'Followers only'),
            ('private',   Icons.lock_outline,  'Only me'),
          ].map((o) => _RadioTile(
              icon: o.$2, label: o.$3,
              selected: picked.visibility == o.$1,
              onTap: () => ctx.read<CreateVideoBloc>()
                  .add(CreateVideoVisibilityChanged(o.$1)))),
          const Divider(color: AppColors.divider, height: 24),
          const _SLabel('Interactions'),
          const SizedBox(height: 8),
          _Switch(icon: Icons.chat_bubble_outline, label: 'Allow Comments',
              value: picked.allowComment,
              onChanged: (v) => ctx.read<CreateVideoBloc>()
                  .add(CreateVideoSettingChanged(allowComment: v))),
          _Switch(icon: Icons.people_outline, label: 'Allow Duet',
              value: picked.allowDuet,
              onChanged: (v) => ctx.read<CreateVideoBloc>()
                  .add(CreateVideoSettingChanged(allowDuet: v))),
          _Switch(icon: Icons.cut_outlined, label: 'Allow Stitch',
              value: picked.allowStitch,
              onChanged: (v) => ctx.read<CreateVideoBloc>()
                  .add(CreateVideoSettingChanged(allowStitch: v))),
        ]);
      },
    );
  }
}

// ─── Effects tab ──────────────────────────────────────────────────────────────

class _EffectsTab extends StatelessWidget {
  const _EffectsTab();

  @override
  Widget build(BuildContext context) => GridView.builder(
    padding: const EdgeInsets.all(10),
    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3, crossAxisSpacing: 6, mainAxisSpacing: 6, childAspectRatio: 0.8),
    itemCount: AppFilters.all.length,
    itemBuilder: (_, i) {
      final f = AppFilters.all[i];
      return Column(children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: f.colorFilter != null
                ? ColorFiltered(colorFilter: f.colorFilter!,
                child: Container(color: Colors.teal.shade300,
                    child: const Center(child: Icon(Icons.play_circle_fill,
                        color: Colors.white54, size: 28))))
                : Container(color: AppColors.bgInput,
                child: const Center(child: Icon(Icons.play_circle_fill,
                    color: Colors.white54, size: 28))),
          ),
        ),
        const SizedBox(height: 3),
        Text(f.name, style: const TextStyle(color: Colors.white54, fontSize: 10)),
      ]);
    },
  );
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

class _SLabel extends StatelessWidget {
  final String text;
  const _SLabel(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.w600));
}

class _RadioTile extends StatelessWidget {
  final IconData icon; final String label; final bool selected; final VoidCallback onTap;
  const _RadioTile({required this.icon, required this.label, required this.selected, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
          color: selected ? AppColors.primary.withOpacity(0.1) : AppColors.bgInput,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: selected ? AppColors.primary : Colors.transparent)),
      child: Row(children: [
        Icon(icon, color: selected ? AppColors.primary : Colors.white38, size: 18),
        const SizedBox(width: 10),
        Text(label, style: TextStyle(color: selected ? Colors.white : Colors.white54, fontSize: 13)),
        const Spacer(),
        if (selected) const Icon(Icons.check_circle, color: AppColors.primary, size: 16),
      ]),
    ),
  );
}

class _Switch extends StatelessWidget {
  final IconData icon; final String label; final bool value; final ValueChanged<bool> onChanged;
  const _Switch({required this.icon, required this.label, required this.value, required this.onChanged});
  @override
  Widget build(BuildContext context) => Row(children: [
    Icon(icon, color: Colors.white38, size: 18),
    const SizedBox(width: 10),
    Text(label, style: const TextStyle(color: Colors.white, fontSize: 13)),
    const Spacer(),
    Switch(value: value, onChanged: onChanged, activeColor: AppColors.primary),
  ]);
}