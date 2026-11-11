import 'package:supabase_flutter/supabase_flutter.dart' hide AuthException;

import '../../../../../core/errors/exception.dart';
import '../../../../../core/services/supabase/index.dart';
import '../models/ecommerce_order_model.dart';

abstract class OrderRemoteDataSource {
  Future<List<EcommerceOrderModel>> getOrders({String? status});

  Future<EcommerceOrderModel> getOrderDetail(String orderId);

  Future<EcommerceOrderModel> cancelOrder(String orderId, {String? reason});

  Future<EcommerceOrderModel> confirmOrderDelivered(String orderId);
}

class OrderRemoteDataSourceImpl implements OrderRemoteDataSource {
  static const _legacyOrderSelect =
      'id,buyer_id,shop_id,order_code,status,subtotal_amount,discount_amount,'
      'shipping_amount,total_amount,currency,address_snapshot,note,placed_at,'
      'updated_at,shops(shop_name,owner_id),'
      'order_items(id,order_id,product_id,variant_id,shop_id,title_snapshot,'
      'variant_snapshot,unit_price,qty,line_total,products(cover_path))';

  static const _orderSelectWithTracking =
      'id,buyer_id,shop_id,order_code,status,subtotal_amount,discount_amount,'
      'shipping_amount,total_amount,currency,address_snapshot,note,placed_at,'
      'updated_at,shipping_carrier,shipping_service,tracking_code,'
      'current_location,pickup_location,estimated_delivery_at,confirmed_at,'
      'shipped_at,delivered_at,cancel_reason,'
      'shops(shop_name,owner_id,pickup_province,pickup_district,pickup_ward),'
      'order_items(id,order_id,product_id,variant_id,shop_id,title_snapshot,'
      'variant_snapshot,unit_price,qty,line_total,products(cover_path)),'
      'order_tracking_events(id,order_id,status,title,description,location,'
      'carrier_name,lat,lng,actor_role,created_at)';

  @override
  Future<List<EcommerceOrderModel>> getOrders({String? status}) async {
    final userId = SupabaseService.auth.currentUser?.id;
    if (userId == null) {
      throw const AuthException('Vui lòng đăng nhập để xem đơn hàng');
    }

    try {
      dynamic response;
      try {
        dynamic query = SupabaseService.from('orders')
            .select(_orderSelectWithTracking)
            .eq('buyer_id', userId);
        if (status != null && status.isNotEmpty) {
          query = query.eq('status', status);
        }
        response = await query.order('placed_at', ascending: false).limit(50);
      } on PostgrestException catch (e) {
        if (e.code == '42703' || e.code == '42P01' || e.code == 'PGRST204' || e.code == 'PGRST200') {
          dynamic query = SupabaseService.from('orders')
              .select(_legacyOrderSelect)
              .eq('buyer_id', userId);
          if (status != null && status.isNotEmpty) {
            query = query.eq('status', status);
          }
          response = await query.order('placed_at', ascending: false).limit(50);
        } else {
          rethrow;
        }
      }

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
      throw const AuthException('Vui lòng đăng nhập để xem đơn hàng');
    }

    try {
      Map<String, dynamic> response;
      try {
        response = await SupabaseService.from('orders')
            .select(_orderSelectWithTracking)
            .eq('id', orderId)
            .single();
      } on PostgrestException catch (e) {
        if (e.code == '42703' || e.code == '42P01' || e.code == 'PGRST204' || e.code == 'PGRST200') {
          response = await SupabaseService.from('orders')
              .select(_legacyOrderSelect)
              .eq('id', orderId)
              .single();
        } else {
          rethrow;
        }
      }

      return EcommerceOrderModel.fromJson(response);
    } on AuthException {
      rethrow;
    } on PostgrestException catch (e) {
      if (e.code == 'PGRST116') {
        throw const NotFoundException('Không tìm thấy đơn hàng');
      }
      throw ServerException(e.message);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<EcommerceOrderModel> cancelOrder(
    String orderId, {
    String? reason,
  }) async {
    final userId = SupabaseService.auth.currentUser?.id;
    if (userId == null) {
      throw const AuthException('Vui lòng đăng nhập để hủy đơn');
    }

    try {
      final beforeDetail = await getOrderDetail(orderId);
      if (beforeDetail.status != 'pending' && beforeDetail.status != 'paid') {
        throw const ServerException(
          'Chỉ có thể hủy đơn khi người bán chưa đóng gói hoặc giao hàng',
        );
      }

      var rpcHandled = false;
      try {
        await SupabaseService.client.rpc(
          'cancel_order',
          params: {
            'p_order_id': orderId,
            'p_reason': reason ?? 'Người mua yêu cầu hủy đơn',
          },
        );
        rpcHandled = true;
      } on PostgrestException catch (e) {
        if (e.code == 'PGRST202' || e.code == '42883') {
          try {
            await SupabaseService.client.rpc(
              'cancel_order',
              params: {'p_order_id': orderId},
            );
          } catch (_) {
            await SupabaseService.from('orders')
                .update({
                  'status': 'cancelled',
                  'updated_at': DateTime.now().toUtc().toIso8601String(),
                })
                .eq('id', orderId)
                .eq('buyer_id', userId);
          }
        } else {
          rethrow;
        }
      }

      if (!rpcHandled) {
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

  @override
  Future<EcommerceOrderModel> confirmOrderDelivered(String orderId) async {
    final userId = SupabaseService.auth.currentUser?.id;
    if (userId == null) {
      throw const AuthException('Vui lòng đăng nhập để xác nhận nhận hàng');
    }

    try {
      try {
        await SupabaseService.client.rpc(
          'confirm_order_delivered',
          params: {'p_order_id': orderId},
        );
      } on PostgrestException catch (e) {
        if (e.code == 'PGRST202' || e.code == '42883') {
          await SupabaseService.from('orders')
              .update({
                'status': 'completed',
                'updated_at': DateTime.now().toUtc().toIso8601String(),
              })
              .eq('id', orderId)
              .eq('buyer_id', userId);
        } else {
          rethrow;
        }
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
