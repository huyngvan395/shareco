import 'package:equatable/equatable.dart';

class ProductMedia extends Equatable {
  final String id;
  final String productId;
  final String mediaType;
  final String storagePath;
  final int sortOrder;
  final DateTime? createdAt;

  const ProductMedia({
    required this.id,
    required this.productId,
    required this.mediaType,
    required this.storagePath,
    required this.sortOrder,
    this.createdAt,
  });

  bool get isImage => mediaType == 'image';
  bool get isVideo => mediaType == 'video';

  @override
  List<Object?> get props => [
        id,
        productId,
        mediaType,
        storagePath,
        sortOrder,
        createdAt,
      ];
}
