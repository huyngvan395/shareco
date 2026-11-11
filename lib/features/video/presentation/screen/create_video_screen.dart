// features/video/presentation/screen/create_video_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/video_controller_cache.dart';
import '../../../../di/injector.dart';
import '../../../../routes/app_router.dart';
import '../../../wallet/presentation/screen/wallet_screen.dart';
import '../bloc/create_video_bloc.dart';
import 'camera_screen.dart';
import 'livestream_screen.dart';
import 'video_edit_screen.dart';

class CreateVideoScreen extends StatefulWidget {
  const CreateVideoScreen({super.key});

  @override
  State<CreateVideoScreen> createState() => _CreateVideoScreenState();
}

class _CreateVideoScreenState extends State<CreateVideoScreen> {
  @override
  void initState() {
    super.initState();
    VideoControllerCache.pauseAllGlobal();
  }

  void _handleBack(BuildContext context) {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      context.go(Routes.feed);
    }
  }

  Future<void> _openCamera(BuildContext context) async {
    VideoControllerCache.pauseAllGlobal();
    await Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const CameraScreen(),
      ),
    );
  }

  Future<void> _openGallery(BuildContext context) async {
    VideoControllerCache.pauseAllGlobal();
    final file = await ImagePicker().pickVideo(source: ImageSource.gallery);
    if (file == null || !context.mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => BlocProvider(
          create: (_) => CreateVideoBloc(createVideo: sl()),
          child: VideoEditScreen(localVideoPath: file.path),
        ),
      ),
    );
  }

  Future<void> _openLive(BuildContext context) async {
    VideoControllerCache.pauseAllGlobal();
    await Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => LivestreamScreen(
          channelName: 'live_${DateTime.now().millisecondsSinceEpoch}',
          isHost: true,
        ),
      ),
    );
  }

  Future<void> _openWallet(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const WalletScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceDark,
      body: Stack(
        children: [
          // Ambient studio glow accents
          Positioned(
            top: -90,
            right: -70,
            child: IgnorePointer(
              child: Container(
                width: 240,
                height: 240,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.primary.withValues(alpha: 0.22),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -100,
            left: -80,
            child: IgnorePointer(
              child: Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.secondary.withValues(alpha: 0.14),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top Bar with Back Button & Wallet Shortcut
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                  child: Row(
                    children: [
                      InkWell(
                        onTap: () => _handleBack(context),
                        borderRadius: BorderRadius.circular(22),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceCard,
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(color: AppColors.borderSubtle),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.arrow_back_ios_new_rounded,
                                color: Colors.white,
                                size: 16,
                              ),
                              SizedBox(width: 6),
                              Text(
                                'Trở về',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const Spacer(),
                      InkWell(
                        onTap: () => _openWallet(context),
                        borderRadius: BorderRadius.circular(22),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.gold.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(
                              color: AppColors.gold.withValues(alpha: 0.35),
                            ),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('🪙', style: TextStyle(fontSize: 14)),
                              SizedBox(width: 6),
                              Text(
                                'Ví Xu',
                                style: TextStyle(
                                  color: AppColors.gold,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Scrollable Content
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            gradient: AppColors.primaryGradient,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'SHARECO STUDIO',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Sáng tạo nội dung',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.4,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Quay video, tải clip chất lượng cao hoặc phát Livestream bán hàng ngay lập tức.',
                          style: TextStyle(
                            color: Colors.white60,
                            fontSize: 14,
                            height: 1.45,
                          ),
                        ),
                        const SizedBox(height: 26),

                        _StudioOptionCard(
                          icon: Icons.videocam_rounded,
                          badge: 'QUAY MỚI',
                          label: 'Quay video trực tiếp',
                          subtitle:
                              'Bộ lọc màu hiện đại, chèn nhạc nền, hẹn giờ và gắn link sản phẩm.',
                          gradient: AppColors.primaryGradient,
                          accentColor: AppColors.primary,
                          onTap: () => _openCamera(context),
                        ),
                        const SizedBox(height: 14),

                        _StudioOptionCard(
                          icon: Icons.cloud_upload_rounded,
                          badge: 'THƯ VIỆN · TỐI ĐA 100 MB',
                          label: 'Tải video từ thiết bị',
                          subtitle:
                              'Hỗ trợ MP4/MOV (tối đa 100 MB), ghép nhạc nền, áp bộ lọc màu TikTok và gắn giỏ hàng Shop.',
                          gradient: AppColors.studioGradient,
                          accentColor: AppColors.secondary,
                          onTap: () => _openGallery(context),
                        ),
                        const SizedBox(height: 14),

                        _StudioOptionCard(
                          icon: Icons.sensors_rounded,
                          badge: 'LIVE SHOP',
                          label: 'Phát trực tiếp (Livestream)',
                          subtitle:
                              'Tương tác thời gian thực, ghim giỏ hàng chốt đơn & nhận quà tặng Xu.',
                          gradient: AppColors.liveGradient,
                          accentColor: const Color(0xFFB37FEB),
                          isHighlighted: true,
                          onTap: () => _openLive(context),
                        ),
                        const SizedBox(height: 24),

                        // Creator Tip Banner
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceCard,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.borderSubtle),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppColors.gold.withValues(alpha: 0.14),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.auto_awesome_rounded,
                                  color: AppColors.gold,
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Mẹo tăng tương tác & đơn hàng',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      'Khung giờ vàng 19:00 – 21:30 giúp video và phiên Livestream tiếp cận nhiều người xem nhất.',
                                      style: TextStyle(
                                        color: Colors.white60,
                                        fontSize: 12,
                                        height: 1.4,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StudioOptionCard extends StatefulWidget {
  final IconData icon;
  final String badge;
  final String label;
  final String subtitle;
  final LinearGradient gradient;
  final Color accentColor;
  final bool isHighlighted;
  final VoidCallback onTap;

  const _StudioOptionCard({
    required this.icon,
    required this.badge,
    required this.label,
    required this.subtitle,
    required this.gradient,
    required this.accentColor,
    this.isHighlighted = false,
    required this.onTap,
  });

  @override
  State<_StudioOptionCard> createState() => _StudioOptionCardState();
}

class _StudioOptionCardState extends State<_StudioOptionCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 110),
    );
    _scale = Tween<double>(
      begin: 1.0,
      end: 0.97,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) {
        _ctrl.reverse();
        widget.onTap();
      },
      onTapCancel: () => _ctrl.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.surfaceCard,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: widget.isHighlighted
                  ? widget.accentColor.withValues(alpha: 0.45)
                  : AppColors.borderSubtle,
              width: widget.isHighlighted ? 1.3 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: widget.accentColor.withValues(alpha: 0.12),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: widget.gradient,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: widget.accentColor.withValues(alpha: 0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(widget.icon, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: widget.accentColor.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            widget.badge,
                            style: TextStyle(
                              color: widget.accentColor,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      widget.label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.subtitle,
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 12.2,
                        height: 1.38,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: Colors.white70,
                  size: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
