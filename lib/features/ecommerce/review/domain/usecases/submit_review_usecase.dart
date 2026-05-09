import 'package:dartz/dartz.dart';

import '../../../../../core/errors/failure.dart';
import '../entities/review.dart';
import '../repositories/review_repository.dart';

class SubmitReviewUseCase {
  final ReviewRepository repository;

  const SubmitReviewUseCase(this.repository);

  Future<Either<Failure, Review>> call({
    required String productId,
    required String orderItemId,
    required int rating,
    String? content,
  }) {
    return repository.submitReview(
      productId: productId,
      orderItemId: orderItemId,
      rating: rating,
      content: content,
    );
  }
}
