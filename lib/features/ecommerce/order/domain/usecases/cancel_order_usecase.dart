import 'package:dartz/dartz.dart';

import '../../../../../core/errors/failure.dart';
import '../entities/ecommerce_order.dart';
import '../repositories/order_repository.dart';

class CancelOrderUseCase {
  final OrderRepository repository;

  const CancelOrderUseCase(this.repository);

  Future<Either<Failure, EcommerceOrder>> call(String orderId) {
    return repository.cancelOrder(orderId);
  }
}
