import '../../domain/entities/ecommerce_order.dart';
import 'order_item_model.dart';
import 'order_tracking_event_model.dart';

class EcommerceOrderModel {
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
  final List<OrderItemModel> items;
  final List<OrderTrackingEventModel> trackingEvents;

  const EcommerceOrderModel({
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

  factory EcommerceOrderModel.fromJson(Map<String, dynamic> json) {
    final shop = json['shops'];
    final itemsJson = json['order_items'];
    final eventsJson = json['order_tracking_events'];
    final address = json['address_snapshot'];

    final parsedEvents = eventsJson is List
        ? eventsJson
            .whereType<Map<String, dynamic>>()
            .map(OrderTrackingEventModel.fromJson)
            .toList()
        : <OrderTrackingEventModel>[];

    parsedEvents.sort((a, b) {
      final ad = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bd = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bd.compareTo(ad); // newest first for Shopee/TikTok timeline
    });

    String? formattedShopLoc;
    if (shop is Map<String, dynamic>) {
      final parts = [
        shop['pickup_ward']?.toString().trim(),
        shop['pickup_district']?.toString().trim(),
        shop['pickup_province']?.toString().trim(),
      ].whereType<String>().where((s) => s.isNotEmpty).toList();
      if (parts.isNotEmpty) {
        formattedShopLoc = parts.join(', ');
      }
    }

    return EcommerceOrderModel(
      id: json['id'] as String,
      buyerId: json['buyer_id'] as String,
      shopId: json['shop_id'] as String,
      shopName: shop is Map<String, dynamic>
          ? shop['shop_name'] as String?
          : null,
      shopOwnerId: shop is Map<String, dynamic>
          ? shop['owner_id'] as String?
          : null,
      orderCode: json['order_code'] as String? ?? '',
      status: json['status'] as String? ?? 'pending',
      subtotalAmount: _asDouble(json['subtotal_amount']),
      discountAmount: _asDouble(json['discount_amount']),
      shippingAmount: _asDouble(json['shipping_amount']),
      totalAmount: _asDouble(json['total_amount']),
      currency: json['currency'] as String? ?? 'VND',
      addressSnapshot:
          address is Map<String, dynamic> ? address : const <String, dynamic>{},
      note: json['note'] as String?,
      placedAt: _parseDate(json['placed_at']),
      updatedAt: _parseDate(json['updated_at']),
      shippingCarrier: json['shipping_carrier'] as String?,
      shippingService: json['shipping_service'] as String?,
      trackingCode: json['tracking_code'] as String?,
      currentLocation: json['current_location'] as String?,
      pickupLocation: (json['pickup_location'] as String?) ?? formattedShopLoc,
      estimatedDeliveryAt: _parseDate(json['estimated_delivery_at']),
      confirmedAt: _parseDate(json['confirmed_at']),
      shippedAt: _parseDate(json['shipped_at']),
      deliveredAt: _parseDate(json['delivered_at']),
      cancelReason: json['cancel_reason'] as String?,
      items: itemsJson is List
          ? itemsJson
              .whereType<Map<String, dynamic>>()
              .map(OrderItemModel.fromJson)
              .toList(growable: false)
          : const [],
      trackingEvents: parsedEvents,
    );
  }

  EcommerceOrder toEntity() {
    return EcommerceOrder(
      id: id,
      buyerId: buyerId,
      shopId: shopId,
      shopName: shopName,
      shopOwnerId: shopOwnerId,
      orderCode: orderCode,
      status: status,
      subtotalAmount: subtotalAmount,
      discountAmount: discountAmount,
      shippingAmount: shippingAmount,
      totalAmount: totalAmount,
      currency: currency,
      addressSnapshot: addressSnapshot,
      note: note,
      placedAt: placedAt,
      updatedAt: updatedAt,
      shippingCarrier: shippingCarrier,
      shippingService: shippingService,
      trackingCode: trackingCode,
      currentLocation: currentLocation,
      pickupLocation: pickupLocation,
      estimatedDeliveryAt: estimatedDeliveryAt,
      confirmedAt: confirmedAt,
      shippedAt: shippedAt,
      deliveredAt: deliveredAt,
      cancelReason: cancelReason,
      items: items.map((item) => item.toEntity()).toList(),
      trackingEvents: trackingEvents.map((e) => e.toEntity()).toList(),
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
