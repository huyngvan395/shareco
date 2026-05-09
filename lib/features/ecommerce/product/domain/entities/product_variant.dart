import 'package:equatable/equatable.dart';

class ProductVariant extends Equatable {
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

  const ProductVariant({
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

  bool get isActive => status == 'active';
  bool get isInStock => stockQty > 0;

  @override
  List<Object?> get props => [
        id,
        productId,
        sku,
        variantName,
        price,
        compareAtPrice,
        stockQty,
        weightGrams,
        status,
        createdAt,
      ];
}
