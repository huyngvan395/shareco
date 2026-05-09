import 'package:equatable/equatable.dart';

abstract class ReviewEvent extends Equatable {
  const ReviewEvent();

  @override
  List<Object?> get props => [];
}

class ReviewSubmitted extends ReviewEvent {
  final String productId;
  final String orderItemId;
  final int rating;
  final String? content;

  const ReviewSubmitted({
    required this.productId,
    required this.orderItemId,
    required this.rating,
    this.content,
  });

  @override
  List<Object?> get props => [productId, orderItemId, rating, content];
}
