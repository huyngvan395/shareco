import 'dart:async';

import 'package:camera/camera.dart' hide FlashMode;
import 'package:camera/camera.dart' as camera;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shareco/core/services/video/video_processing_services.dart';
import 'package:shareco/features/video/domain/entities/filter_entity.dart';
import 'package:shareco/features/video/presentation/bloc/camera_event.dart';
import 'package:shareco/features/video/presentation/bloc/camera_state.dart';

class CameraBloc extends Bloc<CameraEvent, CameraState> {
  List<CameraDescription> _cameras = [];
  Timer? _timer;
  int _camIndex = 0;

  CameraBloc() : super(const CameraState()) {
    on<CameraInitRequested>(_onInit);
    on<CameraFlipRequested>(_onFlip);
    on<CameraFlashToggled>(_onFlash);
    on<CameraRecordStarted>(_onStart);
    on<CameraRecordStopped>(_onStop);
    on<CameraRecordPaused>(_onPause);
    on<CameraRecordResumed>(_onResume);
    on<CameraFilterChanged>(_onFilter);
    on<CameraSpeedChanged>(_onSpeed);
    on<CameraDurationLimitChanged>(_onDurationLimit);
    on<CameraBeautyToggled>(_onBeautyToggle);
    on<CameraBeautyEffectChanged>(_onBeautyEffect);
    on<CameraStickerAdded>(_onStickerAdd);
    on<CameraStickerMoved>(_onStickerMove);
    on<CameraStickerRemoved>(_onStickerRemove);
    on<CameraTextAdded>(_onTextAdd);
    on<CameraTextRemoved>(_onTextRemove);
    on<CameraMusicSelected>(_onMusic);
    on<CameraTimerTick>(_onTick);
    on<CameraDisposed>(_onDispose);
  }

  Future<void> _onInit(CameraInitRequested _, Emitter<CameraState> emit) async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        emit(state.copyWith(errorMessage: 'No camera available'));
        return;
      }
      await _initCtrl(emit, _camIndex);
    } catch (e) {
      emit(state.copyWith(errorMessage: e.toString()));
    }
  }

  Future<void> _initCtrl(Emitter<CameraState> emit, int idx) async {
    await state.controller?.dispose();
    _camIndex = idx % _cameras.length;
    final ctrl = CameraController(_cameras[_camIndex], ResolutionPreset.high, enableAudio: true);
    await ctrl.initialize();
    await ctrl.setFlashMode(camera.FlashMode.off);
    emit(state.copyWith(
      controller: ctrl,
      isInitialized: true,
      facing: _cameras[_camIndex].lensDirection == CameraLensDirection.front
          ? CameraFacing.front : CameraFacing.back,
      beautyEffects: AppBeautyEffects.defaults(),
    ));
  }

  Future<void> _onFlip(CameraFlipRequested _, Emitter<CameraState> emit) async {
    if (_cameras.length < 2) return;
    if (state.isRecording) await _doStop();
    await _initCtrl(emit, _camIndex + 1);
  }

  Future<void> _onFlash(CameraFlashToggled _, Emitter<CameraState> emit) async {
    final ctrl = state.controller;
    if (ctrl == null || !ctrl.value.isInitialized) return;
    final next = switch (state.flashMode) {
      FlashMode.off  => FlashMode.on,
      FlashMode.on   => FlashMode.auto,
      FlashMode.auto => FlashMode.off,
    };
    await ctrl.setFlashMode(switch (next) {
      FlashMode.off  => camera.FlashMode.off,
      FlashMode.on   => camera.FlashMode.torch,
      FlashMode.auto => camera.FlashMode.auto,
    });
    emit(state.copyWith(flashMode: next));
  }

  Future<void> _onStart(CameraRecordStarted _, Emitter<CameraState> emit) async {
    final ctrl = state.controller;
    if (ctrl == null || !ctrl.value.isInitialized || state.isRecording) return;
    try {
      await ctrl.startVideoRecording();
      emit(state.copyWith(isRecording: true, isPaused: false, recordedDuration: Duration.zero));
      _startTimer();
    } catch (e) {
      emit(state.copyWith(errorMessage: e.toString()));
    }
  }

  Future<void> _onStop(CameraRecordStopped _, Emitter<CameraState> emit) async {
    if (!state.isRecording) return;
    _stopTimer();
    final file = await _doStop();
    String? thumbnailPath;

    if (file != null) {
      thumbnailPath = await VideoProcessingService.generateThumbnail(file.path);
    }

    emit(state.copyWith(
      isRecording: false,
      isPaused: false,
      recordedFilePath: file?.path,
      thumbnailPath: thumbnailPath, // 🔥 thêm dòng này
      clearError: true,
    ));
  }

  Future<XFile?> _doStop() async {
    final ctrl = state.controller;
    if (ctrl == null || !ctrl.value.isRecordingVideo) return null;
    try { return await ctrl.stopVideoRecording(); } catch (_) { return null; }
  }

  Future<void> _onPause(CameraRecordPaused _, Emitter<CameraState> emit) async {
    if (!state.isRecording || state.isPaused) return;
    _stopTimer();
    await state.controller?.pauseVideoRecording();
    emit(state.copyWith(isPaused: true));
  }

  Future<void> _onResume(CameraRecordResumed _, Emitter<CameraState> emit) async {
    if (!state.isRecording || !state.isPaused) return;
    await state.controller?.resumeVideoRecording();
    emit(state.copyWith(isPaused: false));
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 100), (_) =>
        add(CameraTimerTick(state.recordedDuration + const Duration(milliseconds: 100))));
  }

  void _stopTimer() { _timer?.cancel(); _timer = null; }

  void _onTick(CameraTimerTick event, Emitter<CameraState> emit) {
    if (event.elapsed >= state.durationLimit.max) {
      _stopTimer();
      add(const CameraRecordStopped());
      return;
    }
    emit(state.copyWith(recordedDuration: event.elapsed));
  }

  void _onFilter(CameraFilterChanged e, Emitter<CameraState> emit) =>
      emit(state.copyWith(activeFilter: e.filter));
  void _onSpeed(CameraSpeedChanged e, Emitter<CameraState> emit) =>
      emit(state.copyWith(activeSpeed: e.speed));
  void _onDurationLimit(CameraDurationLimitChanged e, Emitter<CameraState> emit) =>
      emit(state.copyWith(durationLimit: e.limit));
  void _onBeautyToggle(CameraBeautyToggled _, Emitter<CameraState> emit) =>
      emit(state.copyWith(beautyEnabled: !state.beautyEnabled));
  void _onBeautyEffect(CameraBeautyEffectChanged e, Emitter<CameraState> emit) {
    final updated = state.beautyEffects.map((ef) { if (ef.id == e.effectId) ef.value = e.value; return ef; }).toList();
    emit(state.copyWith(beautyEffects: updated));
  }
  void _onStickerAdd(CameraStickerAdded e, Emitter<CameraState> emit) =>
      emit(state.copyWith(stickers: [...state.stickers, e.sticker]));
  void _onStickerMove(CameraStickerMoved e, Emitter<CameraState> emit) =>
      emit(state.copyWith(stickers: state.stickers.map((s) =>
      s.id == e.stickerId ? s.copyWith(position: e.position) : s).toList()));
  void _onStickerRemove(CameraStickerRemoved e, Emitter<CameraState> emit) =>
      emit(state.copyWith(stickers: state.stickers.where((s) => s.id != e.stickerId).toList()));
  void _onTextAdd(CameraTextAdded e, Emitter<CameraState> emit) =>
      emit(state.copyWith(textOverlays: [...state.textOverlays, e.overlay]));
  void _onTextRemove(CameraTextRemoved e, Emitter<CameraState> emit) =>
      emit(state.copyWith(textOverlays: state.textOverlays.where((t) => t.id != e.overlayId).toList()));
  void _onMusic(CameraMusicSelected e, Emitter<CameraState> emit) =>
      emit(state.copyWith(selectedMusic: e.track, clearMusic: e.track == null));

  Future<void> _onDispose(CameraDisposed _, Emitter<CameraState> emit) async {
    _stopTimer();
    await state.controller?.dispose();
  }

  @override
  Future<void> close() async {
    _stopTimer();
    await state.controller?.dispose();
    return super.close();
  }
}