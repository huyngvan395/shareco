import '../../domain/entities/product_variant.dart';

class ProductVariantModel {
  final String id;
  final String productId;
  final String? sku;
  final String? variantName;
  final double price;
  final double? compareAtPrice;
  final int stockQty;
  final int? weightGrams;
  final String status;
  final DateTime? createdAt;

  const ProductVariantModel({
    required this.id,
    required this.productId,
    this.sku,
    this.variantName,
    required this.price,
    this.compareAtPrice,
    required this.stockQty,
    required this.status,
    this.weightGrams,
    this.createdAt,
  });

  factory ProductVariantModel.fromJson(Map<String, dynamic> json) {
    return ProductVariantModel(
      id: json['id'] as String,
      productId: json['product_id'] as String,
      sku: json['sku'] as String?,
      variantName: json['variant_name'] as String?,
      price: _asDouble(json['price']),
      compareAtPrice: _asNullableDouble(json['compare_at_price']),
      stockQty: json['stock_qty'] as int? ?? 0,
      weightGrams: json['weight_grams'] as int?,
      status: json['status'] as String? ?? 'active',
      createdAt: _parseDate(json['created_at']),
    );
  }

  ProductVariant toEntity() {
    return ProductVariant(
      id: id,
      productId: productId,
      sku: sku,
      variantName: variantName,
      price: price,
      compareAtPrice: compareAtPrice,
      stockQty: stockQty,
      weightGrams: weightGrams,
      status: status,
      createdAt: createdAt,
    );
  }

  static double _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  static double? _asNullableDouble(dynamic value) {
    if (value == null) return null;
    return _asDouble(value);
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }
}
