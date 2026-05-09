import 'package:supabase_flutter/supabase_flutter.dart' hide AuthException;

import '../../../../../core/errors/exception.dart';
import '../../../../../core/services/supabase/index.dart';
import '../models/cart_model.dart';

abstract class CartRemoteDataSource {
  Future<CartModel> getCart();

  Future<CartModel> addToCart({
    required String productId,
    String? variantId,
    int qty = 1,
  });

  Future<CartModel> updateCartItemQty({
    required String itemId,
    required int qty,
  });

  Future<CartModel> removeCartItem(String itemId);
}

class CartRemoteDataSourceImpl implements CartRemoteDataSource {
  static const _cartSelect =
      'id,user_id,updated_at,cart_items(id,cart_id,product_id,variant_id,qty,unit_price,created_at,'
      'products(id,shop_id,title,cover_path,currency,stock_total,shops(shop_name)),'
      'product_variants(id,sku,variant_name,price,stock_qty,status))';

  @override
  Future<CartModel> getCart() async {
    final cart = await _getOrCreateCart();
    return _fetchCart(cart.id);
  }

  @override
  Future<CartModel> addToCart({
    required String productId,
    String? variantId,
    int qty = 1,
  }) async {
    if (qty <= 0) {
      throw const ServerException('Quantity must be greater than zero');
    }

    final cart = await _getOrCreateCart();
    final priceInfo = await _resolvePriceAndStock(
      productId: productId,
      variantId: variantId,
    );

    final existingItems = await SupabaseService.from('cart_items')
        .select('id,variant_id,qty')
        .eq('cart_id', cart.id)
        .eq('product_id', productId);

    Map<String, dynamic>? existing;
    for (final item in (existingItems as List).whereType<Map<String, dynamic>>()) {
      if (item['variant_id'] == variantId) {
        existing = item;
        break;
      }
    }

    final currentQty = existing == null ? 0 : existing['qty'] as int? ?? 0;
    final nextQty = currentQty + qty;
    if (nextQty > priceInfo.stockQty) {
      throw ServerException('Only ${priceInfo.stockQty} item(s) available');
    }

    if (existing == null) {
      await SupabaseService.from('cart_items').insert({
        'cart_id': cart.id,
        'product_id': productId,
        'variant_id': variantId,
        'qty': qty,
        'unit_price': priceInfo.unitPrice,
      });
    } else {
      await SupabaseService.from('cart_items')
          .update({
            'qty': nextQty,
            'unit_price': priceInfo.unitPrice,
          })
          .eq('id', existing['id'] as String);
    }

    return _fetchCart(cart.id);
  }

  @override
  Future<CartModel> updateCartItemQty({
    required String itemId,
    required int qty,
  }) async {
    final cart = await _getOrCreateCart();

    if (qty <= 0) {
      await SupabaseService.from('cart_items').delete().eq('id', itemId);
      return _fetchCart(cart.id);
    }

    final item = await SupabaseService.from('cart_items')
        .select('product_id,variant_id')
        .eq('id', itemId)
        .single();
    final priceInfo = await _resolvePriceAndStock(
      productId: item['product_id'] as String,
      variantId: item['variant_id'] as String?,
    );

    if (qty > priceInfo.stockQty) {
      throw ServerException('Only ${priceInfo.stockQty} item(s) available');
    }

    await SupabaseService.from('cart_items')
        .update({
          'qty': qty,
          'unit_price': priceInfo.unitPrice,
        })
        .eq('id', itemId);

    return _fetchCart(cart.id);
  }

  @override
  Future<CartModel> removeCartItem(String itemId) async {
    final cart = await _getOrCreateCart();
    await SupabaseService.from('cart_items').delete().eq('id', itemId);
    return _fetchCart(cart.id);
  }

  Future<_CartRef> _getOrCreateCart() async {
    final userId = SupabaseService.auth.currentUser?.id;
    if (userId == null) {
      throw const AuthException('Please sign in to use cart');
    }

    final existing = await SupabaseService.from('carts')
        .select('id,user_id')
        .eq('user_id', userId)
        .limit(1);
    final rows = (existing as List).whereType<Map<String, dynamic>>().toList();
    if (rows.isNotEmpty) {
      return _CartRef(
        id: rows.first['id'] as String,
        userId: rows.first['user_id'] as String,
      );
    }

    final created = await SupabaseService.from('carts')
        .insert({'user_id': userId})
        .select('id,user_id')
        .single();

    return _CartRef(
      id: created['id'] as String,
      userId: created['user_id'] as String,
    );
  }

  Future<CartModel> _fetchCart(String cartId) async {
    try {
      final response = await SupabaseService.from('carts')
          .select(_cartSelect)
          .eq('id', cartId)
          .single();
      return CartModel.fromJson(response);
    } on PostgrestException catch (e) {
      throw ServerException(e.message);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  Future<_PriceInfo> _resolvePriceAndStock({
    required String productId,
    String? variantId,
  }) async {
    if (variantId != null) {
      final variant = await SupabaseService.from('product_variants')
          .select('product_id,price,stock_qty,status')
          .eq('id', variantId)
          .single();

      if (variant['product_id'] != productId) {
        throw const ServerException('Selected variant does not match product');
      }
      if (variant['status'] != 'active') {
        throw const ServerException('Selected variant is unavailable');
      }

      return _PriceInfo(
        unitPrice: _asDouble(variant['price']),
        stockQty: variant['stock_qty'] as int? ?? 0,
      );
    }

    final product = await SupabaseService.from('products')
        .select('price_min,stock_total,status')
        .eq('id', productId)
        .single();

    if (product['status'] != 'active') {
      throw const ServerException('Product is unavailable');
    }

    return _PriceInfo(
      unitPrice: _asDouble(product['price_min']),
      stockQty: product['stock_total'] as int? ?? 0,
    );
  }

  double _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
}

class _CartRef {
  final String id;
  final String userId;

  const _CartRef({
    required this.id,
    required this.userId,
  });
}

class _PriceInfo {
  final double unitPrice;
  final int stockQty;

  const _PriceInfo({
    required this.unitPrice,
    required this.stockQty,
  });
}
