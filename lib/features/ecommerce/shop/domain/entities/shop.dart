import 'package:equatable/equatable.dart';

class Shop extends Equatable {
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

  const Shop({
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

  bool get isActive => status == 'active';
  bool get isPending => status == 'pending';
  bool get isRejected => status == 'rejected';
  bool get isBlocked => status == 'blocked';

  String get pickupHubLabel {
    final parts = [
      pickupDistrict?.trim(),
      pickupProvince?.trim(),
    ].whereType<String>().where((e) => e.isNotEmpty).toList();
    if (parts.isNotEmpty) return parts.join(', ');
    if (pickupAddress != null && pickupAddress!.trim().isNotEmpty) {
      return pickupAddress!.trim();
    }
    return 'Kho người bán';
  }

  String get fullPickupLocation {
    final parts = [
      pickupAddress?.trim(),
      pickupWard?.trim(),
      pickupDistrict?.trim(),
      pickupProvince?.trim(),
    ].whereType<String>().where((e) => e.isNotEmpty).toList();
    return parts.isEmpty ? 'Chưa cập nhật địa chỉ kho' : parts.join(', ');
  }

  @override
  List<Object?> get props => [
        id,
        ownerId,
        shopName,
        shopSlug,
        description,
        logoPath,
        coverPath,
        ratingAvg,
        ratingCount,
        productCount,
        followerCount,
        status,
        contactPhone,
        contactEmail,
        businessType,
        pickupProvince,
        pickupDistrict,
        pickupWard,
        pickupAddress,
        defaultCarrier,
        isVerified,
        settledRevenue,
        createdAt,
        updatedAt,
      ];
}
