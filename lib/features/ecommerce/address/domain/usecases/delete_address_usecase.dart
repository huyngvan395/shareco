import 'package:dartz/dartz.dart';

import '../../../../../core/errors/failure.dart';
import '../entities/shipping_address.dart';
import '../repositories/address_repository.dart';

class DeleteAddressUseCase {
  final AddressRepository repository;

  const DeleteAddressUseCase(this.repository);

  Future<Either<Failure, List<ShippingAddress>>> call(String id) {
    return repository.deleteAddress(id);
  }
}
