import 'package:dartz/dartz.dart';

import '../../../../../core/errors/failure.dart';
import '../entities/product_review_with_user.dart';
import '../repositories/review_repository.dart';

class GetProductReviewsUseCase {
  final ReviewRepository repository;

  const GetProductReviewsUseCase({required this.repository});

  Future<Either<Failure, List<ProductReviewWithUser>>> call(String productId) {
    return repository.getProductReviews(productId);
  }
}
