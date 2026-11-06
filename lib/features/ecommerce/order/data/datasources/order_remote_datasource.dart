import 'package:supabase_flutter/supabase_flutter.dart' hide AuthException;

import '../../../../../core/errors/exception.dart';
import '../../../../../core/services/supabase/index.dart';
import '../models/ecommerce_order_model.dart';

abstract class OrderRemoteDataSource {
  Future<List<EcommerceOrderModel>> getOrders({String? status});

  Future<EcommerceOrderModel> getOrderDetail(String orderId);

  Future<EcommerceOrderModel> cancelOrder(String orderId);
}

class OrderRemoteDataSourceImpl implements OrderRemoteDataSource {
  static const _orderSelect =
      'id,buyer_id,shop_id,order_code,status,subtotal_amount,discount_amount,'
      'shipping_amount,total_amount,currency,address_snapshot,note,placed_at,'
      'updated_at,shops(shop_name),'
      'order_items(id,order_id,product_id,variant_id,shop_id,title_snapshot,'
      'variant_snapshot,unit_price,qty,line_total,products(cover_path))';

  @override
  Future<List<EcommerceOrderModel>> getOrders({String? status}) async {
    final userId = SupabaseService.auth.currentUser?.id;
    if (userId == null) {
      throw const AuthException('Please sign in to view orders');
    }

    try {
      dynamic query = SupabaseService.from('orders')
          .select(_orderSelect)
          .eq('buyer_id', userId);

      if (status != null && status.isNotEmpty) {
        query = query.eq('status', status);
      }

      final response = await query
          .order('placed_at', ascending: false)
          .limit(50);

      return (response as List)
          .whereType<Map<String, dynamic>>()
          .map(EcommerceOrderModel.fromJson)
          .toList(growable: false);
    } on AuthException {
      rethrow;
    } on PostgrestException catch (e) {
      throw ServerException(e.message);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<EcommerceOrderModel> getOrderDetail(String orderId) async {
    final userId = SupabaseService.auth.currentUser?.id;
    if (userId == null) {
      throw const AuthException('Please sign in to view orders');
    }

    try {
      final response = await SupabaseService.from('orders')
          .select(_orderSelect)
          .eq('id', orderId)
          .eq('buyer_id', userId)
          .single();

      return EcommerceOrderModel.fromJson(response);
    } on AuthException {
      rethrow;
    } on PostgrestException catch (e) {
      if (e.code == 'PGRST116') {
        throw const NotFoundException('Order not found');
      }
      throw ServerException(e.message);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<EcommerceOrderModel> cancelOrder(String orderId) async {
    final userId = SupabaseService.auth.currentUser?.id;
    if (userId == null) {
      throw const AuthException('Please sign in to cancel orders');
    }

    try {
      final beforeDetail = await getOrderDetail(orderId);
      if (beforeDetail.status != 'pending') {
        throw const ServerException('Only pending orders can be cancelled');
      }

      try {
        await SupabaseService.client.rpc(
          'cancel_order',
          params: {'p_order_id': orderId},
        );
      } on PostgrestException {
        await SupabaseService.from('orders')
            .update({
              'status': 'cancelled',
              'cancelled_at': DateTime.now().toUtc().toIso8601String(),
            })
            .eq('id', orderId)
            .eq('buyer_id', userId);
      }

      // Restore variant stock, product stock, and sold_count safely
      for (final item in beforeDetail.items) {
        try {
          if (item.variantId != null && item.variantId!.isNotEmpty) {
            final varRes = await SupabaseService.from('product_variants')
                .select('stock_qty')
                .eq('id', item.variantId!)
                .maybeSingle();
            if (varRes != null) {
              final curVarStock = (varRes['stock_qty'] as num?)?.toInt() ?? 0;
              await SupabaseService.from('product_variants')
                  .update({'stock_qty': curVarStock + item.qty})
                  .eq('id', item.variantId!);
            }
          }
          final prodRes = await SupabaseService.from('products')
              .select('stock_total,sold_count')
              .eq('id', item.productId)
              .maybeSingle();
          if (prodRes != null) {
            final curStock = (prodRes['stock_total'] as num?)?.toInt() ?? 0;
            final curSold = (prodRes['sold_count'] as num?)?.toInt() ?? 0;
            await SupabaseService.from('products')
                .update({
                  'stock_total': curStock + item.qty,
                  'sold_count': (curSold - item.qty).clamp(0, 999999999),
                })
                .eq('id', item.productId);
          }
        } catch (_) {}
      }

      return getOrderDetail(orderId);
    } on AuthException {
      rethrow;
    } on ServerException {
      rethrow;
    } on PostgrestException catch (e) {
      throw ServerException(e.message);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }
}
