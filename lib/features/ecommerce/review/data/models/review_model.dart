import '../../domain/entities/review.dart';

class ReviewModel {
  final String id;
  final String productId;
  final String orderItemId;
  final String userId;
  final int rating;
  final String? content;
  final DateTime? createdAt;

  const ReviewModel({
    required this.id,
    required this.productId,
    required this.orderItemId,
    required this.userId,
    required this.rating,
    this.content,
    this.createdAt,
  });

  factory ReviewModel.fromJson(Map<String, dynamic> json) {
    return ReviewModel(
      id: json['id'] as String,
      productId: json['product_id'] as String,
      orderItemId: json['order_item_id'] as String,
      userId: json['user_id'] as String,
      rating: json['rating'] as int,
      content: json['content'] as String?,
      createdAt: _parseDate(json['created_at']),
    );
  }

  Review toEntity() {
    return Review(
      id: id,
      productId: productId,
      orderItemId: orderItemId,
      userId: userId,
      rating: rating,
      content: content,
      createdAt: createdAt,
    );
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }
}
