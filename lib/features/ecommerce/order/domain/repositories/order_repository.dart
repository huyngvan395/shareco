import 'package:dartz/dartz.dart';

import '../../../../../core/errors/failure.dart';
import '../entities/ecommerce_order.dart';

abstract class OrderRepository {
  Future<Either<Failure, List<EcommerceOrder>>> getOrders({
    String? status,
  });

  Future<Either<Failure, EcommerceOrder>> getOrderDetail(String orderId);

  Future<Either<Failure, EcommerceOrder>> cancelOrder(String orderId);
}
