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
  List<Object?> get props => [shopId, categoryId, title, description, price, originalPrice, stock, coverPath, variants];
}

class AdminUpdateProduct extends AdminEvent {
  final String productId;
  final String title;
  final String description;
  final double price;
  final double? originalPrice;
  final int stock;
  final String? coverPath;

  const AdminUpdateProduct({
    required this.productId,
    required this.title,
    required this.description,
    required this.price,
    this.originalPrice,
    required this.stock,
    this.coverPath,
  });

  @override
  List<Object?> get props => [productId, title, description, price, originalPrice, stock, coverPath];
}

class AdminDeleteProduct extends AdminEvent {
  final String productId;
  const AdminDeleteProduct({required this.productId});

  @override
  List<Object?> get props => [productId];
}

class AdminFetchOrders extends AdminEvent {}

class AdminUpdateOrderStatus extends AdminEvent {
  final String orderId;
  final String status;

  const AdminUpdateOrderStatus({required this.orderId, required this.status});

  @override
  List<Object?> get props => [orderId, status];
}
