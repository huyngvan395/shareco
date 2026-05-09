import '../../domain/entities/shop.dart';

class ShopModel {
  final String id;
  final String ownerId;
  final String shopName;
  final String shopSlug;
  final String? description;
  final String? logoPath;
  final String? coverPath;
  final double ratingAvg;
  final int ratingCount;
  final int productCount;
  final int followerCount;
  final String status;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const ShopModel({
    required this.id,
    required this.ownerId,
    required this.shopName,
    required this.shopSlug,
    this.description,
    this.logoPath,
    this.coverPath,
    required this.ratingAvg,
    required this.ratingCount,
    required this.productCount,
    required this.followerCount,
    required this.status,
    this.createdAt,
    this.updatedAt,
  });

  factory ShopModel.fromJson(Map<String, dynamic> json) {
    return ShopModel(
      id: json['id'] as String,
      ownerId: json['owner_id'] as String,
      shopName: json['shop_name'] as String,
      shopSlug: json['shop_slug'] as String,
      description: json['description'] as String?,
      logoPath: json['logo_path'] as String?,
      coverPath: json['cover_path'] as String?,
      ratingAvg: _asDouble(json['rating_avg']),
      ratingCount: json['rating_count'] as int? ?? 0,
      productCount: json['product_count'] as int? ?? 0,
      followerCount: json['follower_count'] as int? ?? 0,
      status: json['status'] as String? ?? 'active',
      createdAt: _parseDate(json['created_at']),
      updatedAt: _parseDate(json['updated_at']),
    );
  }

  Shop toEntity() {
    return Shop(
      id: id,
      ownerId: ownerId,
      shopName: shopName,
      shopSlug: shopSlug,
      description: description,
      logoPath: logoPath,
      coverPath: coverPath,
      ratingAvg: ratingAvg,
      ratingCount: ratingCount,
      productCount: productCount,
      followerCount: followerCount,
      status: status,
      createdAt: createdAt,
      updatedAt: updatedAt,
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
}
