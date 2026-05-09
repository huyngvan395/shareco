import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:shareco/features/video/domain/entities/filter_entity.dart';

abstract class CameraEvent extends Equatable {
  const CameraEvent();
  @override List<Object?> get props => [];
}

class CameraInitRequested extends CameraEvent { const CameraInitRequested(); }
class CameraFlipRequested extends CameraEvent { const CameraFlipRequested(); }
class CameraFlashToggled extends CameraEvent { const CameraFlashToggled(); }
class CameraRecordStarted extends CameraEvent { const CameraRecordStarted(); }
class CameraRecordStopped extends CameraEvent { const CameraRecordStopped(); }
class CameraRecordPaused extends CameraEvent { const CameraRecordPaused(); }
class CameraRecordResumed extends CameraEvent { const CameraRecordResumed(); }
class CameraBeautyToggled extends CameraEvent { const CameraBeautyToggled(); }
class CameraDisposed extends CameraEvent { const CameraDisposed(); }

class CameraFilterChanged extends CameraEvent {
  final VideoFilter filter;
  const CameraFilterChanged(this.filter);
  @override List<Object?> get props => [filter.id];
}

class CameraSpeedChanged extends CameraEvent {
  final RecordSpeed speed;
  const CameraSpeedChanged(this.speed);
  @override List<Object?> get props => [speed.value];
}

class CameraDurationLimitChanged extends CameraEvent {
  final DurationLimit limit;
  const CameraDurationLimitChanged(this.limit);
  @override List<Object?> get props => [limit.label];
}

class CameraBeautyEffectChanged extends CameraEvent {
  final String effectId;
  final double value;
  const CameraBeautyEffectChanged({required this.effectId, required this.value});
  @override List<Object?> get props => [effectId, value];
}

class CameraStickerAdded extends CameraEvent {
  final StickerItem sticker;
  const CameraStickerAdded(this.sticker);
  @override List<Object?> get props => [sticker.id];
}

class CameraStickerMoved extends CameraEvent {
  final String stickerId;
  final Offset position;
  const CameraStickerMoved({required this.stickerId, required this.position});
  @override List<Object?> get props => [stickerId];
}

class CameraStickerRemoved extends CameraEvent {
  final String stickerId;
  const CameraStickerRemoved(this.stickerId);
  @override List<Object?> get props => [stickerId];
}

class CameraTextAdded extends CameraEvent {
  final TextOverlay overlay;
  const CameraTextAdded(this.overlay);
  @override List<Object?> get props => [overlay.id];
}

class CameraTextRemoved extends CameraEvent {
  final String overlayId;
  const CameraTextRemoved(this.overlayId);
  @override List<Object?> get props => [overlayId];
}

class CameraMusicSelected extends CameraEvent {
  final MusicTrack? track;
  const CameraMusicSelected(this.track);
  @override List<Object?> get props => [track?.id];
}

class CameraTimerTick extends CameraEvent {
  final Duration elapsed;
  const CameraTimerTick(this.elapsed);
  @override List<Object?> get props => [elapsed.inMilliseconds];
}