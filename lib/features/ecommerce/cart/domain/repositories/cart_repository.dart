import 'package:dartz/dartz.dart';

import '../../../../../core/errors/failure.dart';
import '../entities/cart.dart';

abstract class CartRepository {
  Future<Either<Failure, Cart>> getCart();

  Future<Either<Failure, Cart>> addToCart({
    required String productId,
    String? variantId,
    int qty = 1,
  });

  Future<Either<Failure, Cart>> updateCartItemQty({
    required String itemId,
    required int qty,
  });

  Future<Either<Failure, Cart>> removeCartItem(String itemId);
}
