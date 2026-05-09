import 'package:dartz/dartz.dart';

import '../../../../../core/errors/failure.dart';
import '../entities/shipping_address.dart';
import '../entities/shipping_address_draft.dart';
import '../repositories/address_repository.dart';

class SaveAddressUseCase {
  final AddressRepository repository;

  const SaveAddressUseCase(this.repository);

  Future<Either<Failure, ShippingAddress>> call(ShippingAddressDraft draft) {
    return repository.saveAddress(draft);
  }
}
