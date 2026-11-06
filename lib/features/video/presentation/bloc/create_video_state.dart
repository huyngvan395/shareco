import 'package:equatable/equatable.dart';
import '../../../ecommerce/product/domain/entities/product.dart';

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
  final List<Product> taggedProducts;

  const CreateVideoPickedFile({
    required this.localPath,
    required this.thumbnailPath,
    this.visibility = 'public',
    this.allowComment = true,
    this.allowDuet = true,
    this.allowStitch = true,
    this.taggedProducts = const [],
  });

  CreateVideoPickedFile copyWith({
    String? thumbnailPath,
    String? visibility,
    bool? allowComment,
    bool? allowDuet,
    bool? allowStitch,
    List<Product>? taggedProducts,
  }) => CreateVideoPickedFile(
    localPath: localPath,
    thumbnailPath: thumbnailPath ?? this.thumbnailPath,
    visibility: visibility ?? this.visibility,
    allowComment: allowComment ?? this.allowComment,
    allowDuet: allowDuet ?? this.allowDuet,
    allowStitch: allowStitch ?? this.allowStitch,
    taggedProducts: taggedProducts ?? this.taggedProducts,
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
  ];
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