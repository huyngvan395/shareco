import 'package:supabase_flutter/supabase_flutter.dart' hide AuthException;

import '../../../../../core/errors/exception.dart';
import '../../../../../core/services/supabase/index.dart';
import '../../domain/entities/checkout_address.dart';
import '../../domain/entities/checkout_result.dart';

abstract class CheckoutRemoteDataSource {
  Future<CheckoutResult> placeOrder({
    required CheckoutAddress address,
    String? note,
    double discountAmount = 0.0,
  });

  Future<CheckoutResult> placeDirectOrder({
    required CheckoutAddress address,
    required String productId,
    String? variantId,
    required int qty,
    String? note,
    double discountAmount = 0.0,
  });
}

class CheckoutRemoteDataSourceImpl implements CheckoutRemoteDataSource {
  static const _cartSelect =
      'id,user_id,cart_items(id,product_id,variant_id,qty,unit_price,'
      'products(id,shop_id,title,currency,price_min,stock_total,status),'
      'product_variants(id,sku,variant_name,price,stock_qty,status))';

  @override
  Future<CheckoutResult> placeOrder({
    required CheckoutAddress address,
    String? note,
    double discountAmount = 0.0,
  }) async {
    final userId = SupabaseService.auth.currentUser?.id;
    if (userId == null) {
      throw const AuthException('Please sign in to checkout');
    }

    try {
      final cart = await _fetchCurrentCart(userId);
      final cartId = cart['id'] as String;
      final items = _parseItems(cart['cart_items']);
      if (items.isEmpty) {
        throw const ServerException('Cart is empty');
      }

      final groups = <String, List<_CheckoutItem>>{};
      for (final item in items) {
        groups.putIfAbsent(item.shopId, () => []).add(item);
      }

      final orderIds = <String>[];
      final orderCodes = <String>[];
      var totalAmount = 0.0;
      var currency = items.first.currency;
      var index = 0;

      final totalSubtotal = items.fold<double>(
        0,
        (sum, item) => sum + item.lineTotal,
      );

      for (final entry in groups.entries) {
        index++;
        final groupItems = entry.value;
        final subtotal = groupItems.fold<double>(
          0,
          (sum, item) => sum + item.lineTotal,
        );
        final orderCode = _buildOrderCode(index);
        currency = groupItems.first.currency;

        final orderDiscount = totalSubtotal > 0
            ? (subtotal / totalSubtotal * discountAmount)
            : 0.0;
        final orderTotal = (subtotal - orderDiscount).clamp(0.0, double.infinity);

        final order = await SupabaseService.from('orders')
            .insert({
              'buyer_id': userId,
              'shop_id': entry.key,
              'order_code': orderCode,
              'status': 'pending',
              'subtotal_amount': subtotal,
              'discount_amount': orderDiscount,
              'shipping_amount': 0,
              'total_amount': orderTotal,
              'currency': currency,
              'address_snapshot': address.toJson(),
              'note': note,
            })
            .select('id,order_code,total_amount')
            .single();

        final orderId = order['id'] as String;
        await SupabaseService.from('order_items').insert(
          groupItems.map((item) {
            return {
              'order_id': orderId,
              'product_id': item.productId,
              'variant_id': item.variantId,
              'shop_id': item.shopId,
              'title_snapshot': item.title,
              'variant_snapshot': item.variantName,
              'unit_price': item.unitPrice,
              'qty': item.qty,
              'line_total': item.lineTotal,
            };
          }).toList(),
        );

        // Deduct Variant and Product stock
        for (final item in groupItems) {
          if (item.variantId != null) {
            final varRes = await SupabaseService.from('product_variants')
                .select('stock_qty')
                .eq('id', item.variantId!)
                .single();
            final currentVarStock = _asInt(varRes['stock_qty']);
            await SupabaseService.from('product_variants')
                .update({'stock_qty': (currentVarStock - item.qty).clamp(0, 999999)})
                .eq('id', item.variantId!);
          }
          final prodRes = await SupabaseService.from('products')
              .select('stock_total')
              .eq('id', item.productId)
              .single();
          final currentProdStock = _asInt(prodRes['stock_total']);
          await SupabaseService.from('products')
              .update({'stock_total': (currentProdStock - item.qty).clamp(0, 999999)})
              .eq('id', item.productId);
        }

        orderIds.add(orderId);
        orderCodes.add(order['order_code'] as String);
        totalAmount += _asDouble(order['total_amount']);
      }

      await SupabaseService.from('cart_items').delete().eq('cart_id', cartId);

      return CheckoutResult(
        orderIds: orderIds,
        orderCodes: orderCodes,
        totalAmount: totalAmount,
        currency: currency,
      );
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
  Future<CheckoutResult> placeDirectOrder({
    required CheckoutAddress address,
    required String productId,
    String? variantId,
    required int qty,
    String? note,
    double discountAmount = 0.0,
  }) async {
    final userId = SupabaseService.auth.currentUser?.id;
    if (userId == null) {
      throw const AuthException('Please sign in to checkout');
    }

    try {
      final productResponse = await SupabaseService.from('products')
          .select('id,shop_id,title,currency,price_min,stock_total,status,product_variants(id,sku,variant_name,price,stock_qty,status)')
          .eq('id', productId)
          .single();

      final variants = productResponse['product_variants'] as List;
      Map<String, dynamic>? selectedVariant;
      if (variantId != null) {
        final matches = variants.where((v) => v['id'] == variantId).toList();
        if (matches.isNotEmpty) selectedVariant = matches.first;
      } else if (variants.isNotEmpty) {
        selectedVariant = variants.first;
      }

      final shopId = productResponse['shop_id'] as String;
      final title = productResponse['title'] as String;
      final currency = productResponse['currency'] as String;
      final productStatus = productResponse['status'] as String;
      
      final variantName = selectedVariant?['variant_name'] as String?;
      final variantSku = selectedVariant?['sku'] as String?;
      final resolvedVariantName = variantName ?? variantSku;
      
      final unitPrice = selectedVariant != null 
          ? _asDouble(selectedVariant['price']) 
          : _asDouble(productResponse['price_min']);
          
      final stockQty = selectedVariant != null 
          ? _asInt(selectedVariant['stock_qty']) 
          : _asInt(productResponse['stock_total']);
          
      final itemStatus = selectedVariant != null 
          ? selectedVariant['status'] as String 
          : productStatus;

      if (productStatus != 'active' || itemStatus != 'active') {
        throw const ServerException('Product is unavailable');
      }
      if (qty <= 0 || qty > stockQty) {
        throw const ServerException('Exceeds available stock');
      }

      final lineTotal = qty * unitPrice;
      final orderCode = _buildOrderCode(1);
      final orderTotal = (lineTotal - discountAmount).clamp(0.0, double.infinity);

      final order = await SupabaseService.from('orders')
          .insert({
            'buyer_id': userId,
            'shop_id': shopId,
            'order_code': orderCode,
            'status': 'pending',
            'subtotal_amount': lineTotal,
            'discount_amount': discountAmount,
            'shipping_amount': 0,
            'total_amount': orderTotal,
            'currency': currency,
            'address_snapshot': address.toJson(),
            'note': note,
          })
          .select('id,order_code,total_amount')
          .single();

      final orderId = order['id'] as String;
      await SupabaseService.from('order_items').insert({
        'order_id': orderId,
        'product_id': productId,
        'variant_id': variantId,
        'shop_id': shopId,
        'title_snapshot': title,
        'variant_snapshot': resolvedVariantName,
        'unit_price': unitPrice,
        'qty': qty,
        'line_total': lineTotal,
      });

      // Deduct stock
      if (variantId != null) {
        final varRes = await SupabaseService.from('product_variants')
            .select('stock_qty')
            .eq('id', variantId)
            .single();
        final currentVarStock = _asInt(varRes['stock_qty']);
        await SupabaseService.from('product_variants')
            .update({'stock_qty': (currentVarStock - qty).clamp(0, 999999)})
            .eq('id', variantId);
      }
      final prodRes = await SupabaseService.from('products')
          .select('stock_total')
          .eq('id', productId)
          .single();
      final currentProdStock = _asInt(prodRes['stock_total']);
      await SupabaseService.from('products')
          .update({'stock_total': (currentProdStock - qty).clamp(0, 999999)})
          .eq('id', productId);

      return CheckoutResult(
        orderIds: [orderId],
        orderCodes: [order['order_code'] as String],
        totalAmount: _asDouble(order['total_amount']),
        currency: currency,
      );
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

  Future<Map<String, dynamic>> _fetchCurrentCart(String userId) async {
    final response = await SupabaseService.from('carts')
        .select(_cartSelect)
        .eq('user_id', userId)
        .limit(1);
    final rows = (response as List).whereType<Map<String, dynamic>>().toList();
    if (rows.isEmpty) {
      throw const ServerException('Cart is empty');
    }
    return rows.first;
  }

  List<_CheckoutItem> _parseItems(dynamic value) {
    if (value is! List) return const [];
    return value
        .whereType<Map<String, dynamic>>()
        .map(_CheckoutItem.fromJson)
        .toList(growable: false);
  }

  String _buildOrderCode(int index) {
    final micros = DateTime.now().microsecondsSinceEpoch;
    return 'SC$micros$index';
  }

  double _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}

class _CheckoutItem {
  final String productId;
  final String? variantId;
  final String shopId;
  final String title;
  final String? variantName;
  final String currency;
  final int qty;
  final double unitPrice;

  const _CheckoutItem({
    required this.productId,
    this.variantId,
    required this.shopId,
    required this.title,
    this.variantName,
    required this.currency,
    required this.qty,
    required this.unitPrice,
  });

  double get lineTotal => qty * unitPrice;

  factory _CheckoutItem.fromJson(Map<String, dynamic> json) {
    final product = json['products'];
    final variant = json['product_variants'];
    if (product is! Map<String, dynamic>) {
      throw const ServerException('Product is unavailable');
    }

    final rawVariantName =
        variant is Map<String, dynamic> ? variant['variant_name'] : null;
    final rawVariantSku =
        variant is Map<String, dynamic> ? variant['sku'] : null;
    final shopId = (product['shop_id'] as String?) ?? '';
    final qty = _asInt(json['qty']);
    final stockQty = variant is Map<String, dynamic>
        ? _asInt(variant['stock_qty'])
        : _asInt(product['stock_total']);
    final productStatus = product['status'] as String?;
    final itemStatus = variant is Map<String, dynamic>
        ? variant['status'] as String?
        : productStatus;

    if (productStatus != 'active' || itemStatus != 'active') {
      throw const ServerException('A cart item is unavailable');
    }
    if (shopId.isEmpty) {
      throw const ServerException('A cart item has no shop');
    }
    if (qty <= 0 || qty > stockQty) {
      throw const ServerException('A cart item exceeds available stock');
    }

    return _CheckoutItem(
      productId: json['product_id'] as String,
      variantId: json['variant_id'] as String?,
      shopId: shopId,
      title: (product['title'] as String?) ?? 'Product',
      variantName: variant is Map<String, dynamic>
          ? (rawVariantName as String?) ?? (rawVariantSku as String?)
          : null,
      currency: (product['currency'] as String?) ?? 'VND',
      qty: qty,
      unitPrice: variant is Map<String, dynamic>
          ? _asDouble(variant['price'])
          : _asDouble(product['price_min']),
    );
  }

  static double _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  static int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}
