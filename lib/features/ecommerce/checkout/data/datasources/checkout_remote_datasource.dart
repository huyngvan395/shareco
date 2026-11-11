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
    double shippingAmount = 0.0,
    String shippingService = 'fast',
    String? shippingCarrier,
  });

  Future<CheckoutResult> placeDirectOrder({
    required CheckoutAddress address,
    required String productId,
    String? variantId,
    required int qty,
    String? note,
    double discountAmount = 0.0,
    double shippingAmount = 0.0,
    String shippingService = 'fast',
    String? shippingCarrier,
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
    double shippingAmount = 0.0,
    String shippingService = 'fast',
    String? shippingCarrier,
  }) async {
    final userId = SupabaseService.auth.currentUser?.id;
    if (userId == null) {
      throw const AuthException('Vui lòng đăng nhập để đặt hàng');
    }

    try {
      final cart = await _fetchCurrentCart(userId);
      final cartId = cart['id'] as String;
      final items = _parseItems(cart['cart_items']);
      if (items.isEmpty) {
        throw const ServerException('Giỏ hàng đang trống');
      }

      final groups = <String, List<_CheckoutItem>>{};
      for (final item in items) {
        groups.putIfAbsent(item.shopId, () => []).add(item);
      }

      final shopsById = await _fetchShopsMap(groups.keys.toList());
      for (final shopId in groups.keys) {
        final shop = shopsById[shopId];
        if (shop == null || (shop['status'] as String?) != 'active') {
          final name = shop?['shop_name']?.toString() ?? 'Cửa hàng';
          throw ServerException('$name hiện đang tạm ngưng bán hàng');
        }
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

      final paymentMethod = address.paymentMethod ?? 'cod';
      final isPrepaid = paymentMethod == 'card' || paymentMethod == 'qr';
      final initialStatus = isPrepaid ? 'paid' : 'pending';
      final estimatedDelivery = _estimateDelivery(shippingService);

      for (final entry in groups.entries) {
        index++;
        final groupItems = entry.value;
        final shopMeta = shopsById[entry.key];
        final subtotal = groupItems.fold<double>(
          0,
          (sum, item) => sum + item.lineTotal,
        );
        final orderCode = _buildOrderCode(index);
        currency = groupItems.first.currency;

        final ratio = totalSubtotal > 0
            ? (subtotal / totalSubtotal)
            : (1.0 / groups.length);
        final orderShipping = (shippingAmount * ratio).roundToDouble();
        final orderDiscount = (discountAmount * ratio).roundToDouble();
        final orderTotal =
            (subtotal + orderShipping - orderDiscount).clamp(0.0, double.infinity);

        final carrier = (shippingCarrier != null && shippingCarrier.trim().isNotEmpty)
            ? shippingCarrier.trim()
            : ((shopMeta?['default_carrier'] as String?) ?? 'SPX Express');
        final pickupLoc = _formatPickupLocation(shopMeta);

        final order = await _insertOrderRow(
          buyerId: userId,
          shopId: entry.key,
          orderCode: orderCode,
          status: initialStatus,
          subtotal: subtotal,
          discount: orderDiscount,
          shipping: orderShipping,
          total: orderTotal,
          currency: currency,
          address: address,
          note: note,
          shippingCarrier: carrier,
          shippingService: shippingService,
          pickupLocation: pickupLoc,
          estimatedDeliveryAt: estimatedDelivery,
        );

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

        await _finalizeOrderStockPaymentAndTracking(
          orderId: orderId,
          paymentMethod: paymentMethod,
          paymentStatus: isPrepaid ? 'paid' : 'pending',
          shippingService: shippingService,
          items: groupItems
              .map((e) => _StockAdjustItem(
                    productId: e.productId,
                    variantId: e.variantId,
                    qty: e.qty,
                  ))
              .toList(),
        );

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
    double shippingAmount = 0.0,
    String shippingService = 'fast',
    String? shippingCarrier,
  }) async {
    final userId = SupabaseService.auth.currentUser?.id;
    if (userId == null) {
      throw const AuthException('Vui lòng đăng nhập để đặt hàng');
    }

    try {
      final productResponse = await SupabaseService.from('products')
          .select(
              'id,shop_id,title,currency,price_min,stock_total,status,'
              'shops(id,shop_name,status,default_carrier,pickup_province,pickup_district,pickup_ward,pickup_address),'
              'product_variants(id,sku,variant_name,price,stock_qty,status)')
          .eq('id', productId)
          .single();

      final shopMeta = productResponse['shops'] as Map<String, dynamic>?;
      if (shopMeta != null && (shopMeta['status'] as String?) != 'active') {
        throw ServerException(
          '${shopMeta['shop_name'] ?? 'Cửa hàng'} hiện đang tạm ngưng bán hàng',
        );
      }

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
      final resolvedVariantId =
          variantId ?? (selectedVariant?['id'] as String?);

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
        throw const ServerException('Sản phẩm hiện không khả dụng');
      }
      if (qty <= 0 || qty > stockQty) {
        throw ServerException('Số lượng vượt quá tồn kho hiện có ($stockQty)');
      }

      final lineTotal = qty * unitPrice;
      final orderCode = _buildOrderCode(1);
      final orderTotal =
          (lineTotal + shippingAmount - discountAmount).clamp(0.0, double.infinity);

      final paymentMethod = address.paymentMethod ?? 'cod';
      final isPrepaid = paymentMethod == 'card' || paymentMethod == 'qr';
      final initialStatus = isPrepaid ? 'paid' : 'pending';
      final estimatedDelivery = _estimateDelivery(shippingService);
      final carrier = (shippingCarrier != null && shippingCarrier.trim().isNotEmpty)
          ? shippingCarrier.trim()
          : ((shopMeta?['default_carrier'] as String?) ?? 'SPX Express');
      final pickupLoc = _formatPickupLocation(shopMeta);

      final order = await _insertOrderRow(
        buyerId: userId,
        shopId: shopId,
        orderCode: orderCode,
        status: initialStatus,
        subtotal: lineTotal,
        discount: discountAmount,
        shipping: shippingAmount,
        total: orderTotal,
        currency: currency,
        address: address,
        note: note,
        shippingCarrier: carrier,
        shippingService: shippingService,
        pickupLocation: pickupLoc,
        estimatedDeliveryAt: estimatedDelivery,
      );

      final orderId = order['id'] as String;
      await SupabaseService.from('order_items').insert({
        'order_id': orderId,
        'product_id': productId,
        'variant_id': resolvedVariantId,
        'shop_id': shopId,
        'title_snapshot': title,
        'variant_snapshot': resolvedVariantName,
        'unit_price': unitPrice,
        'qty': qty,
        'line_total': lineTotal,
      });

      await _finalizeOrderStockPaymentAndTracking(
        orderId: orderId,
        paymentMethod: paymentMethod,
        paymentStatus: isPrepaid ? 'paid' : 'pending',
        shippingService: shippingService,
        items: [
          _StockAdjustItem(
            productId: productId,
            variantId: resolvedVariantId,
            qty: qty,
          ),
        ],
      );

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

  Future<Map<String, Map<String, dynamic>>> _fetchShopsMap(
    List<String> shopIds,
  ) async {
    if (shopIds.isEmpty) return const {};
    try {
      final rows = await SupabaseService.from('shops')
          .select(
              'id,shop_name,status,default_carrier,pickup_province,pickup_district,pickup_ward,pickup_address')
          .inFilter('id', shopIds);
      final map = <String, Map<String, dynamic>>{};
      for (final row in (rows as List).whereType<Map<String, dynamic>>()) {
        final id = row['id'] as String?;
        if (id != null) map[id] = row;
      }
      return map;
    } catch (_) {
      final rows = await SupabaseService.from('shops')
          .select('id,shop_name,status')
          .inFilter('id', shopIds);
      final map = <String, Map<String, dynamic>>{};
      for (final row in (rows as List).whereType<Map<String, dynamic>>()) {
        final id = row['id'] as String?;
        if (id != null) map[id] = row;
      }
      return map;
    }
  }

  Future<Map<String, dynamic>> _insertOrderRow({
    required String buyerId,
    required String shopId,
    required String orderCode,
    required String status,
    required double subtotal,
    required double discount,
    required double shipping,
    required double total,
    required String currency,
    required CheckoutAddress address,
    required String? note,
    required String shippingCarrier,
    required String shippingService,
    required String pickupLocation,
    required DateTime estimatedDeliveryAt,
  }) async {
    final basePayload = <String, dynamic>{
      'buyer_id': buyerId,
      'shop_id': shopId,
      'order_code': orderCode,
      'status': status,
      'subtotal_amount': subtotal,
      'discount_amount': discount,
      'shipping_amount': shipping,
      'total_amount': total,
      'currency': currency,
      'address_snapshot': address.toJson(),
      'note': note,
    };

    try {
      return await SupabaseService.from('orders')
          .insert({
            ...basePayload,
            'shipping_carrier': shippingCarrier,
            'shipping_service': shippingService,
            'pickup_location': pickupLocation,
            'current_location': 'Chờ người bán xác nhận • $pickupLocation',
            'estimated_delivery_at': estimatedDeliveryAt.toUtc().toIso8601String(),
          })
          .select('id,order_code,total_amount')
          .single();
    } on PostgrestException catch (e) {
      // Fallback if SQL migration columns do not exist yet
      if (e.code == '42703' || e.code == 'PGRST204') {
        return await SupabaseService.from('orders')
            .insert(basePayload)
            .select('id,order_code,total_amount')
            .single();
      }
      rethrow;
    }
  }

  Future<void> _finalizeOrderStockPaymentAndTracking({
    required String orderId,
    required String paymentMethod,
    required String paymentStatus,
    required String shippingService,
    required List<_StockAdjustItem> items,
  }) async {
    try {
      await SupabaseService.client.rpc(
        'deduct_order_stock_and_init_tracking',
        params: {
          'p_order_id': orderId,
          'p_payment_method': paymentMethod,
          'p_payment_status': paymentStatus,
          'p_shipping_service': shippingService,
        },
      );
      return;
    } catch (_) {
      // Fallback best-effort when RPC hasn't been installed yet
    }

    for (final item in items) {
      try {
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
            .select('stock_total,sold_count')
            .eq('id', item.productId)
            .single();
        final currentProdStock = _asInt(prodRes['stock_total']);
        final currentSoldCount = _asInt(prodRes['sold_count']);
        await SupabaseService.from('products')
            .update({
              'stock_total': (currentProdStock - item.qty).clamp(0, 999999),
              'sold_count': (currentSoldCount + item.qty).clamp(0, 999999999),
            })
            .eq('id', item.productId);
      } catch (_) {}
    }
  }

  DateTime _estimateDelivery(String service) {
    final now = DateTime.now();
    switch (service) {
      case 'express':
        return now.add(const Duration(days: 1));
      case 'standard':
        return now.add(const Duration(days: 5));
      case 'fast':
      default:
        return now.add(const Duration(days: 3));
    }
  }

  String _formatPickupLocation(Map<String, dynamic>? shopMeta) {
    if (shopMeta == null) return 'Kho người bán ShareCo';
    final parts = [
      shopMeta['pickup_ward']?.toString().trim(),
      shopMeta['pickup_district']?.toString().trim(),
      shopMeta['pickup_province']?.toString().trim(),
    ].whereType<String>().where((s) => s.isNotEmpty).toList();
    if (parts.isNotEmpty) return parts.join(', ');
    final addr = shopMeta['pickup_address']?.toString().trim();
    if (addr != null && addr.isNotEmpty) return addr;
    return 'Kho người bán ShareCo';
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

class _StockAdjustItem {
  final String productId;
  final String? variantId;
  final int qty;

  const _StockAdjustItem({
    required this.productId,
    this.variantId,
    required this.qty,
  });
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
