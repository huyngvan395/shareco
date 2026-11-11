import 'package:shareco/core/services/livestrem/agora_service.dart';

class LivestreamState {
  final bool isLive;
  final bool isChannelJoined;
  final bool isMuted;
  final int viewerCount;
  final List<int> remoteUsers;
  final String? joinedChannelName;
  final String? error;
  final AgoraService? agoraService;

  const LivestreamState({
    this.isLive = false,
    this.isChannelJoined = false,
    this.isMuted = false,
    this.viewerCount = 0,
    this.remoteUsers = const [],
    this.joinedChannelName,
    this.error,
    this.agoraService,
  });

  LivestreamState copyWith({
    bool? isLive,
    bool? isChannelJoined,
    bool? isMuted,
    int? viewerCount,
    List<int>? remoteUsers,
    String? joinedChannelName,
    String? error,
    bool clearError = false,
    AgoraService? agoraService,
  }) {
    return LivestreamState(
      isLive: isLive ?? this.isLive,
      isChannelJoined: isChannelJoined ?? this.isChannelJoined,
      isMuted: isMuted ?? this.isMuted,
      viewerCount: viewerCount ?? this.viewerCount,
      remoteUsers: remoteUsers ?? this.remoteUsers,
      joinedChannelName: joinedChannelName ?? this.joinedChannelName,
      error: clearError ? null : (error ?? this.error),
      agoraService: agoraService ?? this.agoraService,
    );
  }
}
