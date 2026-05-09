import 'package:dartz/dartz.dart';

import '../../../../../core/errors/failure.dart';
import '../entities/cart.dart';
import '../repositories/cart_repository.dart';

class UpdateCartItemQtyUseCase {
  final CartRepository repository;

  const UpdateCartItemQtyUseCase(this.repository);

  Future<Either<Failure, Cart>> call({
    required String itemId,
    required int qty,
  }) {
    return repository.updateCartItemQty(itemId: itemId, qty: qty);
  }
}
