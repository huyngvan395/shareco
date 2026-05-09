import 'package:dartz/dartz.dart';

import '../../../../../core/errors/failure.dart';
import '../entities/checkout_address.dart';
import '../entities/checkout_result.dart';
import '../repositories/checkout_repository.dart';

class PlaceDirectOrderUseCase {
  final CheckoutRepository repository;

  const PlaceDirectOrderUseCase(this.repository);

  Future<Either<Failure, CheckoutResult>> call({
    required CheckoutAddress address,
    required String productId,
    String? variantId,
    required int qty,
    String? note,
    double discountAmount = 0.0,
  }) {
    return repository.placeDirectOrder(
      address: address,
      productId: productId,
      variantId: variantId,
      qty: qty,
      note: note,
      discountAmount: discountAmount,
    );
  }
}
