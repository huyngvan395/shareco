import 'package:dartz/dartz.dart';

import '../../../../../core/errors/failure.dart';
import '../../../product/domain/entities/product.dart';
import '../repositories/shop_repository.dart';

class GetShopProductsUseCase {
  final ShopRepository repository;

  const GetShopProductsUseCase(this.repository);

  Future<Either<Failure, List<Product>>> call({
    required String shopId,
    int limit = 20,
    String? search,
  }) {
    return repository.getShopProducts(
      shopId: shopId,
      limit: limit,
      search: search,
    );
  }
}
