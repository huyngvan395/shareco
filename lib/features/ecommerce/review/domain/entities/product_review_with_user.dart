import 'package:equatable/equatable.dart';

class ProductReviewWithUser extends Equatable {
  final String id;
  final String productId;
  final String userId;
  final String userName;
  final String? userAvatar;
  final int rating;
  final String? content;
  final DateTime? createdAt;

  const ProductReviewWithUser({
    required this.id,
    required this.productId,
    required this.userId,
    required this.userName,
    this.userAvatar,
    required this.rating,
    this.content,
    this.createdAt,
  });

  @override
  List<Object?> get props => [
        id,
        productId,
        userId,
        userName,
        userAvatar,
        rating,
        content,
        createdAt,
      ];
}
