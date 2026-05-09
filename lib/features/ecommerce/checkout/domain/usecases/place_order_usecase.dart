import 'package:dartz/dartz.dart';

import '../../../../../core/errors/failure.dart';
import '../entities/checkout_address.dart';
import '../entities/checkout_result.dart';
import '../repositories/checkout_repository.dart';

class PlaceOrderUseCase {
  final CheckoutRepository repository;

  const PlaceOrderUseCase(this.repository);

  Future<Either<Failure, CheckoutResult>> call({
    required CheckoutAddress address,
    String? note,
    double discountAmount = 0.0,
  }) {
    return repository.placeOrder(
      address: address,
      note: note,
      discountAmount: discountAmount,
    );
  }
}
