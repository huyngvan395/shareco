import 'package:shareco/core/services/livestrem/agora_service.dart';

class LivestreamState {
  final bool isLive;
  final bool isMuted;
  final int viewerCount;
  final List<int> remoteUsers;
  final String? error;
  final AgoraService? agoraService;

  const LivestreamState({
    this.isLive = false,
    this.isMuted = false,
    this.viewerCount = 0,
    this.remoteUsers = const [],
    this.error,
    this.agoraService,
  });

  LivestreamState copyWith({
    bool? isLive,
    bool? isMuted,
    int? viewerCount,
    List<int>? remoteUsers,
    String? error,
    AgoraService? agoraService,
  }) {
    return LivestreamState(
      isLive: isLive ?? this.isLive,
      isMuted: isMuted ?? this.isMuted,
      viewerCount: viewerCount ?? this.viewerCount,
      remoteUsers: remoteUsers ?? this.remoteUsers,
      error: error,
      agoraService: agoraService ?? this.agoraService,
    );
  }
}