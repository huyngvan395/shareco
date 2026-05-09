import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/usecases/submit_review_usecase.dart';
import 'review_event.dart';
import 'review_state.dart';

class ReviewBloc extends Bloc<ReviewEvent, ReviewState> {
  final SubmitReviewUseCase submitReviewUseCase;

  ReviewBloc({required this.submitReviewUseCase}) : super(ReviewInitial()) {
    on<ReviewSubmitted>(_onSubmitted);
  }

  Future<void> _onSubmitted(
    ReviewSubmitted event,
    Emitter<ReviewState> emit,
  ) async {
    emit(ReviewSubmitting());
    final result = await submitReviewUseCase(
      productId: event.productId,
      orderItemId: event.orderItemId,
      rating: event.rating,
      content: event.content,
    );

    result.fold(
      (failure) => emit(ReviewSubmitFailure(failure.message)),
      (_) => emit(ReviewSubmitSuccess()),
    );
  }
}
