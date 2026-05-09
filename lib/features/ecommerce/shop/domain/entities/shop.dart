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
    this.createdAt,
    this.updatedAt,
  });

  bool get isActive => status == 'active';

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
        createdAt,
        updatedAt,
      ];
}
