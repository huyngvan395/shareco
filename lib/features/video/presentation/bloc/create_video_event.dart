import 'package:equatable/equatable.dart';
import '../../../ecommerce/product/domain/entities/product.dart';
import '../../domain/entities/filter_entity.dart';

abstract class CreateVideoEvent extends Equatable {
  const CreateVideoEvent();
  @override
  List<Object?> get props => [];
}

class CreateVideoPickedFromPath extends CreateVideoEvent {
  final String localPath;
  final String? thumbnailPath;
  final VideoEffectMeta? initialEffects;

  const CreateVideoPickedFromPath({
    required this.localPath,
    required this.thumbnailPath,
    this.initialEffects,
  });

  @override
  List<Object?> get props => [localPath, thumbnailPath, initialEffects];
}

class CreateVideoVisibilityChanged extends CreateVideoEvent {
  final String visibility;
  const CreateVideoVisibilityChanged(this.visibility);
  @override
  List<Object?> get props => [visibility];
}

class CreateVideoSettingChanged extends CreateVideoEvent {
  final bool? allowComment;
  final bool? allowDuet;
  final bool? allowStitch;
  const CreateVideoSettingChanged({
    this.allowComment,
    this.allowDuet,
    this.allowStitch,
  });
  @override
  List<Object?> get props => [allowComment, allowDuet, allowStitch];
}

class CreateVideoEffectUpdated extends CreateVideoEvent {
  final VideoEffectMeta effectMeta;
  const CreateVideoEffectUpdated(this.effectMeta);

  @override
  List<Object?> get props => [
    effectMeta.filterId,
    effectMeta.musicId,
    effectMeta.originalVolume,
    effectMeta.musicVolume,
    effectMeta.playbackSpeed,
    effectMeta.textOverlays.length,
    effectMeta.stickers.length,
  ];
}

class CreateVideoPostRequested extends CreateVideoEvent {
  final String caption;
  const CreateVideoPostRequested({required this.caption});
  @override
  List<Object?> get props => [caption];
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

class CreateVideoProductTagToggled extends CreateVideoEvent {
  final Product product;
  const CreateVideoProductTagToggled(this.product);

  @override
  List<Object?> get props => [product];
}

class CreateVideoProductsUpdated extends CreateVideoEvent {
  final List<Product> products;
  const CreateVideoProductsUpdated(this.products);

  @override
  List<Object?> get props => [products];
}
