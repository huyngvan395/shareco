import 'package:dartz/dartz.dart';

import '../../../../../core/errors/failure.dart';
import '../entities/product.dart';
import '../repositories/product_repository.dart';

class GetProductsUseCase {
  final ProductRepository repository;

  const GetProductsUseCase(this.repository);

  Future<Either<Failure, List<Product>>> call({
    int limit = 20,
    String? search,
    String? categoryId,
    String? brand,
  }) {
    return repository.getProducts(
      limit: limit,
      search: search,
      categoryId: categoryId,
      brand: brand,
    );
  }
}
