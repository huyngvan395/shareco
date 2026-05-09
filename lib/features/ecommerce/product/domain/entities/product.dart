import 'package:equatable/equatable.dart';

import 'product_media.dart';
import 'product_variant.dart';

class Product extends Equatable {
  final String id;
  final String shopId;
  final String? categoryId;
  final String? shopName;
  final String title;
  final String? description;
  final String? brand;
  final String status;
  final double priceMin;
  final double priceMax;
  final double? originalPrice;
  final String currency;
  final int stockTotal;
  final int soldCount;
  final double ratingAvg;
  final int ratingCount;
  final String? coverPath;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final List<ProductMedia> media;
  final List<ProductVariant> variants;

  const Product({
    required this.id,
    required this.shopId,
    this.categoryId,
    this.shopName,
    required this.title,
    this.description,
    this.brand,
    required this.status,
    required this.priceMin,
    required this.priceMax,
    this.originalPrice,
    required this.currency,
    required this.stockTotal,
    required this.soldCount,
    required this.ratingAvg,
    required this.ratingCount,
    this.coverPath,
    this.createdAt,
    this.updatedAt,
    this.media = const [],
    this.variants = const [],
  });

  bool get isActive => status == 'active';
  bool get isInStock => stockTotal > 0;
  bool get hasPriceRange => priceMin != priceMax;

  int get discountPercent {
    if (originalPrice == null || originalPrice! <= priceMin || originalPrice == 0) return 0;
    return (((originalPrice! - priceMin) / originalPrice!) * 100).round();
  }

  String? get displayImagePath {
    if (coverPath != null && coverPath!.isNotEmpty) return coverPath;
    for (final item in media) {
      if (item.isImage && item.storagePath.isNotEmpty) return item.storagePath;
    }
    return null;
  }

  @override
  List<Object?> get props => [
        id,
        shopId,
        categoryId,
        shopName,
        title,
        description,
        brand,
        status,
        priceMin,
        priceMax,
        originalPrice,
        currency,
        stockTotal,
        soldCount,
        ratingAvg,
        ratingCount,
        coverPath,
        createdAt,
        updatedAt,
        media,
        variants,
      ];
}
