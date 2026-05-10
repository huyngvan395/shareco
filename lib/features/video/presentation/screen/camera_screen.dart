// features/video/presentation/screen/camera_screen.dart

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shareco/features/video/presentation/bloc/camera_event.dart';
import 'package:shareco/features/video/presentation/bloc/camera_state.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../di/injector.dart';
import '../bloc/camera_bloc.dart';
import '../bloc/create_video_bloc.dart';
import '../widgets/camera_controls.dart';
import 'video_edit_screen.dart';

class CameraScreen extends StatelessWidget {
  const CameraScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => CameraBloc()..add(const CameraInitRequested()),
      child: const _CameraView(),
    );
  }
}

class _CameraView extends StatefulWidget {
  const _CameraView();
  @override State<_CameraView> createState() => _CameraViewState();
}

class _CameraViewState extends State<_CameraView> with WidgetsBindingObserver {
  int _activeTab = 0; // 0=Camera, 1=Upload, 2=Templates

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    context.read<CameraBloc>().add(const CameraDisposed());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycle) {
    final ctrl = context.read<CameraBloc>().state.controller;
    if (ctrl == null || !ctrl.value.isInitialized) return;
    if (lifecycle == AppLifecycleState.inactive) {
      ctrl.dispose();
    } else if (lifecycle == AppLifecycleState.resumed) {
      context.read<CameraBloc>().add(const CameraInitRequested());
    }
  }

  Future<void> _pickFromGallery() async {
    final file = await ImagePicker().pickVideo(source: ImageSource.gallery);
    if (file == null || !mounted) return;
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => BlocProvider(
        create: (_) => CreateVideoBloc(createVideo: sl()),
        child: VideoEditScreen(localVideoPath: file.path),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<CameraBloc, CameraState>(
      listenWhen: (p, c) =>
      p.recordedFilePath != c.recordedFilePath && c.recordedFilePath != null,
      listener: (_, state) {
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => BlocProvider(
            create: (_) => CreateVideoBloc(createVideo: sl()),
            child: VideoEditScreen(
              localVideoPath: state.recordedFilePath!,
              thumbnailPath: state.thumbnailPath,
            ),
          ),
        ));
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: BlocBuilder<CameraBloc, CameraState>(
          builder: (ctx, state) => Stack(children: [
            // Camera preview
            _buildPreview(ctx, state),

            // Colour filter overlay
            if (state.activeFilter.colorFilter != null && state.isInitialized)
              Positioned.fill(
                child: IgnorePointer(
                  child: ColorFiltered(
                    colorFilter: state.activeFilter.colorFilter!,
                    child: Container(color: Colors.white.withOpacity(0.01)),
                  ),
                ),
              ),

            // Stickers + text
            const Positioned.fill(child: StickersOverlay()),
            const Positioned.fill(child: TextOverlaysLayer()),

            // Top bar
            Positioned(top: 0, left: 0, right: 0,
                child: CameraTopBar(onClose: () => Navigator.pop(context))),

            // Music bar
            Positioned(
              top: MediaQuery.of(context).padding.top + 64,
              left: 0, right: 0,
              child: const Center(child: MusicBar()),
            ),

            // Right tools
            Positioned(
              right: 12,
              top: MediaQuery.of(context).size.height * 0.22,
              child: const CameraRightTools(),
            ),

            // Tab bar
            Positioned(
              bottom: 186, left: 0, right: 0,
              child: _buildTabBar(),
            ),

            // Speed
            Positioned(
              bottom: 158, left: 0, right: 0,
              child: const SpeedSelector(),
            ),

            // Duration limit
            Positioned(
              bottom: 122, left: 0, right: 0,
              child: const DurationLimitSelector(),
            ),

            // Progress
            Positioned(
              bottom: 100, left: 16, right: 16,
              child: const RecordingProgressBar(),
            ),

            // Bottom controls
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: _buildBottomControls(ctx, state),
            ),
          ]),
        ),
      ),
    );
  }

  // ── Camera preview ──────────────────────────────────────────────────────────

  Widget _buildPreview(BuildContext ctx, CameraState state) {
    if (!state.isInitialized || state.controller == null) {
      return Container(
        color: Colors.black,
        child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (state.errorMessage != null) ...[
              const Icon(Icons.camera_alt_outlined, color: Colors.white24, size: 64),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(state.errorMessage!,
                    style: const TextStyle(color: Colors.white38),
                    textAlign: TextAlign.center),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => ctx.read<CameraBloc>().add(const CameraInitRequested()),
                child: const Text('Thử lại', style: TextStyle(color: AppColors.primary)),
              ),
            ] else ...[
              const CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2),
              const SizedBox(height: 16),
              const Text('Đang khởi động camera...', style: TextStyle(color: Colors.white38)),
            ],
          ]),
        ),
      );
    }

    return Positioned.fill(
      child: GestureDetector(
        onTapDown: (d) => _onFocus(ctx, state, d.localPosition),
        child: CameraPreview(state.controller!),
      ),
    );
  }

  Future<void> _onFocus(BuildContext ctx, CameraState state, Offset pos) async {
    final ctrl = state.controller;
    if (ctrl == null || !ctrl.value.isInitialized) return;
    final size = MediaQuery.of(context).size;
    try {
      await ctrl.setFocusPoint(Offset(pos.dx / size.width, pos.dy / size.height));
      await ctrl.setExposurePoint(Offset(pos.dx / size.width, pos.dy / size.height));
    } catch (_) {}
  }

  // ── Tab bar ─────────────────────────────────────────────────────────────────

  Widget _buildTabBar() {
    const tabs = ['Camera', 'Tải lên', 'Mẫu'];
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: tabs.asMap().entries.map((e) {
        final selected = e.key == _activeTab;
        return GestureDetector(
          onTap: () {
            if (e.key == 1) { _pickFromGallery(); return; }
            setState(() => _activeTab = e.key);
          },
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: selected ? Colors.white.withOpacity(0.18) : Colors.transparent,
              borderRadius: BorderRadius.circular(20),
              border: selected ? Border.all(color: Colors.white30) : null,
            ),
            child: Text(e.value, style: TextStyle(
              color: selected ? Colors.white : Colors.white54,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
              fontSize: 14,
            )),
          ),
        );
      }).toList(),
    );
  }

  // ── Bottom controls ─────────────────────────────────────────────────────────

  Widget _buildBottomControls(BuildContext ctx, CameraState state) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Gallery
            GestureDetector(
              onTap: _pickFromGallery,
              child: Container(
                width: 52, height: 52,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: AppColors.bgInput,
                  border: Border.all(color: Colors.white30, width: 1.5),
                ),
                child: const Icon(Icons.photo_library_outlined, color: Colors.white54, size: 24),
              ),
            ),

            // Record + label
            Column(children: [
              const RecordButton(),
              const SizedBox(height: 8),
              Text(
                state.isRecording
                    ? (state.isPaused ? 'Nhấn để tiếp tục' : 'Nhấn để tạm dừng')
                    : 'Nhấn để quay',
                style: const TextStyle(color: Colors.white54, fontSize: 11),
              ),
            ]),

            // Stop / flip
            Column(mainAxisSize: MainAxisSize.min, children: [
              if (state.isRecording)
                const StopRecordButton()
              else
                GestureDetector(
                  onTap: () => ctx.read<CameraBloc>().add(const CameraFlipRequested()),
                  child: Container(
                    width: 52, height: 52,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.15),
                    ),
                    child: const Icon(Icons.flip_camera_ios_outlined, color: Colors.white, size: 26),
                  ),
                ),
            ]),
          ],
        ),
      ),
    );
  }
}