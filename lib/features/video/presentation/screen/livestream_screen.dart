import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:shareco/features/video/presentation/bloc/livestream_state.dart';
import '../../../../core/constants/app_colors.dart';
import '../bloc/livestream_bloc.dart';
import '../bloc/livestream_event.dart';

class LiveStreamScreen extends StatelessWidget {
  const LiveStreamScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => LivestreamBloc()..add(LivestreamInitialize(
        channelName: 'test_channel_${DateTime.now().millisecondsSinceEpoch}',
        token: '', // Get from your server
        uid: 0, // 0 = auto assign
      )),
      child: const _LiveView(),
    );
  }
}

class _LiveView extends StatelessWidget {
  const _LiveView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: BlocBuilder<LivestreamBloc, LivestreamState>(
        builder: (context, state) {
          return Stack(
            children: [
              // Agora Video View
              if (state.agoraService?.engine != null)
                Positioned.fill(
                  child: AgoraVideoView(
                    controller: VideoViewController(
                      rtcEngine: state.agoraService!.engine!,
                      canvas: const VideoCanvas(uid: 0),
                    ),
                  ),
                ),

              // Gradient overlay
              _buildGradient(),

              // Top bar
              _buildTopBar(context, state),

              // Bottom controls
              _buildBottomBar(context, state),

              // Start button overlay
              if (!state.isLive) _buildStartOverlay(context),
            ],
          );
        },
      ),
    );
  }

  Widget _buildGradient() {
    return Positioned.fill(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withOpacity(0.5),
              Colors.transparent,
              Colors.transparent,
              Colors.black.withOpacity(0.7),
            ],
            stops: const [0, 0.2, 0.6, 1],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context, LivestreamState state) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Close button
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    color: Colors.black38,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, color: Colors.white),
                ),
              ),
              const SizedBox(width: 12),

              // LIVE indicator
              if (state.isLive) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'LIVE',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Viewer count
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black38,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.visibility, color: Colors.white, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        '${state.viewerCount}',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ],

              const Spacer(),

              // Flip camera
              GestureDetector(
                onTap: () => context.read<LivestreamBloc>().add(LivestreamSwitchCamera()),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    color: Colors.black38,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.flip_camera_ios, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context, LivestreamState state) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Mute button
              GestureDetector(
                onTap: () => context.read<LivestreamBloc>().add(LivestreamToggleMute()),
                child: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: state.isMuted ? Colors.red : Colors.black38,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    state.isMuted ? Icons.mic_off : Icons.mic,
                    color: Colors.white,
                  ),
                ),
              ),

              const Spacer(),

              // End button (if live)
              if (state.isLive)
                GestureDetector(
                  onTap: () {
                    context.read<LivestreamBloc>().add(LivestreamStop());
                    Navigator.pop(context);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: const Text(
                      'End Stream',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStartOverlay(BuildContext context) {
    return Positioned.fill(
      child: Container(
        color: Colors.black54,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.live_tv,
                size: 80,
                color: Colors.white,
              ),
              const SizedBox(height: 24),
              const Text(
                'Ready to go LIVE?',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () {
                  context.read<LivestreamBloc>().add(LivestreamStart());
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
                ),
                child: const Text(
                  'Start Livestream',
                  style: TextStyle(fontSize: 16, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}