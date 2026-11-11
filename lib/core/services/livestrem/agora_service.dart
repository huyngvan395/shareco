import 'dart:async';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:agora_token_service/agora_token_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:permission_handler/permission_handler.dart';

class AgoraService {
  RtcEngine? _engine;
  bool _isInitialized = false;
  bool _isJoined = false;
  String? _joinedChannelId;
  RtcEngineEventHandler? _eventHandler;

  // Lấy từ .env (AGORA_APP_ID & AGORA_APP_CERTIFICATE)
  static const String appId = 'YOUR_AGORA_APP_ID';

  String get resolvedAppId {
    final envId = dotenv.env['AGORA_APP_ID']?.trim() ?? '';
    if (envId.isNotEmpty && envId != 'YOUR_AGORA_APP_ID') {
      return envId;
    }
    return appId;
  }

  String get resolvedAppCertificate {
    final cert = dotenv.env['AGORA_APP_CERTIFICATE']?.trim() ?? '';
    if (cert.isNotEmpty && cert != 'YOUR_AGORA_APP_CERTIFICATE') {
      return cert;
    }
    return '';
  }

  String get resolvedTempToken {
    return dotenv.env['AGORA_TEMP_TOKEN']?.trim() ?? '';
  }

  bool get hasValidAppId =>
      resolvedAppId.isNotEmpty && resolvedAppId != 'YOUR_AGORA_APP_ID';

  bool get hasAppCertificate => resolvedAppCertificate.isNotEmpty;

  bool get isEngineReady => _isInitialized && _engine != null;

  bool get isJoined => _isJoined;

  /// Tạo RTC Token tự động nếu có AGORA_APP_CERTIFICATE trong .env
  String buildToken({
    required String channelName,
    required int uid,
    required bool isBroadcaster,
    String fallbackToken = '',
  }) {
    if (fallbackToken.trim().isNotEmpty) {
      return fallbackToken.trim();
    }
    if (hasValidAppId && hasAppCertificate) {
      final expireTs =
          (DateTime.now().millisecondsSinceEpoch ~/ 1000) + 24 * 3600;
      return RtcTokenBuilder.build(
        appId: resolvedAppId,
        appCertificate: resolvedAppCertificate,
        channelName: channelName,
        uid: uid == 0 ? '' : uid.toString(),
        role: isBroadcaster ? RtcRole.publisher : RtcRole.subscriber,
        expireTimestamp: expireTs,
      );
    }
    if (resolvedTempToken.isNotEmpty) {
      return resolvedTempToken;
    }
    return '';
  }

  Future<void> initialize({bool isBroadcaster = true}) async {
    if (_isInitialized && _engine != null) return;

    // Chỉ xin quyền Camera & Mic đối với người phát Live (Host)
    if (isBroadcaster) {
      await [Permission.camera, Permission.microphone].request();
    }

    if (!hasValidAppId) {
      return;
    }

    try {
      final engine = createAgoraRtcEngine();
      await engine.initialize(
        RtcEngineContext(
          appId: resolvedAppId,
          channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
        ),
      );

      await engine.enableAudio();
      await engine.enableVideo();

      try {
        await engine.setEnableSpeakerphone(true);
      } catch (_) {}

      if (isBroadcaster) {
        await engine.setVideoEncoderConfiguration(
          const VideoEncoderConfiguration(
            dimensions: VideoDimensions(width: 720, height: 1280),
            frameRate: 24,
            orientationMode: OrientationMode.orientationModeFixedPortrait,
          ),
        );
        await engine.setClientRole(
          role: ClientRoleType.clientRoleBroadcaster,
        );
        await engine.startPreview();
      } else {
        await engine.setClientRole(
          role: ClientRoleType.clientRoleAudience,
        );
      }

      _engine = engine;
      _isInitialized = true;
    } catch (e) {
      debugPrint('[AgoraService] initialize error: $e');
      _engine = null;
      _isInitialized = false;
    }
  }

  void registerEventHandler(RtcEngineEventHandler handler) {
    if (_engine == null) return;
    if (_eventHandler != null) {
      try {
        _engine?.unregisterEventHandler(_eventHandler!);
      } catch (_) {}
    }
    _eventHandler = handler;
    _engine?.registerEventHandler(handler);
  }

  Future<void> joinChannel({
    required String channelName,
    String token = '',
    required int uid,
    required bool isBroadcaster,
  }) async {
    if (!hasValidAppId) return;
    if (!_isInitialized) {
      await initialize(isBroadcaster: isBroadcaster);
    }
    if (_engine == null) return;

    // Nếu đang ở kênh khác thì rời kênh cũ trước khi join kênh mới
    if (_isJoined && _joinedChannelId != null && _joinedChannelId != channelName) {
      try {
        await _engine!.leaveChannel();
      } catch (_) {}
      _isJoined = false;
      _joinedChannelId = null;
    }

    final effectiveToken = buildToken(
      channelName: channelName,
      uid: uid,
      isBroadcaster: isBroadcaster,
      fallbackToken: token,
    );

    final mediaOptions = isBroadcaster
        ? const ChannelMediaOptions(
            clientRoleType: ClientRoleType.clientRoleBroadcaster,
            channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
            publishCameraTrack: true,
            publishMicrophoneTrack: true,
            autoSubscribeAudio: true,
            autoSubscribeVideo: true,
          )
        : const ChannelMediaOptions(
            clientRoleType: ClientRoleType.clientRoleAudience,
            channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
            publishCameraTrack: false,
            publishMicrophoneTrack: false,
            autoSubscribeAudio: true,
            autoSubscribeVideo: true,
            audienceLatencyLevel:
                AudienceLatencyLevelType.audienceLatencyLevelLowLatency,
          );

    if (_isJoined && _joinedChannelId == channelName) {
      await _engine!.updateChannelMediaOptions(mediaOptions);
      return;
    }

    await _engine!.setClientRole(
      role: isBroadcaster
          ? ClientRoleType.clientRoleBroadcaster
          : ClientRoleType.clientRoleAudience,
    );

    if (isBroadcaster) {
      try {
        await _engine!.startPreview();
      } catch (_) {}
    }

    await _engine!.joinChannel(
      token: effectiveToken,
      channelId: channelName,
      uid: uid,
      options: mediaOptions,
    );

    _isJoined = true;
    _joinedChannelId = channelName;
  }

  Future<void> renewChannelToken({
    required String channelName,
    required int uid,
    required bool isBroadcaster,
  }) async {
    if (_engine == null || !hasAppCertificate) return;
    final newToken = buildToken(
      channelName: channelName,
      uid: uid,
      isBroadcaster: isBroadcaster,
    );
    if (newToken.isNotEmpty) {
      try {
        await _engine!.renewToken(newToken);
      } catch (_) {}
    }
  }

  Future<void> leaveChannel() async {
    try {
      await _engine?.leaveChannel();
    } catch (_) {}
    _isJoined = false;
    _joinedChannelId = null;
  }

  Future<void> switchCamera() async {
    try {
      await _engine?.switchCamera();
    } catch (_) {}
  }

  Future<void> toggleMute(bool mute) async {
    try {
      await _engine?.muteLocalAudioStream(mute);
    } catch (_) {}
  }

  Future<void> toggleCamera(bool enable) async {
    try {
      await _engine?.muteLocalVideoStream(!enable);
    } catch (_) {}
  }

  RtcEngine? get engine => _engine;

  Future<void> dispose() async {
    try {
      if (_eventHandler != null) {
        _engine?.unregisterEventHandler(_eventHandler!);
      }
      await _engine?.stopPreview();
      await _engine?.leaveChannel();
      await _engine?.release();
    } catch (_) {}
    _eventHandler = null;
    _engine = null;
    _isInitialized = false;
    _isJoined = false;
    _joinedChannelId = null;
  }
}
