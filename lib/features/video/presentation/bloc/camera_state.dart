import 'package:camera/camera.dart' hide FlashMode;
import 'package:equatable/equatable.dart';
import 'package:shareco/features/video/domain/entities/filter_entity.dart';

class CameraState extends Equatable {
  final CameraController? controller;
  final bool isInitialized;
  final bool isRecording;
  final bool isPaused;
  final CameraFacing facing;
  final FlashMode flashMode;
  final VideoFilter activeFilter;
  final RecordSpeed activeSpeed;
  final DurationLimit durationLimit;
  final Duration recordedDuration;
  final bool beautyEnabled;
  final List<BeautyEffect> beautyEffects;
  final List<StickerItem> stickers;
  final List<TextOverlay> textOverlays;
  final MusicTrack? selectedMusic;
  final String? recordedFilePath;
  final String? thumbnailPath;
  final String? errorMessage;

  const CameraState({
    this.controller,
    this.isInitialized = false,
    this.isRecording = false,
    this.isPaused = false,
    this.facing = CameraFacing.back,
    this.flashMode = FlashMode.off,
    this.activeFilter = AppFilters.none,
    this.recordedDuration = Duration.zero,
    this.beautyEnabled = false,
    this.stickers = const [],
    this.textOverlays = const [],
    this.selectedMusic,
    this.recordedFilePath,
    this.thumbnailPath,
    this.errorMessage,
    RecordSpeed? activeSpeed,
    DurationLimit? durationLimit,
    List<BeautyEffect>? beautyEffects,
  })  : activeSpeed = activeSpeed ?? const RecordSpeed(label: '1x', value: 1.0),
        durationLimit = durationLimit ?? const DurationLimit(label: '60s', max: Duration(seconds: 60)),
        beautyEffects = beautyEffects ?? const [];

  bool get isAtDurationLimit => recordedDuration >= durationLimit.max;
  double get recordingProgress => durationLimit.max.inMilliseconds > 0
      ? (recordedDuration.inMilliseconds / durationLimit.max.inMilliseconds).clamp(0.0, 1.0)
      : 0.0;

  CameraState copyWith({
    CameraController? controller,
    bool? isInitialized,
    bool? isRecording,
    bool? isPaused,
    CameraFacing? facing,
    FlashMode? flashMode,
    VideoFilter? activeFilter,
    RecordSpeed? activeSpeed,
    DurationLimit? durationLimit,
    Duration? recordedDuration,
    bool? beautyEnabled,
    List<BeautyEffect>? beautyEffects,
    List<StickerItem>? stickers,
    List<TextOverlay>? textOverlays,
    MusicTrack? selectedMusic,
    bool clearMusic = false,
    String? recordedFilePath,
    String? thumbnailPath,
    String? errorMessage,
    bool clearError = false,
  }) =>
      CameraState(
        controller: controller ?? this.controller,
        isInitialized: isInitialized ?? this.isInitialized,
        isRecording: isRecording ?? this.isRecording,
        isPaused: isPaused ?? this.isPaused,
        facing: facing ?? this.facing,
        flashMode: flashMode ?? this.flashMode,
        activeFilter: activeFilter ?? this.activeFilter,
        activeSpeed: activeSpeed ?? this.activeSpeed,
        durationLimit: durationLimit ?? this.durationLimit,
        recordedDuration: recordedDuration ?? this.recordedDuration,
        beautyEnabled: beautyEnabled ?? this.beautyEnabled,
        beautyEffects: beautyEffects ?? this.beautyEffects,
        stickers: stickers ?? this.stickers,
        textOverlays: textOverlays ?? this.textOverlays,
        selectedMusic: clearMusic ? null : (selectedMusic ?? this.selectedMusic),
        recordedFilePath: recordedFilePath ?? this.recordedFilePath,
        thumbnailPath: thumbnailPath ?? this.thumbnailPath,
        errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      );

  @override
  List<Object?> get props => [
    isInitialized, isRecording, isPaused, facing.name, flashMode.name,
    activeFilter.id, activeSpeed.value, durationLimit.label,
    recordedDuration.inMilliseconds, beautyEnabled,
    stickers.length, textOverlays.length, selectedMusic?.id,
    recordedFilePath, errorMessage,
  ];
}