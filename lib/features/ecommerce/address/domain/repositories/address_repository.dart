import 'package:dartz/dartz.dart';

import '../../../../../core/errors/failure.dart';
import '../entities/shipping_address.dart';
import '../entities/shipping_address_draft.dart';

abstract class AddressRepository {
  Future<Either<Failure, List<ShippingAddress>>> getAddresses();

  Future<Either<Failure, ShippingAddress>> saveAddress(
    ShippingAddressDraft draft,
  );

  Future<Either<Failure, List<ShippingAddress>>> deleteAddress(String id);

  Future<Either<Failure, List<ShippingAddress>>> setDefaultAddress(String id);
}
