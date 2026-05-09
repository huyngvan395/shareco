import 'package:dartz/dartz.dart';

import '../../../../../core/errors/failure.dart';
import '../entities/product.dart';

abstract class ProductRepository {
  Future<Either<Failure, List<Product>>> getProducts({
    int limit = 20,
    String? search,
    String? categoryId,
    String? brand,
  });

  Future<Either<Failure, Product>> getProductDetail(String productId);

  Future<Either<Failure, List<Product>>> getFlashSaleProducts();
}
