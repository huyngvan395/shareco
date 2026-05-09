import '../../domain/entities/product.dart';
import 'product_media_model.dart';
import 'product_variant_model.dart';

class ProductModel {
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
  final List<ProductMediaModel> media;
  final List<ProductVariantModel> variants;

  const ProductModel({
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

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    final shop = json['shops'];
    final mediaJson = json['product_media'];
    final variantJson = json['product_variants'];

    return ProductModel(
      id: json['id'] as String,
      shopId: json['shop_id'] as String,
      categoryId: json['category_id'] as String?,
      shopName: shop is Map<String, dynamic> ? shop['shop_name'] as String? : null,
      title: json['title'] as String? ?? '',
      description: json['description'] as String?,
      brand: json['brand'] as String?,
      status: json['status'] as String? ?? 'active',
      priceMin: _asDouble(json['price_min']),
      priceMax: _asDouble(json['price_max']),
      originalPrice: json['original_price'] != null ? _asDouble(json['original_price']) : null,
      currency: json['currency'] as String? ?? 'VND',
      stockTotal: json['stock_total'] as int? ?? 0,
      soldCount: json['sold_count'] as int? ?? 0,
      ratingAvg: _asDouble(json['rating_avg']),
      ratingCount: json['rating_count'] as int? ?? 0,
      coverPath: json['cover_path'] as String?,
      createdAt: _parseDate(json['created_at']),
      updatedAt: _parseDate(json['updated_at']),
      media: _parseList(
        mediaJson,
        ProductMediaModel.fromJson,
      ),
      variants: _parseList(
        variantJson,
        ProductVariantModel.fromJson,
      ),
    );
  }

  Product toEntity() {
    return Product(
      id: id,
      shopId: shopId,
      categoryId: categoryId,
      shopName: shopName,
      title: title,
      description: description,
      brand: brand,
      status: status,
      priceMin: priceMin,
      priceMax: priceMax,
      originalPrice: originalPrice,
      currency: currency,
      stockTotal: stockTotal,
      soldCount: soldCount,
      ratingAvg: ratingAvg,
      ratingCount: ratingCount,
      coverPath: coverPath,
      createdAt: createdAt,
      updatedAt: updatedAt,
      media: media.map((item) => item.toEntity()).toList(),
      variants: variants.map((item) => item.toEntity()).toList(),
    );
  }

  static double _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }

  static List<T> _parseList<T>(
    dynamic value,
    T Function(Map<String, dynamic>) parser,
  ) {
    if (value is! List) return const [];
    return value
        .whereType<Map<String, dynamic>>()
        .map(parser)
        .toList(growable: false);
  }
}
