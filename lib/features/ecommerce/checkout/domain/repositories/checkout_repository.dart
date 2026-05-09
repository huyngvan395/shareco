import 'package:dartz/dartz.dart';

import '../../../../../core/errors/failure.dart';
import '../entities/checkout_address.dart';
import '../entities/checkout_result.dart';

abstract class CheckoutRepository {
  Future<Either<Failure, CheckoutResult>> placeOrder({
    required CheckoutAddress address,
    String? note,
    double discountAmount = 0.0,
  });

  Future<Either<Failure, CheckoutResult>> placeDirectOrder({
    required CheckoutAddress address,
    required String productId,
    String? variantId,
    required int qty,
    String? note,
    double discountAmount = 0.0,
  });
}
