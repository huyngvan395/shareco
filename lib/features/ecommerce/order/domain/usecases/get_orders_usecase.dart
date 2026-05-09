import 'package:dartz/dartz.dart';

import '../../../../../core/errors/failure.dart';
import '../entities/ecommerce_order.dart';
import '../repositories/order_repository.dart';

class GetOrdersUseCase {
  final OrderRepository repository;

  const GetOrdersUseCase(this.repository);

  Future<Either<Failure, List<EcommerceOrder>>> call({String? status}) {
    return repository.getOrders(status: status);
  }
}
