import '../../domain/entities/cart_item.dart';

class CartItemModel {
  final String id;
  final String cartId;
  final String productId;
  final String? shopId;
  final String? variantId;
  final String title;
  final String? variantName;
  final String? shopName;
  final String? imagePath;
  final String currency;
  final int qty;
  final double unitPrice;
  final int stockQty;
  final DateTime? createdAt;

  const CartItemModel({
    required this.id,
    required this.cartId,
    required this.productId,
    this.shopId,
    this.variantId,
    required this.title,
    this.variantName,
    this.shopName,
    this.imagePath,
    required this.currency,
    required this.qty,
    required this.unitPrice,
    required this.stockQty,
    this.createdAt,
  });

  factory CartItemModel.fromJson(Map<String, dynamic> json) {
    final product = json['products'];
    final variant = json['product_variants'];
    final shop = product is Map<String, dynamic> ? product['shops'] : null;
    final rawVariantName =
        variant is Map<String, dynamic> ? variant['variant_name'] : null;
    final rawVariantSku =
        variant is Map<String, dynamic> ? variant['sku'] : null;
    final variantName = variant is Map<String, dynamic>
        ? (rawVariantName as String?) ?? (rawVariantSku as String?)
        : null;

    return CartItemModel(
      id: json['id'] as String,
      cartId: json['cart_id'] as String,
      productId: json['product_id'] as String,
      shopId: product is Map<String, dynamic> ? product['shop_id'] as String? : null,
      variantId: json['variant_id'] as String?,
      title: product is Map<String, dynamic>
          ? product['title'] as String? ?? 'Product'
          : 'Product',
      variantName: variantName,
      shopName:
          shop is Map<String, dynamic> ? shop['shop_name'] as String? : null,
      imagePath: product is Map<String, dynamic>
          ? product['cover_path'] as String?
          : null,
      currency: product is Map<String, dynamic>
          ? product['currency'] as String? ?? 'VND'
          : 'VND',
      qty: json['qty'] as int? ?? 0,
      unitPrice: _asDouble(json['unit_price']),
      stockQty: variant is Map<String, dynamic>
          ? variant['stock_qty'] as int? ?? 0
          : product is Map<String, dynamic>
              ? product['stock_total'] as int? ?? 0
              : 0,
      createdAt: _parseDate(json['created_at']),
    );
  }

  CartItem toEntity() {
    return CartItem(
      id: id,
      cartId: cartId,
      productId: productId,
      shopId: shopId,
      variantId: variantId,
      title: title,
      variantName: variantName,
      shopName: shopName,
      imagePath: imagePath,
      currency: currency,
      qty: qty,
      unitPrice: unitPrice,
      stockQty: stockQty,
      createdAt: createdAt,
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
