import '../../domain/entities/product_media.dart';

class ProductMediaModel {
  final String id;
  final String productId;
  final String mediaType;
  final String storagePath;
  final int sortOrder;
  final DateTime? createdAt;

  const ProductMediaModel({
    required this.id,
    required this.productId,
    required this.mediaType,
    required this.storagePath,
    required this.sortOrder,
    this.createdAt,
  });

  factory ProductMediaModel.fromJson(Map<String, dynamic> json) {
    return ProductMediaModel(
      id: json['id'] as String,
      productId: json['product_id'] as String,
      mediaType: json['media_type'] as String? ?? 'image',
      storagePath: json['storage_path'] as String? ?? '',
      sortOrder: json['sort_order'] as int? ?? 0,
      createdAt: _parseDate(json['created_at']),
    );
  }

  ProductMedia toEntity() {
    return ProductMedia(
      id: id,
      productId: productId,
      mediaType: mediaType,
      storagePath: storagePath,
      sortOrder: sortOrder,
      createdAt: createdAt,
    );
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }
}
