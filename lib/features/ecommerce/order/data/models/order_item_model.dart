import '../../domain/entities/order_item.dart';

class OrderItemModel {
  final String id;
  final String orderId;
  final String productId;
  final String? variantId;
  final String shopId;
  final String title;
  final String? variantName;
  final String? imagePath;
  final double unitPrice;
  final int qty;
  final double lineTotal;

  const OrderItemModel({
    required this.id,
    required this.orderId,
    required this.productId,
    this.variantId,
    required this.shopId,
    required this.title,
    this.variantName,
    this.imagePath,
    required this.unitPrice,
    required this.qty,
    required this.lineTotal,
  });

  factory OrderItemModel.fromJson(Map<String, dynamic> json) {
    final product = json['products'];
    return OrderItemModel(
      id: json['id'] as String,
      orderId: json['order_id'] as String,
      productId: json['product_id'] as String,
      variantId: json['variant_id'] as String?,
      shopId: json['shop_id'] as String,
      title: json['title_snapshot'] as String? ?? 'Product',
      variantName: json['variant_snapshot'] as String?,
      imagePath: product is Map<String, dynamic>
          ? product['cover_path'] as String?
          : null,
      unitPrice: _asDouble(json['unit_price']),
      qty: _asInt(json['qty']),
      lineTotal: _asDouble(json['line_total']),
    );
  }

  OrderItem toEntity() {
    return OrderItem(
      id: id,
      orderId: orderId,
      productId: productId,
      variantId: variantId,
      shopId: shopId,
      title: title,
      variantName: variantName,
      imagePath: imagePath,
      unitPrice: unitPrice,
      qty: qty,
      lineTotal: lineTotal,
    );
  }

  static double _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  static int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}
