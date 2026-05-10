// features/video/presentation/screen/create_video_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../di/injector.dart';
import '../bloc/create_video_bloc.dart';
import 'camera_screen.dart';
import 'livestream_screen.dart';
import 'video_edit_screen.dart';

class CreateVideoScreen extends StatelessWidget {
  const CreateVideoScreen({super.key});

  @override
  Widget build(BuildContext context) => const _CreateEntryView();
}

class _CreateEntryView extends StatelessWidget {
  const _CreateEntryView();

  Future<void> _openCamera(BuildContext context) async {
    await Navigator.push(context, MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => const CameraScreen(),
    ));
  }

  Future<void> _openGallery(BuildContext context) async {
    final file = await ImagePicker().pickVideo(source: ImageSource.gallery);
    if (file == null || !context.mounted) return;
    await Navigator.push(context, MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => BlocProvider(
        create: (_) => CreateVideoBloc(createVideo: sl()),
        child: VideoEditScreen(localVideoPath: file.path),
      ),
    ));
  }

  Future<void> _openLive(BuildContext context) async {
    await Navigator.push(context, MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => const LiveStreamScreen(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(child: Column(children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(24, 32, 24, 0),
          child: Align(alignment: Alignment.centerLeft,
              child: Text('Tạo video', style: TextStyle(color: Colors.white, fontSize: 26,
                  fontWeight: FontWeight.w800))),
        ),
        const SizedBox(height: 6),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 24),
          child: Align(alignment: Alignment.centerLeft,
              child: Text('Chia sẻ khoảnh khắc của bạn với mọi người',
                  style: TextStyle(color: Colors.white38, fontSize: 14))),
        ),
        const SizedBox(height: 36),
        Expanded(child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            _Option(icon: Icons.videocam_rounded, label: 'Quay video',
                subtitle: 'Tối đa 10 phút · Bộ lọc · Hiệu ứng · Nhạc',
                gradient: const [Color(0xFFFF2D55), Color(0xFFFF6535)],
                onTap: () => _openCamera(context)),
            const SizedBox(height: 14),
            _Option(icon: Icons.upload_rounded, label: 'Tải lên từ thư viện',
                subtitle: 'MP4, MOV · Chú thích · Ảnh bìa · Quyền riêng tư',
                gradient: const [Color(0xFF6C63FF), Color(0xFF3D9BE9)],
                onTap: () => _openGallery(context)),
            const SizedBox(height: 14),
            _Option(icon: Icons.live_tv_rounded, label: 'Phát trực tiếp',
                subtitle: 'Phát sóng thời gian thực · Quà tặng · Bình luận',
                gradient: const [Color(0xFF20D5EC), Color(0xFF0F9B8E)],
                onTap: () => _openLive(context)),
          ]),
        )),
        Container(
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: AppColors.bgCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.divider)),
          child: const Row(children: [
            Icon(Icons.lightbulb_outline, color: Colors.amber, size: 18),
            SizedBox(width: 10),
            Expanded(child: Text('Mẹo: Đăng vào giờ cao điểm (19h–21h) để tiếp cận nhiều người hơn.',
                style: TextStyle(color: Colors.white54, fontSize: 12, height: 1.4))),
          ]),
        ),
      ])),
    );
  }
}

class _Option extends StatefulWidget {
  final IconData icon;
  final String label, subtitle;
  final List<Color> gradient;
  final VoidCallback onTap;
  const _Option({required this.icon, required this.label, required this.subtitle,
    required this.gradient, required this.onTap});
  @override State<_Option> createState() => _OptionState();
}

class _OptionState extends State<_Option> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 120));
    _scale = Tween(begin: 1.0, end: 0.96).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }
  @override void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTapDown: (_) => _ctrl.forward(),
    onTapUp: (_) { _ctrl.reverse(); widget.onTap(); },
    onTapCancel: () => _ctrl.reverse(),
    child: ScaleTransition(
      scale: _scale,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
            gradient: LinearGradient(colors: widget.gradient,
                begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: widget.gradient.first.withOpacity(0.3),
                blurRadius: 16, offset: const Offset(0, 6))]),
        child: Row(children: [
          Container(width: 52, height: 52,
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
              child: Icon(widget.icon, color: Colors.white, size: 28)),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(widget.label, style: const TextStyle(color: Colors.white,
                fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 3),
            Text(widget.subtitle, style: TextStyle(
                color: Colors.white.withOpacity(0.7), fontSize: 12, height: 1.4)),
          ])),
          Icon(Icons.arrow_forward_ios_rounded,
              color: Colors.white.withOpacity(0.6), size: 16),
        ]),
      ),
    ),
  );
}