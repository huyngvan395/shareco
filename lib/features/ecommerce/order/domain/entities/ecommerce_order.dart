import 'package:equatable/equatable.dart';

import 'order_item.dart';

class EcommerceOrder extends Equatable {
  final String id;
  final String buyerId;
  final String shopId;
  final String? shopName;
  final String orderCode;
  final String status;
  final double subtotalAmount;
  final double discountAmount;
  final double shippingAmount;
  final double totalAmount;
  final String currency;
  final Map<String, dynamic> addressSnapshot;
  final String? note;
  final DateTime? placedAt;
  final DateTime? updatedAt;
  final List<OrderItem> items;

  const EcommerceOrder({
    required this.id,
    required this.buyerId,
    required this.shopId,
    this.shopName,
    required this.orderCode,
    required this.status,
    required this.subtotalAmount,
    required this.discountAmount,
    required this.shippingAmount,
    required this.totalAmount,
    required this.currency,
    required this.addressSnapshot,
    this.note,
    this.placedAt,
    this.updatedAt,
    this.items = const [],
  });

  int get totalItems => items.fold(0, (sum, item) => sum + item.qty);

  @override
  List<Object?> get props => [
        id,
        buyerId,
        shopId,
        shopName,
        orderCode,
        status,
        subtotalAmount,
        discountAmount,
        shippingAmount,
        totalAmount,
        currency,
        addressSnapshot,
        note,
        placedAt,
        updatedAt,
        items,
      ];
}
