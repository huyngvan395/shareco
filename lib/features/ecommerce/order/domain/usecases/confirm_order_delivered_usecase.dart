import 'package:dartz/dartz.dart';

import '../../../../../core/errors/failure.dart';
import '../entities/ecommerce_order.dart';
import '../repositories/order_repository.dart';

class ConfirmOrderDeliveredUseCase {
  final OrderRepository repository;

  const ConfirmOrderDeliveredUseCase(this.repository);

  Future<Either<Failure, EcommerceOrder>> call(String orderId) {
    return repository.confirmOrderDelivered(orderId);
  }
}

