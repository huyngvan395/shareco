import 'package:equatable/equatable.dart';

import 'order_item.dart';
import 'order_tracking_event.dart';

class EcommerceOrder extends Equatable {
  final String id;
  final String buyerId;
  final String shopId;
  final String? shopName;
  final String? shopOwnerId;
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
  final String? shippingCarrier;
  final String? shippingService;
  final String? trackingCode;
  final String? currentLocation;
  final String? pickupLocation;
  final DateTime? estimatedDeliveryAt;
  final DateTime? confirmedAt;
  final DateTime? shippedAt;
  final DateTime? deliveredAt;
  final String? cancelReason;
  final List<OrderItem> items;
  final List<OrderTrackingEvent> trackingEvents;

  const EcommerceOrder({
    required this.id,
    required this.buyerId,
    required this.shopId,
    this.shopName,
    this.shopOwnerId,
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
    this.shippingCarrier,
    this.shippingService,
    this.trackingCode,
    this.currentLocation,
    this.pickupLocation,
    this.estimatedDeliveryAt,
    this.confirmedAt,
    this.shippedAt,
    this.deliveredAt,
    this.cancelReason,
    this.items = const [],
    this.trackingEvents = const [],
  });

  int get totalItems => items.fold(0, (sum, item) => sum + item.qty);

  @override
  List<Object?> get props => [
        id,
        buyerId,
        shopId,
        shopName,
        shopOwnerId,
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
        shippingCarrier,
        shippingService,
        trackingCode,
        currentLocation,
        pickupLocation,
        estimatedDeliveryAt,
        confirmedAt,
        shippedAt,
        deliveredAt,
        cancelReason,
        items,
        trackingEvents,
      ];
}
