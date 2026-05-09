import 'package:equatable/equatable.dart';

class Review extends Equatable {
  final String id;
  final String productId;
  final String orderItemId;
  final String userId;
  final int rating;
  final String? content;
  final DateTime? createdAt;

  const Review({
    required this.id,
    required this.productId,
    required this.orderItemId,
    required this.userId,
    required this.rating,
    this.content,
    this.createdAt,
  });

  @override
  List<Object?> get props => [
        id,
        productId,
        orderItemId,
        userId,
        rating,
        content,
        createdAt,
      ];
}
