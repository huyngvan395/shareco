import 'package:dartz/dartz.dart';

import '../../../../../core/errors/failure.dart';
import '../entities/shipping_address.dart';
import '../repositories/address_repository.dart';

class SetDefaultAddressUseCase {
  final AddressRepository repository;

  const SetDefaultAddressUseCase(this.repository);

  Future<Either<Failure, List<ShippingAddress>>> call(String id) {
    return repository.setDefaultAddress(id);
  }
}
