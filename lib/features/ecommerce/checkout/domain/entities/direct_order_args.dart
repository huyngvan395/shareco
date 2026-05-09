import '../../../product/domain/entities/product.dart';
import '../../../product/domain/entities/product_variant.dart';

class DirectOrderArgs {
  final Product product;
  final ProductVariant? selectedVariant;
  final int qty;

  const DirectOrderArgs({
    required this.product,
    this.selectedVariant,
    this.qty = 1,
  });
}
