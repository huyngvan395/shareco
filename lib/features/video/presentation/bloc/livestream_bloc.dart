import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shareco/core/services/livestrem/agora_service.dart';
import 'package:shareco/features/video/presentation/bloc/livestream_event.dart';
import 'package:shareco/features/video/presentation/bloc/livestream_state.dart';

class LivestreamBloc extends Bloc<LivestreamEvent, LivestreamState> {
  final AgoraService _agoraService = AgoraService();

  LivestreamBloc() : super(const LivestreamState()) {
    on<LivestreamInitialize>(_onInitialize);
    on<LivestreamStart>(_onStart);
    on<LivestreamStop>(_onStop);
    on<LivestreamSwitchCamera>(_onSwitchCamera);
    on<LivestreamToggleMute>(_onToggleMute);
    on<LivestreamUserJoined>(_onUserJoined);
    on<LivestreamUserLeft>(_onUserLeft);
  }

  Future<void> _onInitialize(
      LivestreamInitialize event,
      Emitter<LivestreamState> emit,
      ) async {
    try {
      await _agoraService.initialize();

      _agoraService.registerEventHandler(
        RtcEngineEventHandler(
          onUserJoined: (connection, uid, elapsed) {
            add(LivestreamUserJoined(uid));
          },
          onUserOffline: (connection, uid, reason) {
            add(LivestreamUserLeft(uid));
          },
        ),
      );

      await _agoraService.joinChannel(
        channelName: event.channelName,
        token: event.token,
        uid: event.uid,
        isBroadcaster: true,
      );

      emit(state.copyWith(agoraService: _agoraService));
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  Future<void> _onStart(
      LivestreamStart event,
      Emitter<LivestreamState> emit,
      ) async {
    emit(state.copyWith(isLive: true, viewerCount: 1));
  }

  Future<void> _onStop(
      LivestreamStop event,
      Emitter<LivestreamState> emit,
      ) async {
    await _agoraService.leaveChannel();
    emit(state.copyWith(isLive: false));
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
    final users = List<int>.from(state.remoteUsers)..add(event.uid);
    emit(state.copyWith(
      remoteUsers: users,
      viewerCount: state.viewerCount + 1,
    ));
  }

  void _onUserLeft(
      LivestreamUserLeft event,
      Emitter<LivestreamState> emit,
      ) {
    final users = List<int>.from(state.remoteUsers)..remove(event.uid);
    emit(state.copyWith(
      remoteUsers: users,
      viewerCount: state.viewerCount - 1,
    ));
  }

  @override
  Future<void> close() {
    _agoraService.dispose();
    return super.close();
  }
}