import 'package:supabase_flutter/supabase_flutter.dart' hide AuthException;

import '../../../../../core/errors/exception.dart';
import '../../../../../core/services/supabase/index.dart';
import '../models/product_review_with_user_model.dart';
import '../models/review_model.dart';

abstract class ReviewRemoteDataSource {
  Future<ReviewModel> submitReview({
    required String productId,
    required String orderItemId,
    required int rating,
    String? content,
  });

  Future<List<ProductReviewWithUserModel>> getProductReviews(String productId);
}

class ReviewRemoteDataSourceImpl implements ReviewRemoteDataSource {
  @override
  Future<ReviewModel> submitReview({
    required String productId,
    required String orderItemId,
    required int rating,
    String? content,
  }) async {
    try {
      final userId = SupabaseService.auth.currentUser?.id;
      if (userId == null) {
        throw const AuthException('Bạn cần đăng nhập để đánh giá');
      }

      final response = await SupabaseService.from('product_reviews')
          .insert({
            'product_id': productId,
            'order_item_id': orderItemId,
            'user_id': userId,
            'rating': rating,
            'content': content,
          })
          .select()
          .single();

      // Update rating_avg and rating_count on products
      try {
        final allReviews = await SupabaseService.from('product_reviews')
            .select('rating')
            .eq('product_id', productId);
        final rows =
            (allReviews as List).whereType<Map<String, dynamic>>().toList();
        if (rows.isNotEmpty) {
          final totalRating = rows.fold<int>(
            0,
            (sum, r) => sum + ((r['rating'] as num?)?.toInt() ?? 0),
          );
          final avg = totalRating / rows.length;
          await SupabaseService.from('products')
              .update({
                'rating_avg': double.parse(avg.toStringAsFixed(2)),
                'rating_count': rows.length,
              })
              .eq('id', productId);
        }
      } catch (_) {}

      return ReviewModel.fromJson(response);
    } on PostgrestException catch (e) {
      if (e.code == '23505') {
        throw const ServerException('Bạn đã đánh giá sản phẩm này rồi');
      }
      throw ServerException(e.message);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<List<ProductReviewWithUserModel>> getProductReviews(String productId) async {
    try {
      final response = await SupabaseService.from('product_reviews')
          .select('*, profiles:user_id(username, display_name, avatar_url)')
          .eq('product_id', productId)
          .order('created_at', ascending: false);

      return (response as List)
          .whereType<Map<String, dynamic>>()
          .map(ProductReviewWithUserModel.fromJson)
          .toList();
    } on PostgrestException catch (e) {
      throw ServerException(e.message);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }
}
