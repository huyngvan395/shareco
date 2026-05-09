import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../domain/entities/product.dart';
import '../../domain/entities/product_variant.dart';

class ProductPrice extends StatelessWidget {
  final Product product;
  final ProductVariant? variant;
  final double fontSize;
  final FontWeight fontWeight;

  const ProductPrice({
    super.key,
    required this.product,
    this.variant,
    this.fontSize = 16,
    this.fontWeight = FontWeight.w800,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      variant == null
          ? formatProduct(product)
          : formatAmount(variant!.price, product.currency),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: const Color(0xFFFF2D55),
        fontSize: fontSize,
        fontWeight: fontWeight,
      ),
    );
  }

  static String formatProduct(Product product) {
    final formatter = NumberFormat.decimalPattern('vi_VN');
    final min = formatter.format(product.priceMin);
    if (!product.hasPriceRange) return '$min ${product.currency}';
    final max = formatter.format(product.priceMax);
    return '$min - $max ${product.currency}';
  }

  static String formatAmount(double amount, String currency) {
    final formatter = NumberFormat.decimalPattern('vi_VN');
    return '${formatter.format(amount)} $currency';
  }
}
