import 'package:dartz/dartz.dart';

import '../../../../../core/errors/failure.dart';
import '../entities/cart.dart';
import '../repositories/cart_repository.dart';

class RemoveCartItemUseCase {
  final CartRepository repository;

  const RemoveCartItemUseCase(this.repository);

  Future<Either<Failure, Cart>> call(String itemId) {
    return repository.removeCartItem(itemId);
  }
}
