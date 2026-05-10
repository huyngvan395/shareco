import 'dart:async';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';

class AgoraService {
  RtcEngine? _engine;
  bool _isInitialized = false;

  // Lấy từ Agora Console
  static const String appId = 'YOUR_AGORA_APP_ID';

  Future<void> initialize() async {
    if (_isInitialized) return;

    // Request permissions
    await [Permission.camera, Permission.microphone].request();

    // Create engine
    _engine = createAgoraRtcEngine();
    await _engine!.initialize(RtcEngineContext(
      appId: appId,
      channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
    ));

    // Enable video
    await _engine!.enableVideo();
    await _engine!.startPreview();

    _isInitialized = true;
  }

  Future<void> joinChannel({
    required String channelName,
    required String token,
    required int uid,
    required bool isBroadcaster,
  }) async {
    if (!_isInitialized) await initialize();

    await _engine!.setClientRole(
      role: isBroadcaster
          ? ClientRoleType.clientRoleBroadcaster
          : ClientRoleType.clientRoleAudience,
    );

    await _engine!.joinChannel(
      token: token,
      channelId: channelName,
      uid: uid,
      options: const ChannelMediaOptions(),
    );
  }

  Future<void> leaveChannel() async {
    await _engine?.leaveChannel();
  }

  Future<void> switchCamera() async {
    await _engine?.switchCamera();
  }

  Future<void> toggleMute(bool mute) async {
    await _engine?.muteLocalAudioStream(mute);
  }

  Future<void> toggleCamera(bool enable) async {
    await _engine?.muteLocalVideoStream(!enable);
  }

  void registerEventHandler(RtcEngineEventHandler handler) {
    _engine?.registerEventHandler(handler);
  }

  RtcEngine? get engine => _engine;

  Future<void> dispose() async {
    await _engine?.leaveChannel();
    await _engine?.release();
    _isInitialized = false;
  }
}