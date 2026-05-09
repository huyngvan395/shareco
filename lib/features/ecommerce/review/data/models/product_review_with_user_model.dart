import '../../domain/entities/product_review_with_user.dart';

class ProductReviewWithUserModel extends ProductReviewWithUser {
  const ProductReviewWithUserModel({
    required super.id,
    required super.productId,
    required super.userId,
    required super.userName,
    super.userAvatar,
    required super.rating,
    super.content,
    super.createdAt,
  });

  factory ProductReviewWithUserModel.fromJson(Map<String, dynamic> json) {
    final profile = json['profiles'] as Map<String, dynamic>?;
    final userName = profile?['display_name'] as String? ??
        profile?['username'] as String? ??
        'Người dùng ẩn danh';
    final userAvatar = profile?['avatar_url'] as String?;

    return ProductReviewWithUserModel(
      id: json['id'] as String,
      productId: json['product_id'] as String,
      userId: json['user_id'] as String,
      userName: userName,
      userAvatar: userAvatar,
      rating: json['rating'] as int,
      content: json['content'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }
}
