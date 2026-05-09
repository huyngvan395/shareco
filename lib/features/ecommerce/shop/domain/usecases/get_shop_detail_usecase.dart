import 'package:dartz/dartz.dart';

import '../../../../../core/errors/failure.dart';
import '../entities/shop.dart';
import '../repositories/shop_repository.dart';

class GetShopDetailUseCase {
  final ShopRepository repository;

  const GetShopDetailUseCase(this.repository);

  Future<Either<Failure, Shop>> call(String shopId) {
    return repository.getShopDetail(shopId);
  }
}
