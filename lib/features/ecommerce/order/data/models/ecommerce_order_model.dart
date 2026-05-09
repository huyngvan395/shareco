import '../../domain/entities/ecommerce_order.dart';
import 'order_item_model.dart';

class EcommerceOrderModel {
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
  final List<OrderItemModel> items;

  const EcommerceOrderModel({
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

  factory EcommerceOrderModel.fromJson(Map<String, dynamic> json) {
    final shop = json['shops'];
    final itemsJson = json['order_items'];
    final address = json['address_snapshot'];

    return EcommerceOrderModel(
      id: json['id'] as String,
      buyerId: json['buyer_id'] as String,
      shopId: json['shop_id'] as String,
      shopName: shop is Map<String, dynamic>
          ? shop['shop_name'] as String?
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
      items: itemsJson is List
          ? itemsJson
              .whereType<Map<String, dynamic>>()
              .map(OrderItemModel.fromJson)
              .toList(growable: false)
          : const [],
    );
  }

  EcommerceOrder toEntity() {
    return EcommerceOrder(
      id: id,
      buyerId: buyerId,
      shopId: shopId,
      shopName: shopName,
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
      items: items.map((item) => item.toEntity()).toList(),
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
