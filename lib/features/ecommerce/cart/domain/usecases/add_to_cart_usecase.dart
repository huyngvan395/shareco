import 'package:dartz/dartz.dart';

import '../../../../../core/errors/failure.dart';
import '../entities/cart.dart';
import '../repositories/cart_repository.dart';

class AddToCartUseCase {
  final CartRepository repository;

  const AddToCartUseCase(this.repository);

  Future<Either<Failure, Cart>> call({
    required String productId,
    String? variantId,
    int qty = 1,
  }) {
    return repository.addToCart(
      productId: productId,
      variantId: variantId,
      qty: qty,
    );
  }
}
