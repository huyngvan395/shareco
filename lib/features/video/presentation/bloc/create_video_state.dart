import 'package:equatable/equatable.dart';
import '../../../ecommerce/product/domain/entities/product.dart';
import '../../domain/entities/filter_entity.dart';

abstract class CreateVideoState extends Equatable {
  const CreateVideoState();
  @override
  List<Object?> get props => [];
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
  final List<Product> taggedProducts;
  final VideoEffectMeta effectMeta;
  final int fileSizeBytes;

  const CreateVideoPickedFile({
    required this.localPath,
    required this.thumbnailPath,
    this.visibility = 'public',
    this.allowComment = true,
    this.allowDuet = true,
    this.allowStitch = true,
    this.taggedProducts = const [],
    this.effectMeta = const VideoEffectMeta(),
    this.fileSizeBytes = 0,
  });

  double get fileSizeMB => fileSizeBytes / (1024 * 1024);

  CreateVideoPickedFile copyWith({
    String? thumbnailPath,
    String? visibility,
    bool? allowComment,
    bool? allowDuet,
    bool? allowStitch,
    List<Product>? taggedProducts,
    VideoEffectMeta? effectMeta,
    int? fileSizeBytes,
  }) => CreateVideoPickedFile(
    localPath: localPath,
    thumbnailPath: thumbnailPath ?? this.thumbnailPath,
    visibility: visibility ?? this.visibility,
    allowComment: allowComment ?? this.allowComment,
    allowDuet: allowDuet ?? this.allowDuet,
    allowStitch: allowStitch ?? this.allowStitch,
    taggedProducts: taggedProducts ?? this.taggedProducts,
    effectMeta: effectMeta ?? this.effectMeta,
    fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
  );

  @override
  List<Object?> get props => [
    localPath,
    thumbnailPath,
    visibility,
    allowComment,
    allowDuet,
    allowStitch,
    taggedProducts,
    effectMeta.filterId,
    effectMeta.musicId,
    effectMeta.originalVolume,
    effectMeta.musicVolume,
    effectMeta.playbackSpeed,
    effectMeta.textOverlays.length,
    effectMeta.stickers.length,
    fileSizeBytes,
  ];
}

class CreateVideoUploading extends CreateVideoState {
  final double progress;
  final int totalBytes;
  final VideoEffectMeta effectMeta;

  const CreateVideoUploading({
    this.progress = 0,
    this.totalBytes = 0,
    this.effectMeta = const VideoEffectMeta(),
  });

  @override
  List<Object?> get props => [progress, totalBytes, effectMeta.filterId, effectMeta.musicId];
}

class CreateVideoSuccess extends CreateVideoState {
  const CreateVideoSuccess();
}

class CreateVideoError extends CreateVideoState {
  final String message;
  const CreateVideoError(this.message);
  @override
  List<Object?> get props => [message];
}
