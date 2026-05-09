import 'package:dartz/dartz.dart';

import '../../../../../core/errors/failure.dart';
import '../entities/product.dart';
import '../repositories/product_repository.dart';

class GetFlashSaleProductsUseCase {
  final ProductRepository repository;

  const GetFlashSaleProductsUseCase({required this.repository});

  Future<Either<Failure, List<Product>>> call() {
    return repository.getFlashSaleProducts();
  }
}
