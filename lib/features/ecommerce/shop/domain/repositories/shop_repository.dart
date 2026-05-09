import 'package:dartz/dartz.dart';

import '../../../../../core/errors/failure.dart';
import '../../../product/domain/entities/product.dart';
import '../entities/shop.dart';

abstract class ShopRepository {
  Future<Either<Failure, Shop>> getShopDetail(String shopId);

  Future<Either<Failure, List<Product>>> getShopProducts({
    required String shopId,
    int limit = 20,
    String? search,
  });
}
