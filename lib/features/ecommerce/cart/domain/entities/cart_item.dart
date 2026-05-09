import 'package:equatable/equatable.dart';

class CartItem extends Equatable {
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

  const CartItem({
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

  double get subtotal => qty * unitPrice;
  bool get isInStock => stockQty > 0;

  @override
  List<Object?> get props => [
        id,
        cartId,
        productId,
        shopId,
        variantId,
        title,
        variantName,
        shopName,
        imagePath,
        currency,
        qty,
        unitPrice,
        stockQty,
        createdAt,
      ];
}
