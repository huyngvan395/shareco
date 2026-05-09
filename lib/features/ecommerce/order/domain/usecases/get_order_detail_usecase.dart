import 'package:dartz/dartz.dart';

import '../../../../../core/errors/failure.dart';
import '../entities/ecommerce_order.dart';
import '../repositories/order_repository.dart';

class GetOrderDetailUseCase {
  final OrderRepository repository;

  const GetOrderDetailUseCase(this.repository);

  Future<Either<Failure, EcommerceOrder>> call(String orderId) {
    return repository.getOrderDetail(orderId);
  }
}
