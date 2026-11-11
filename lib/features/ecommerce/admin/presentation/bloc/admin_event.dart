import 'package:equatable/equatable.dart';

abstract class AdminEvent extends Equatable {
  const AdminEvent();
  @override
  List<Object?> get props => [];
}

class AdminFetchShops extends AdminEvent {}

class AdminCreateShop extends AdminEvent {
  final String shopName;
  final String description;
  final String? logoPath;
  final String? coverPath;

  const AdminCreateShop({
    required this.shopName,
    required this.description,
    this.logoPath,
    this.coverPath,
  });

  @override
  List<Object?> get props => [shopName, description, logoPath, coverPath];
}

class AdminUpdateShop extends AdminEvent {
  final String id;
  final String shopName;
  final String description;
  final String? logoPath;
  final String? coverPath;

  const AdminUpdateShop({
    required this.id,
    required this.shopName,
    required this.description,
    this.logoPath,
    this.coverPath,
  });

  @override
  List<Object?> get props => [id, shopName, description, logoPath, coverPath];
}

class AdminToggleShopVerified extends AdminEvent {
  final String shopId;
  final bool isVerified;

  const AdminToggleShopVerified({
    required this.shopId,
    required this.isVerified,
  });

  @override
  List<Object?> get props => [shopId, isVerified];
}

class AdminToggleShopStatus extends AdminEvent {
  final String shopId;
  final String status;

  const AdminToggleShopStatus({
    required this.shopId,
    required this.status,
  });

  @override
  List<Object?> get props => [shopId, status];
}

class AdminApproveShop extends AdminEvent {
  final String shopId;

  const AdminApproveShop({required this.shopId});

  @override
  List<Object?> get props => [shopId];
}

class AdminRejectShop extends AdminEvent {
  final String shopId;
  final String reason;

  const AdminRejectShop({
    required this.shopId,
    required this.reason,
  });

  @override
  List<Object?> get props => [shopId, reason];
}

class AdminFetchUsers extends AdminEvent {}

class AdminToggleUserVerified extends AdminEvent {
  final String userId;
  final bool isVerified;

  const AdminToggleUserVerified({
    required this.userId,
    required this.isVerified,
  });

  @override
  List<Object?> get props => [userId, isVerified];
}

class AdminBanUser extends AdminEvent {
  final String userId;
  final bool isBanned;
  final String? reason;
  final int? durationDays;

  const AdminBanUser({
    required this.userId,
    required this.isBanned,
    this.reason,
    this.durationDays,
  });

  @override
  List<Object?> get props => [userId, isBanned, reason, durationDays];
}

class AdminToggleUserCanLive extends AdminEvent {
  final String userId;
  final bool canLive;
  final String? reason;

  const AdminToggleUserCanLive({
    required this.userId,
    required this.canLive,
    this.reason,
  });

  @override
  List<Object?> get props => [userId, canLive, reason];
}

class AdminToggleUserCanComment extends AdminEvent {
  final String userId;
  final bool canComment;

  const AdminToggleUserCanComment({
    required this.userId,
    required this.canComment,
  });

  @override
  List<Object?> get props => [userId, canComment];
}

class AdminIssueUserWarning extends AdminEvent {
  final String userId;
  final String reason;

  const AdminIssueUserWarning({
    required this.userId,
    required this.reason,
  });

  @override
  List<Object?> get props => [userId, reason];
}

class AdminFetchProducts extends AdminEvent {
  final String? shopId;
  const AdminFetchProducts({this.shopId});

  @override
  List<Object?> get props => [shopId];
}

class AdminCreateProduct extends AdminEvent {
  final String shopId;
  final String categoryId;
  final String title;
  final String description;
  final double price;
  final double? originalPrice;
  final int stock;
  final String? coverPath;
  final List<Map<String, dynamic>> variants;

  const AdminCreateProduct({
    required this.shopId,
    required this.categoryId,
    required this.title,
    required this.description,
    required this.price,
    this.originalPrice,
    required this.stock,
    this.coverPath,
    required this.variants,
  });

  @override
  List<Object?> get props => [
        shopId,
        categoryId,
        title,
        description,
        price,
        originalPrice,
        stock,
        coverPath,
        variants,
      ];
}

class AdminUpdateProduct extends AdminEvent {
  final String productId;
  final String shopId;
  final String categoryId;
  final String title;
  final String description;
  final double price;
  final double? originalPrice;
  final int stock;
  final String? coverPath;

  const AdminUpdateProduct({
    required this.productId,
    required this.shopId,
    required this.categoryId,
    required this.title,
    required this.description,
    required this.price,
    this.originalPrice,
    required this.stock,
    this.coverPath,
  });

  @override
  List<Object?> get props => [
        productId,
        shopId,
        categoryId,
        title,
        description,
        price,
        originalPrice,
        stock,
        coverPath,
      ];
}

class AdminDeleteProduct extends AdminEvent {
  final String productId;
  const AdminDeleteProduct({required this.productId});

  @override
  List<Object?> get props => [productId];
}

class AdminToggleProductStatus extends AdminEvent {
  final String productId;
  final String status;

  const AdminToggleProductStatus({
    required this.productId,
    required this.status,
  });

  @override
  List<Object?> get props => [productId, status];
}

class AdminFetchOrders extends AdminEvent {
  final String? shopId;
  const AdminFetchOrders({this.shopId});

  @override
  List<Object?> get props => [shopId];
}

class AdminUpdateOrderStatus extends AdminEvent {
  final String orderId;
  final String status;

  const AdminUpdateOrderStatus({required this.orderId, required this.status});

  @override
  List<Object?> get props => [orderId, status];
}

class AdminConfirmAndPackOrder extends AdminEvent {
  final String orderId;
  final String? note;

  const AdminConfirmAndPackOrder({
    required this.orderId,
    this.note,
  });

  @override
  List<Object?> get props => [orderId, note];
}

class AdminHandoverOrderToCarrier extends AdminEvent {
  final String orderId;
  final String carrier;
  final String? trackingCode;
  final String? pickupHub;

  const AdminHandoverOrderToCarrier({
    required this.orderId,
    required this.carrier,
    this.trackingCode,
    this.pickupHub,
  });

  @override
  List<Object?> get props => [orderId, carrier, trackingCode, pickupHub];
}

class AdminAdvanceOrderLocation extends AdminEvent {
  final String orderId;
  final String stepStatus;
  final String title;
  final String location;
  final String? description;

  const AdminAdvanceOrderLocation({
    required this.orderId,
    required this.stepStatus,
    required this.title,
    required this.location,
    this.description,
  });

  @override
  List<Object?> get props => [orderId, stepStatus, title, location, description];
}

class AdminSellerCancelOrder extends AdminEvent {
  final String orderId;
  final String reason;

  const AdminSellerCancelOrder({
    required this.orderId,
    required this.reason,
  });

  @override
  List<Object?> get props => [orderId, reason];
}

class AdminFetchVideos extends AdminEvent {}

class AdminUpdateVideoStatus extends AdminEvent {
  final String videoId;
  final String status; // 'draft' | 'published' | 'blocked' | 'deleted'

  const AdminUpdateVideoStatus({
    required this.videoId,
    required this.status,
  });

  @override
  List<Object?> get props => [videoId, status];
}

class AdminApproveAllPendingVideos extends AdminEvent {}

