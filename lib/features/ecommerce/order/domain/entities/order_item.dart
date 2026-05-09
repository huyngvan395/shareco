import 'package:equatable/equatable.dart';

class OrderItem extends Equatable {
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

  const OrderItem({
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

  @override
  List<Object?> get props => [
        id,
        orderId,
        productId,
        variantId,
        shopId,
        title,
        variantName,
        imagePath,
        unitPrice,
        qty,
        lineTotal,
      ];
}
