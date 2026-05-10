import 'package:equatable/equatable.dart';

abstract class CreateVideoState extends Equatable {
  const CreateVideoState();
  @override List<Object?> get props => [];
}

class CreateVideoInitial extends CreateVideoState {
  const CreateVideoInitial();
}

class CreateVideoLoading extends CreateVideoState {
  const CreateVideoLoading();
}

class CreateVideoPickedFile extends CreateVideoState {
  final String localPath;
  final String thumbnailPath;
  final String visibility;
  final bool allowComment;
  final bool allowDuet;
  final bool allowStitch;

  const CreateVideoPickedFile({
    required this.localPath,
    required this.thumbnailPath,
    this.visibility = 'public',
    this.allowComment = true,
    this.allowDuet = true,
    this.allowStitch = true,
  });

  CreateVideoPickedFile copyWith({
    String? thumbnailPath,
    String? visibility,
    bool? allowComment,
    bool? allowDuet,
    bool? allowStitch,
  }) => CreateVideoPickedFile(
    localPath: localPath,
    thumbnailPath: thumbnailPath ?? this.thumbnailPath,
    visibility: visibility ?? this.visibility,
    allowComment: allowComment ?? this.allowComment,
    allowDuet: allowDuet ?? this.allowDuet,
    allowStitch: allowStitch ?? this.allowStitch,
  );

  @override
  List<Object?> get props =>
      [localPath, thumbnailPath, visibility, allowComment, allowDuet, allowStitch];
}

class CreateVideoUploading extends CreateVideoState {
  final double progress;
  const CreateVideoUploading({this.progress = 0});
  @override List<Object?> get props => [progress];
}

class CreateVideoSuccess extends CreateVideoState {
  const CreateVideoSuccess();
}

class CreateVideoError extends CreateVideoState {
  final String message;
  const CreateVideoError(this.message);
  @override List<Object?> get props => [message];
}