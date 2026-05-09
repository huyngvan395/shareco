import 'package:dartz/dartz.dart';

import '../../../../../core/errors/failure.dart';
import '../entities/product_review_with_user.dart';
import '../entities/review.dart';

abstract class ReviewRepository {
  Future<Either<Failure, Review>> submitReview({
    required String productId,
    required String orderItemId,
    required int rating,
    String? content,
  });

  Future<Either<Failure, List<ProductReviewWithUser>>> getProductReviews(String productId);
}
