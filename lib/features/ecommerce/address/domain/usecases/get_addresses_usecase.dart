import 'package:dartz/dartz.dart';

import '../../../../../core/errors/failure.dart';
import '../entities/shipping_address.dart';
import '../repositories/address_repository.dart';

class GetAddressesUseCase {
  final AddressRepository repository;

  const GetAddressesUseCase(this.repository);

  Future<Either<Failure, List<ShippingAddress>>> call() {
    return repository.getAddresses();
  }
}
