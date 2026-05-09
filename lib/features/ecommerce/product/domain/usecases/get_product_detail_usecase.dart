import 'package:dartz/dartz.dart';

import '../../../../../core/errors/failure.dart';
import '../entities/product.dart';
import '../repositories/product_repository.dart';

class GetProductDetailUseCase {
  final ProductRepository repository;

  const GetProductDetailUseCase(this.repository);

  Future<Either<Failure, Product>> call(String productId) {
    return repository.getProductDetail(productId);
  }
}
