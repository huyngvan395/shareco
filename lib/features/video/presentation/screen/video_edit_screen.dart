// features/video/presentation/screen/video_edit_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shareco/core/notifier/video_posted_notifier.dart';
import 'package:shareco/features/video/presentation/bloc/create_video_event.dart';
import 'package:shareco/features/video/presentation/bloc/create_video_state.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../domain/entities/filter_entity.dart';
import '../bloc/create_video_bloc.dart';

class VideoEditScreen extends StatefulWidget {
  final String localVideoPath;
  final String? thumbnailPath;
  final VoidCallback? onVideoPosted;

  const VideoEditScreen({
    super.key,
    required this.localVideoPath,
    this.thumbnailPath,
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
          VideoPostedNotifier.instance.notify();
          widget.onVideoPosted?.call();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Đăng video thành công! '),
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
        backgroundColor: const Color(0xFF0A0A0A),
        appBar: _buildAppBar(),
        body: BlocBuilder<CreateVideoBloc, CreateVideoState>(
          builder: (_, state) {
            if (state is CreateVideoUploading) {
              return _buildUploading(state.progress);
            }
            return Column(
              children: [
                // ── Preview strip ──────────────────────────────────────────
                _VideoPreviewStrip(
                  localVideoPath: widget.localVideoPath,
                  thumbnailPath: widget.thumbnailPath,
                ),
                const Divider(height: 1, color: Color(0xFF1E1E1E)),

                // ── Edit panels ────────────────────────────────────────────
                TabBar(
                  controller: _tabCtrl,
                  indicatorColor: AppColors.primary,
                  indicatorWeight: 2,
                  labelColor: Colors.white,
                  unselectedLabelColor: const Color(0xFF666666),
                  dividerColor: const Color(0xFF1E1E1E),
                  labelStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  tabs: const [
                    Tab(text: 'Mô tả'),
                    Tab(text: 'Ảnh bìa'),
                    Tab(text: 'Cài đặt'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabCtrl,
                    children: [
                      _CaptionTab(ctrl: _captionCtrl),
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
    backgroundColor: const Color(0xFF0A0A0A),
    foregroundColor: Colors.white,
    elevation: 0,
    centerTitle: true,
    title: const Text(
      'Đăng video',
      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
    ),
    actions: [
      BlocBuilder<CreateVideoBloc, CreateVideoState>(
        builder: (ctx, state) => Padding(
          padding: const EdgeInsets.only(right: 8),
          child: TextButton(
            onPressed: state is CreateVideoUploading
                ? null
                : () => ctx.read<CreateVideoBloc>().add(
              CreateVideoPostRequested(
                caption: _captionCtrl.text.trim(),
              ),
            ),
            style: TextButton.styleFrom(
              backgroundColor: state is CreateVideoUploading
                  ? Colors.transparent
                  : AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            child: state is CreateVideoUploading
                ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                color: AppColors.primary,
                strokeWidth: 2,
              ),
            )
                : const Text(
              'Đăng',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ),
    ],
  );

  Widget _buildUploading(double progress) => Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 48),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.cloud_upload_outlined,
              color: AppColors.primary,
              size: 36,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Đang tải video lên...',
            style: TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Vui lòng giữ ứng dụng đang mở',
            style: TextStyle(
              color: Colors.white.withOpacity(0.4),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 28),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: const Color(0xFF1E1E1E),
              valueColor:
              const AlwaysStoppedAnimation(AppColors.primary),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '${(progress * 100).round()}%',
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    ),
  );
}

// ─── Video preview strip ───────────────────────────────────────────────────────

class _VideoPreviewStrip extends StatelessWidget {
  final String localVideoPath;
  final String? thumbnailPath;

  const _VideoPreviewStrip({
    required this.localVideoPath,
    this.thumbnailPath,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 160,
      color: Colors.black,
      child: Row(
        children: [
          // Thumbnail preview
          AspectRatio(
            aspectRatio: 9 / 16,
            child: Stack(
              fit: StackFit.expand,
              children: [
                _buildThumbnail(),
                // Play overlay
                Center(
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.55),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Video info
          Expanded(
            child: Padding(
              padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Video đã sẵn sàng',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _truncatePath(localVideoPath),
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.45),
                      fontSize: 11,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _InfoChip(
                        icon: Icons.hd_rounded,
                        label: 'HD',
                      ),
                      const SizedBox(width: 6),
                      _InfoChip(
                        icon: Icons.videocam_rounded,
                        label: 'MP4',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThumbnail() {
    if (thumbnailPath != null && thumbnailPath!.isNotEmpty) {
      final file = File(thumbnailPath!);
      if (file.existsSync()) {
        return Image.file(file, fit: BoxFit.cover);
      }
    }
    return Container(
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

  String _truncatePath(String path) {
    final parts = path.split('/');
    return parts.last;
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => Container(
    padding:
    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.08),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white54, size: 12),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    ),
  );
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
      ],
    ),
  );
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