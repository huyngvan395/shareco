import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shareco/core/services/livestrem/agora_service.dart';
import 'package:shareco/features/video/presentation/bloc/livestream_event.dart';
import 'package:shareco/features/video/presentation/bloc/livestream_state.dart';

class LivestreamBloc extends Bloc<LivestreamEvent, LivestreamState> {
  final AgoraService _agoraService = AgoraService();
  String _channelName = '';
  int _localUid = 0;
  bool _isBroadcaster = true;

  LivestreamBloc() : super(const LivestreamState()) {
    on<LivestreamInitialize>(_onInitialize);
    on<LivestreamStart>(_onStart);
    on<LivestreamJoinChannel>(_onJoinChannel);
    on<LivestreamStop>(_onStop);
    on<LivestreamSwitchCamera>(_onSwitchCamera);
    on<LivestreamToggleMute>(_onToggleMute);
    on<LivestreamChannelJoined>(_onChannelJoined);
    on<LivestreamUserJoined>(_onUserJoined);
    on<LivestreamUserLeft>(_onUserLeft);
    on<LivestreamErrorOccurred>(_onErrorOccurred);
  }

  Future<void> _onInitialize(
    LivestreamInitialize event,
    Emitter<LivestreamState> emit,
  ) async {
    _channelName = event.channelName;
    _localUid = event.uid;
    _isBroadcaster = event.isBroadcaster;

    try {
      await _agoraService.initialize(isBroadcaster: event.isBroadcaster);

      if (_agoraService.isEngineReady) {
        _attachAgoraListeners();

        // Đối với Người xem (Viewer), tham gia kênh ngay khi vào phòng Live!
        // Đối với Host, ở màn hình chuẩn bị chỉ mở Preview Camera, khi bấm "Bắt đầu Live" mới joinChannel để phát sóng.
        if (!event.isBroadcaster && event.channelName.trim().isNotEmpty) {
          await _agoraService.joinChannel(
            channelName: event.channelName.trim(),
            token: event.token,
            uid: event.uid,
            isBroadcaster: false,
          );
        }
      }

      emit(
        state.copyWith(
          agoraService: _agoraService,
          isLive: !event.isBroadcaster ? true : state.isLive,
          clearError: true,
        ),
      );
    } catch (e) {
      debugPrint('[LivestreamBloc] _onInitialize error: $e');
      emit(
        state.copyWith(
          agoraService: _agoraService,
          error: e.toString(),
        ),
      );
    }
  }

  void _attachAgoraListeners() {
    _agoraService.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
          debugPrint(
            '[Agora] Joined channel=${connection.channelId}, localUid=${connection.localUid}',
          );
          add(
            LivestreamChannelJoined(
              channelName: connection.channelId ?? _channelName,
              localUid: connection.localUid ?? _localUid,
            ),
          );
        },
        onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
          debugPrint('[Agora] Remote user joined: $remoteUid');
          add(LivestreamUserJoined(remoteUid));
        },
        onFirstRemoteVideoFrame: (
          RtcConnection connection,
          int remoteUid,
          int width,
          int height,
          int elapsed,
        ) {
          debugPrint(
            '[Agora] First remote video frame from $remoteUid (${width}x$height)',
          );
          add(LivestreamUserJoined(remoteUid));
        },
        onRemoteVideoStateChanged: (
          RtcConnection connection,
          int remoteUid,
          RemoteVideoState videoState,
          RemoteVideoStateReason reason,
          int elapsed,
        ) {
          if (videoState == RemoteVideoState.remoteVideoStateStarting ||
              videoState == RemoteVideoState.remoteVideoStateDecoding) {
            add(LivestreamUserJoined(remoteUid));
          }
        },
        onUserOffline: (
          RtcConnection connection,
          int remoteUid,
          UserOfflineReasonType reason,
        ) {
          debugPrint('[Agora] Remote user offline: $remoteUid ($reason)');
          add(LivestreamUserLeft(remoteUid));
        },
        onTokenPrivilegeWillExpire: (RtcConnection connection, String token) {
          _agoraService.renewChannelToken(
            channelName: connection.channelId ?? _channelName,
            uid: _localUid,
            isBroadcaster: _isBroadcaster,
          );
        },
        onConnectionStateChanged: (
          RtcConnection connection,
          ConnectionStateType connState,
          ConnectionChangedReasonType reason,
        ) {
          debugPrint('[Agora] Connection state=$connState, reason=$reason');
          if (reason ==
                  ConnectionChangedReasonType.connectionChangedInvalidToken ||
              reason ==
                  ConnectionChangedReasonType.connectionChangedTokenExpired) {
            add(
              const LivestreamErrorOccurred(
                'Dự án Agora đang bật Primary Certificate! Hãy dán AGORA_APP_CERTIFICATE vào file .env (hoặc tắt Primary Certificate trên Agora Console) để truyền hình ảnh.',
              ),
            );
          } else if (reason ==
              ConnectionChangedReasonType.connectionChangedInvalidAppId) {
            add(
              const LivestreamErrorOccurred(
                'AGORA_APP_ID không hợp lệ. Vui lòng kiểm tra lại file .env.',
              ),
            );
          }
        },
        onError: (ErrorCodeType err, String msg) {
          debugPrint('[Agora] onError: $err ($msg)');
          if (err == ErrorCodeType.errInvalidToken ||
              err == ErrorCodeType.errTokenExpired) {
            add(
              const LivestreamErrorOccurred(
                'Dự án Agora đang bật Primary Certificate! Hãy dán AGORA_APP_CERTIFICATE vào file .env (hoặc tắt Primary Certificate trên Agora Console) để truyền hình ảnh.',
              ),
            );
          }
        },
      ),
    );
  }

  Future<void> _onStart(
    LivestreamStart event,
    Emitter<LivestreamState> emit,
  ) async {
    final targetChannel = (event.channelName?.trim().isNotEmpty == true)
        ? event.channelName!.trim()
        : _channelName;
    _channelName = targetChannel;

    try {
      if (_agoraService.hasValidAppId) {
        if (!_agoraService.isEngineReady) {
          await _agoraService.initialize(isBroadcaster: true);
          _attachAgoraListeners();
        }
        await _agoraService.joinChannel(
          channelName: targetChannel,
          uid: _localUid,
          isBroadcaster: true,
        );
      }
      emit(
        state.copyWith(
          isLive: true,
          joinedChannelName: targetChannel,
          agoraService: _agoraService,
          clearError: true,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          isLive: true,
          error: e.toString(),
          agoraService: _agoraService,
        ),
      );
    }
  }

  Future<void> _onJoinChannel(
    LivestreamJoinChannel event,
    Emitter<LivestreamState> emit,
  ) async {
    if (event.channelName.trim().isEmpty) return;
    if (state.joinedChannelName == event.channelName.trim() &&
        state.isChannelJoined) {
      return;
    }

    _channelName = event.channelName.trim();
    _isBroadcaster = event.isBroadcaster;

    try {
      if (_agoraService.hasValidAppId) {
        if (!_agoraService.isEngineReady) {
          await _agoraService.initialize(isBroadcaster: event.isBroadcaster);
          _attachAgoraListeners();
        }
        await _agoraService.joinChannel(
          channelName: _channelName,
          uid: _localUid,
          isBroadcaster: event.isBroadcaster,
        );
      }
      emit(
        state.copyWith(
          joinedChannelName: _channelName,
          agoraService: _agoraService,
        ),
      );
    } catch (e) {
      debugPrint('[LivestreamBloc] _onJoinChannel error: $e');
    }
  }

  void _onChannelJoined(
    LivestreamChannelJoined event,
    Emitter<LivestreamState> emit,
  ) {
    emit(
      state.copyWith(
        isChannelJoined: true,
        joinedChannelName: event.channelName,
        clearError: true,
      ),
    );
  }

  Future<void> _onStop(
    LivestreamStop event,
    Emitter<LivestreamState> emit,
  ) async {
    await _agoraService.leaveChannel();
    emit(state.copyWith(isLive: false, isChannelJoined: false));
  }

  Future<void> _onSwitchCamera(
    LivestreamSwitchCamera event,
    Emitter<LivestreamState> emit,
  ) async {
    await _agoraService.switchCamera();
  }

  Future<void> _onToggleMute(
    LivestreamToggleMute event,
    Emitter<LivestreamState> emit,
  ) async {
    final newMuted = !state.isMuted;
    await _agoraService.toggleMute(newMuted);
    emit(state.copyWith(isMuted: newMuted));
  }

  void _onUserJoined(
    LivestreamUserJoined event,
    Emitter<LivestreamState> emit,
  ) {
    if (state.remoteUsers.contains(event.uid)) return;
    final users = List<int>.from(state.remoteUsers)..add(event.uid);
    emit(
      state.copyWith(
        remoteUsers: users,
        clearError: true,
      ),
    );
  }

  void _onUserLeft(
    LivestreamUserLeft event,
    Emitter<LivestreamState> emit,
  ) {
    if (!state.remoteUsers.contains(event.uid)) return;
    final users = List<int>.from(state.remoteUsers)..remove(event.uid);
    emit(
      state.copyWith(
        remoteUsers: users,
      ),
    );
  }

  void _onErrorOccurred(
    LivestreamErrorOccurred event,
    Emitter<LivestreamState> emit,
  ) {
    emit(state.copyWith(error: event.message));
  }

  @override
  Future<void> close() async {
    await _agoraService.dispose();
    return super.close();
  }
}
