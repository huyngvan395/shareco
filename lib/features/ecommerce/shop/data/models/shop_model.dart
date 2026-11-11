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
  final String? contactPhone;
  final String? contactEmail;
  final String businessType;
  final String? pickupProvince;
  final String? pickupDistrict;
  final String? pickupWard;
  final String? pickupAddress;
  final String defaultCarrier;
  final bool isVerified;
  final double settledRevenue;
  final String? rejectionReason;
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
    this.contactPhone,
    this.contactEmail,
    this.businessType = 'individual',
    this.pickupProvince,
    this.pickupDistrict,
    this.pickupWard,
    this.pickupAddress,
    this.defaultCarrier = 'SPX Express',
    this.isVerified = false,
    this.settledRevenue = 0,
    this.rejectionReason,
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
      status: json['status'] as String? ?? 'pending',
      contactPhone: json['contact_phone'] as String?,
      contactEmail: json['contact_email'] as String?,
      businessType: json['business_type'] as String? ?? 'individual',
      pickupProvince: json['pickup_province'] as String?,
      pickupDistrict: json['pickup_district'] as String?,
      pickupWard: json['pickup_ward'] as String?,
      pickupAddress: json['pickup_address'] as String?,
      defaultCarrier: json['default_carrier'] as String? ?? 'SPX Express',
      isVerified: (json['is_verified'] as bool?) ??
          (json['has_blue_badge'] as bool?) ??
          false,
      settledRevenue: _asDouble(json['settled_revenue']),
      rejectionReason: json['rejection_reason'] as String?,
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
      contactPhone: contactPhone,
      contactEmail: contactEmail,
      businessType: businessType,
      pickupProvince: pickupProvince,
      pickupDistrict: pickupDistrict,
      pickupWard: pickupWard,
      pickupAddress: pickupAddress,
      defaultCarrier: defaultCarrier,
      isVerified: isVerified,
      settledRevenue: settledRevenue,
      rejectionReason: rejectionReason,
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
