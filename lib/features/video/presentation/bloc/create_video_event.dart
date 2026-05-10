import 'package:equatable/equatable.dart';

abstract class CreateVideoEvent extends Equatable {
  const CreateVideoEvent();
  @override List<Object?> get props => [];
}

/// User picked a file from gallery or finished recording
class CreateVideoPickRequested extends CreateVideoEvent {
  const CreateVideoPickRequested();
}

class CreateVideoPickedFromPath extends CreateVideoEvent {
  final String localPath;
  final String? thumbnailPath;
  const CreateVideoPickedFromPath({required this.localPath, required this.thumbnailPath});
  @override List<Object?> get props => [localPath, thumbnailPath];
}

class CreateVideoRecordRequested extends CreateVideoEvent {
  const CreateVideoRecordRequested();
}

class CreateVideoResetRequested extends CreateVideoEvent {
  const CreateVideoResetRequested();
}

class CreateVideoVisibilityChanged extends CreateVideoEvent {
  final String visibility;
  const CreateVideoVisibilityChanged(this.visibility);
  @override List<Object?> get props => [visibility];
}

class CreateVideoSettingChanged extends CreateVideoEvent {
  final bool? allowComment;
  final bool? allowDuet;
  final bool? allowStitch;
  const CreateVideoSettingChanged({this.allowComment, this.allowDuet, this.allowStitch});
  @override List<Object?> get props => [allowComment, allowDuet, allowStitch];
}

class CreateVideoPostRequested extends CreateVideoEvent {
  final String caption;
  const CreateVideoPostRequested({required this.caption});
  @override List<Object?> get props => [caption];
}

class CreateVideoThumbnailChanged extends CreateVideoEvent {
  final String thumbnailPath;
  const CreateVideoThumbnailChanged({required this.thumbnailPath});
}

class CreateVideoUploadProgressChanged extends CreateVideoEvent {
  final double progress;

  const CreateVideoUploadProgressChanged(this.progress);

  @override
  List<Object> get props => [progress];
}