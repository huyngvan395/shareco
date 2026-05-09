import 'package:dartz/dartz.dart';

import '../../../../../core/errors/failure.dart';
import '../entities/cart.dart';
import '../repositories/cart_repository.dart';

class GetCartUseCase {
  final CartRepository repository;

  const GetCartUseCase(this.repository);

  Future<Either<Failure, Cart>> call() => repository.getCart();
}
