import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../../core/errors/exception.dart';
import '../../../../../core/services/supabase/index.dart';
import '../../../order/data/models/ecommerce_order_model.dart';
import '../../../product/data/models/product_model.dart';
import '../models/shop_model.dart';

abstract class ShopRemoteDataSource {
  Future<ShopModel> getShopDetail(String shopId);

  Future<List<ProductModel>> getShopProducts({
    required String shopId,
    int limit = 20,
    String? search,
  });

  Future<List<ShopModel>> getMyShops();

  Future<ShopModel> registerShop({
    required String shopName,
    required String shopSlug,
    required String description,
    String? logoUrl,
    String? coverUrl,
    String? contactPhone,
    String? contactEmail,
    String businessType = 'individual',
    String? pickupProvince,
    String? pickupDistrict,
    String? pickupWard,
    String? pickupAddress,
    String defaultCarrier = 'SPX Express',
  });

  Future<ShopModel> updateShopSettings({
    required String shopId,
    required String shopName,
    required String description,
    String? logoUrl,
    String? coverUrl,
    String? contactPhone,
    String? contactEmail,
    String? businessType,
    String? pickupProvince,
    String? pickupDistrict,
    String? pickupWard,
    String? pickupAddress,
    String? defaultCarrier,
    String? status,
  });

  Future<List<EcommerceOrderModel>> getShopOrders({
    required String shopId,
    String? status,
  });

  Future<void> confirmAndPackOrder({
    required String orderId,
    String? note,
  });

  Future<String> handoverToCarrier({
    required String orderId,
    required String carrier,
    String? trackingCode,
    String? pickupHub,
  });

  Future<void> advanceOrderLocation({
    required String orderId,
    required String stepStatus,
    required String title,
    required String location,
    String? description,
  });

  Future<void> sellerCancelOrder({
    required String orderId,
    required String reason,
  });

  Future<List<ProductModel>> getSellerCatalog(String shopId);

  Future<List<Map<String, dynamic>>> getProductCategories();

  Future<Map<String, dynamic>> createProductCategory(String name);

  Future<ProductModel> upsertSellerProduct({
    String? productId,
    required String shopId,
    required String categoryId,
    required String title,
    String? description,
    String? brand,
    required double price,
    double? originalPrice,
    required int stock,
    String status = 'active',
    String? coverPath,
    List<Map<String, dynamic>> variants = const [],
  });

  Future<void> toggleSellerProductStatus({
    required String productId,
    required String status,
  });
}

class ShopRemoteDataSourceImpl implements ShopRemoteDataSource {
  static const _productSelect =
      'id,shop_id,category_id,title,description,brand,status,price_min,price_max,'
      'original_price,currency,stock_total,sold_count,rating_avg,rating_count,cover_path,'
      'created_at,updated_at,shops(shop_name),'
      'product_media(id,product_id,media_type,storage_path,sort_order,created_at),'
      'product_variants(id,product_id,sku,variant_name,price,compare_at_price,'
      'stock_qty,weight_grams,status,created_at)';

  static const _orderSelectWithTracking =
      'id,buyer_id,shop_id,order_code,status,subtotal_amount,discount_amount,'
      'shipping_amount,total_amount,currency,address_snapshot,note,placed_at,updated_at,'
      'shipping_carrier,shipping_service,tracking_code,current_location,pickup_location,'
      'estimated_delivery_at,confirmed_at,shipped_at,delivered_at,cancel_reason,'
      'shops(shop_name,owner_id,pickup_province,pickup_district,pickup_ward),'
      'order_items(id,order_id,product_id,variant_id,shop_id,title_snapshot,'
      'variant_snapshot,unit_price,qty,line_total,products(cover_path)),'
      'order_tracking_events(id,order_id,status,title,description,location,carrier_name,lat,lng,actor_role,created_at)';

  static const _legacyOrderSelect =
      'id,buyer_id,shop_id,order_code,status,subtotal_amount,discount_amount,'
      'shipping_amount,total_amount,currency,address_snapshot,note,placed_at,updated_at,'
      'shops(shop_name,owner_id),'
      'order_items(id,order_id,product_id,variant_id,shop_id,title_snapshot,'
      'variant_snapshot,unit_price,qty,line_total,products(cover_path))';

  String _requireUserId() {
    final userId = SupabaseService.currentUserId;
    if (userId == null) {
      throw const ServerException('Vui lòng đăng nhập để tiếp tục');
    }
    return userId;
  }

  static bool _isSchemaMismatch(PostgrestException e) {
    final code = e.code ?? '';
    return code == '42703' ||
        code == '42P01' ||
        code == 'PGRST204' ||
        code == 'PGRST200' ||
        code == 'PGRST202';
  }

  static String _randomSuffix() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final rand = Random();
    return List.generate(4, (_) => chars[rand.nextInt(chars.length)]).join();
  }

  static String _slugify(String raw) {
    var s = raw.toLowerCase().trim();
    const vietnamese =
        'aáàảãạăắằẳẵặâấầẩẫậeéèẻẽẹêếềểễệiíìỉĩịoóòỏõọôốồổỗộơớờởỡợuúùủũụưứừửữựyýỳỷỹỵdđ';
    const latin =
        'aaaaaaaaaaaaaaaaaeeeeeeeeeeeeiiiiiiioooooooooooooooooouuuuuuuuuuuuyyyyyydd';
    for (int i = 0; i < vietnamese.length; i++) {
      s = s.replaceAll(vietnamese[i], latin[i]);
    }
    return s
        .replaceAll(RegExp(r'[^a-z0-9\s-]'), '')
        .replaceAll(RegExp(r'\s+'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
  }

  @override
  Future<ShopModel> getShopDetail(String shopId) async {
    try {
      final response = await SupabaseService.from('shops')
          .select()
          .eq('id', shopId)
          .single();

      return ShopModel.fromJson(response);
    } on PostgrestException catch (e) {
      if (e.code == 'PGRST116') {
        throw const NotFoundException('Shop not found');
      }
      throw ServerException(e.message);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  static String _extractBrandKeyword(String rawName) {
    final cleaned = rawName
        .replaceAll(
          RegExp(
            r'\b(official|flagship|store|shop|mall|vn|vietnam|cửa hàng|cua hang)\b',
            caseSensitive: false,
          ),
          '',
        )
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return cleaned.isEmpty ? rawName.trim() : cleaned;
  }

  @override
  Future<List<ProductModel>> getShopProducts({
    required String shopId,
    int limit = 20,
    String? search,
  }) async {
    try {
      String? shopName;
      try {
        final shopRow = await SupabaseService.from('shops')
            .select('shop_name')
            .eq('id', shopId)
            .maybeSingle();
        shopName = (shopRow?['shop_name'] as String?)?.trim();
      } catch (_) {}

      dynamic query = SupabaseService.from('products')
          .select(_productSelect)
          .eq('status', 'active');

      if (shopName != null && shopName.isNotEmpty) {
        final brandKeyword = _extractBrandKeyword(shopName);
        if (brandKeyword.toLowerCase() != shopName.toLowerCase() &&
            brandKeyword.isNotEmpty) {
          query = query.or(
            'shop_id.eq.$shopId,brand.ilike.%$shopName%,brand.ilike.%$brandKeyword%',
          );
        } else {
          query = query.or(
            'shop_id.eq.$shopId,brand.ilike.%$shopName%',
          );
        }
      } else {
        query = query.eq('shop_id', shopId);
      }

      final keyword = search?.trim();
      if (keyword != null && keyword.isNotEmpty) {
        query = query.ilike('title', '%$keyword%');
      }

      final response = await query
          .order('created_at', ascending: false)
          .limit(limit);

      return (response as List)
          .whereType<Map<String, dynamic>>()
          .map(ProductModel.fromJson)
          .toList(growable: false);
    } on PostgrestException catch (e) {
      throw ServerException(e.message);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<List<ShopModel>> getMyShops() async {
    try {
      final userId = _requireUserId();
      final response = await SupabaseService.from('shops')
          .select()
          .eq('owner_id', userId)
          .order('created_at', ascending: true);

      return (response as List)
          .whereType<Map<String, dynamic>>()
          .map(ShopModel.fromJson)
          .toList(growable: false);
    } on PostgrestException catch (e) {
      throw ServerException(e.message);
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException(e.toString());
    }
  }

  @override
  Future<ShopModel> registerShop({
    required String shopName,
    required String shopSlug,
    required String description,
    String? logoUrl,
    String? coverUrl,
    String? contactPhone,
    String? contactEmail,
    String businessType = 'individual',
    String? pickupProvince,
    String? pickupDistrict,
    String? pickupWard,
    String? pickupAddress,
    String defaultCarrier = 'SPX Express',
  }) async {
    final userId = _requireUserId();
    var finalSlug = _slugify(shopSlug.trim().isEmpty ? shopName : shopSlug);
    if (finalSlug.isEmpty) {
      finalSlug = 'shop-${_randomSuffix()}';
    }

    Map<String, dynamic> buildPayload(String slug, bool includeExtended) {
      final map = <String, dynamic>{
        'owner_id': userId,
        'shop_name': shopName.trim(),
        'shop_slug': slug,
        'description': description.trim(),
        if (logoUrl != null && logoUrl.isNotEmpty) 'logo_path': logoUrl,
        if (coverUrl != null && coverUrl.isNotEmpty) 'cover_path': coverUrl,
        'status': 'pending',
      };
      if (includeExtended) {
        map.addAll({
          if (contactPhone != null && contactPhone.trim().isNotEmpty)
            'contact_phone': contactPhone.trim(),
          if (contactEmail != null && contactEmail.trim().isNotEmpty)
            'contact_email': contactEmail.trim(),
          'business_type': businessType,
          if (pickupProvince != null && pickupProvince.trim().isNotEmpty)
            'pickup_province': pickupProvince.trim(),
          if (pickupDistrict != null && pickupDistrict.trim().isNotEmpty)
            'pickup_district': pickupDistrict.trim(),
          if (pickupWard != null && pickupWard.trim().isNotEmpty)
            'pickup_ward': pickupWard.trim(),
          if (pickupAddress != null && pickupAddress.trim().isNotEmpty)
            'pickup_address': pickupAddress.trim(),
          'default_carrier': defaultCarrier,
        });
      }
      return map;
    }

    try {
      try {
        final row = await SupabaseService.from('shops')
            .insert(buildPayload(finalSlug, true))
            .select()
            .single();
        return ShopModel.fromJson(row);
      } on PostgrestException catch (e) {
        if (_isSchemaMismatch(e)) {
          final row = await SupabaseService.from('shops')
              .insert(buildPayload(finalSlug, false))
              .select()
              .single();
          return ShopModel.fromJson(row);
        }
        if (e.code == '23505') {
          if (e.message.contains('owner_id')) {
            throw const ServerException(
              'Tài khoản này đã có cửa hàng (hãy chạy file SQL migration để mở khóa tính năng nhiều shop).',
            );
          }
          // Slug collision: retry once with random suffix
          final retrySlug = '$finalSlug-${_randomSuffix()}';
          final row = await SupabaseService.from('shops')
              .insert(buildPayload(retrySlug, true))
              .select()
              .single();
          return ShopModel.fromJson(row);
        }
        rethrow;
      }
    } on PostgrestException catch (e) {
      throw ServerException(e.message);
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException(e.toString());
    }
  }

  @override
  Future<ShopModel> updateShopSettings({
    required String shopId,
    required String shopName,
    required String description,
    String? logoUrl,
    String? coverUrl,
    String? contactPhone,
    String? contactEmail,
    String? businessType,
    String? pickupProvince,
    String? pickupDistrict,
    String? pickupWard,
    String? pickupAddress,
    String? defaultCarrier,
    String? status,
  }) async {
    _requireUserId();
    final basePayload = <String, dynamic>{
      'shop_name': shopName.trim(),
      'description': description.trim(),
      if (logoUrl != null && logoUrl.isNotEmpty) 'logo_path': logoUrl,
      if (coverUrl != null && coverUrl.isNotEmpty) 'cover_path': coverUrl,
      if (status != null) 'status': status,
    };
    final fullPayload = <String, dynamic>{
      ...basePayload,
      'contact_phone': contactPhone?.trim(),
      'contact_email': contactEmail?.trim(),
      if (businessType != null) 'business_type': businessType,
      'pickup_province': pickupProvince?.trim(),
      'pickup_district': pickupDistrict?.trim(),
      'pickup_ward': pickupWard?.trim(),
      'pickup_address': pickupAddress?.trim(),
      if (defaultCarrier != null) 'default_carrier': defaultCarrier,
    };

    try {
      try {
        final row = await SupabaseService.from('shops')
            .update(fullPayload)
            .eq('id', shopId)
            .select()
            .single();
        return ShopModel.fromJson(row);
      } on PostgrestException catch (e) {
        if (_isSchemaMismatch(e)) {
          final row = await SupabaseService.from('shops')
              .update(basePayload)
              .eq('id', shopId)
              .select()
              .single();
          return ShopModel.fromJson(row);
        }
        rethrow;
      }
    } on PostgrestException catch (e) {
      throw ServerException(e.message);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<List<EcommerceOrderModel>> getShopOrders({
    required String shopId,
    String? status,
  }) async {
    _requireUserId();
    try {
      Future<List<dynamic>> runQuery(String selectClause) async {
        dynamic query = SupabaseService.from('orders')
            .select(selectClause)
            .eq('shop_id', shopId);
        if (status != null && status.isNotEmpty) {
          query = query.eq('status', status);
        }
        return await query.order('placed_at', ascending: false);
      }

      List<dynamic> response;
      try {
        response = await runQuery(_orderSelectWithTracking);
      } on PostgrestException catch (e) {
        if (_isSchemaMismatch(e)) {
          response = await runQuery(_legacyOrderSelect);
        } else {
          rethrow;
        }
      }

      return response
          .whereType<Map<String, dynamic>>()
          .map(EcommerceOrderModel.fromJson)
          .toList(growable: false);
    } on PostgrestException catch (e) {
      throw ServerException(e.message);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<void> confirmAndPackOrder({
    required String orderId,
    String? note,
  }) async {
    _requireUserId();
    try {
      try {
        await SupabaseService.client.rpc(
          'seller_confirm_pack_order',
          params: {
            'p_order_id': orderId,
            if (note != null && note.trim().isNotEmpty) 'p_note': note.trim(),
          },
        );
      } on PostgrestException catch (e) {
        if (_isSchemaMismatch(e)) {
          await SupabaseService.from('orders').update({
            'status': 'packed',
            'updated_at': DateTime.now().toIso8601String(),
          }).eq('id', orderId);
        } else {
          rethrow;
        }
      }
    } on PostgrestException catch (e) {
      throw ServerException(e.message);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<String> handoverToCarrier({
    required String orderId,
    required String carrier,
    String? trackingCode,
    String? pickupHub,
  }) async {
    final userId = _requireUserId();
    final cleanCarrier = carrier.trim().isEmpty ? 'SPX Express' : carrier.trim();
    try {
      try {
        final res = await SupabaseService.client.rpc(
          'seller_handover_to_carrier',
          params: {
            'p_order_id': orderId,
            'p_carrier': cleanCarrier,
            if (trackingCode != null && trackingCode.trim().isNotEmpty)
              'p_tracking_code': trackingCode.trim(),
            if (pickupHub != null && pickupHub.trim().isNotEmpty)
              'p_pickup_hub': pickupHub.trim(),
          },
        );
        return res?.toString() ?? (trackingCode?.trim() ?? '');
      } on PostgrestException catch (e) {
        if (_isSchemaMismatch(e)) {
          final generatedCode = (trackingCode != null && trackingCode.trim().isNotEmpty)
              ? trackingCode.trim()
              : 'SHC${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';
          try {
            await SupabaseService.from('orders').update({
              'status': 'shipping',
              'shipping_carrier': cleanCarrier,
              'tracking_code': generatedCode,
              if (pickupHub != null && pickupHub.trim().isNotEmpty)
                'current_location': pickupHub.trim(),
              'updated_at': DateTime.now().toIso8601String(),
            }).eq('id', orderId);
            await SupabaseService.from('order_tracking_events').insert({
              'order_id': orderId,
              'status': 'picked_up',
              'title': 'Đơn vị vận chuyển đã lấy hàng thành công',
              'location': pickupHub?.trim() ?? 'Bưu cục gửi hàng',
              'carrier_name': cleanCarrier,
              'actor_role': 'carrier',
              'created_by': userId,
            });
          } catch (_) {
            await SupabaseService.from('orders').update({
              'status': 'shipping',
              'updated_at': DateTime.now().toIso8601String(),
            }).eq('id', orderId);
          }
          return generatedCode;
        }
        rethrow;
      }
    } on PostgrestException catch (e) {
      throw ServerException(e.message);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<void> advanceOrderLocation({
    required String orderId,
    required String stepStatus,
    required String title,
    required String location,
    String? description,
  }) async {
    final userId = _requireUserId();
    try {
      try {
        await SupabaseService.client.rpc(
          'advance_order_location',
          params: {
            'p_order_id': orderId,
            'p_step_status': stepStatus,
            'p_title': title.trim(),
            'p_location': location.trim(),
            if (description != null && description.trim().isNotEmpty)
              'p_description': description.trim(),
          },
        );
      } on PostgrestException catch (e) {
        if (_isSchemaMismatch(e)) {
          final nextStatus = stepStatus == 'completed' ? 'completed' : 'shipping';
          try {
            await SupabaseService.from('orders').update({
              'status': nextStatus,
              'current_location': location.trim(),
              'updated_at': DateTime.now().toIso8601String(),
            }).eq('id', orderId);
            await SupabaseService.from('order_tracking_events').insert({
              'order_id': orderId,
              'status': stepStatus,
              'title': title.trim(),
              'location': location.trim(),
              'description': description?.trim(),
              'actor_role': 'carrier',
              'created_by': userId,
            });
          } catch (_) {
            await SupabaseService.from('orders').update({
              'status': nextStatus,
              'updated_at': DateTime.now().toIso8601String(),
            }).eq('id', orderId);
          }
        } else {
          rethrow;
        }
      }
    } on PostgrestException catch (e) {
      throw ServerException(e.message);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<void> sellerCancelOrder({
    required String orderId,
    required String reason,
  }) async {
    _requireUserId();
    final cleanReason =
        reason.trim().isEmpty ? 'Người bán hủy đơn hàng' : reason.trim();
    try {
      try {
        await SupabaseService.client.rpc(
          'cancel_order',
          params: {
            'p_order_id': orderId,
            'p_reason': cleanReason,
          },
        );
      } on PostgrestException catch (e) {
        if (_isSchemaMismatch(e)) {
          await SupabaseService.from('orders').update({
            'status': 'cancelled',
            'updated_at': DateTime.now().toIso8601String(),
          }).eq('id', orderId);
        } else {
          rethrow;
        }
      }
    } on PostgrestException catch (e) {
      throw ServerException(e.message);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<List<ProductModel>> getSellerCatalog(String shopId) async {
    _requireUserId();
    try {
      final response = await SupabaseService.from('products')
          .select(_productSelect)
          .eq('shop_id', shopId)
          .neq('status', 'deleted')
          .order('created_at', ascending: false);

      return (response as List)
          .whereType<Map<String, dynamic>>()
          .map(ProductModel.fromJson)
          .toList(growable: false);
    } on PostgrestException catch (e) {
      if (_isSchemaMismatch(e)) {
        const legacySelect =
            'id,shop_id,category_id,title,description,brand,status,price_min,price_max,'
            'currency,stock_total,sold_count,rating_avg,rating_count,cover_path,'
            'created_at,updated_at,shops(shop_name),'
            'product_media(id,product_id,media_type,storage_path,sort_order,created_at),'
            'product_variants(id,product_id,sku,variant_name,price,compare_at_price,'
            'stock_qty,weight_grams,status,created_at)';
        final response = await SupabaseService.from('products')
            .select(legacySelect)
            .eq('shop_id', shopId)
            .neq('status', 'deleted')
            .order('created_at', ascending: false);
        return (response as List)
            .whereType<Map<String, dynamic>>()
            .map(ProductModel.fromJson)
            .toList(growable: false);
      }
      throw ServerException(e.message);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getProductCategories() async {
    try {
      final response = await SupabaseService.from('product_categories')
          .select('id, name, slug')
          .order('name', ascending: true);
      return List<Map<String, dynamic>>.from(response);
    } on PostgrestException catch (e) {
      throw ServerException(e.message);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<Map<String, dynamic>> createProductCategory(String name) async {
    _requireUserId();
    final cleanName = name.trim();
    var slug = _slugify(cleanName);
    if (slug.isEmpty) slug = 'cat-${_randomSuffix()}';

    try {
      final response = await SupabaseService.from('product_categories')
          .insert({'name': cleanName, 'slug': slug})
          .select('id, name, slug')
          .single();
      return Map<String, dynamic>.from(response);
    } on PostgrestException catch (e) {
      if (e.code == '23505') {
        final retry = await SupabaseService.from('product_categories')
            .insert({'name': cleanName, 'slug': '$slug-${_randomSuffix()}'})
            .select('id, name, slug')
            .single();
        return Map<String, dynamic>.from(retry);
      }
      throw ServerException(e.message);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<ProductModel> upsertSellerProduct({
    String? productId,
    required String shopId,
    required String categoryId,
    required String title,
    String? description,
    String? brand,
    required double price,
    double? originalPrice,
    required int stock,
    String status = 'active',
    String? coverPath,
    List<Map<String, dynamic>> variants = const [],
  }) async {
    _requireUserId();
    try {
      final validVariants = variants
          .where((v) => (v['variant_name']?.toString().trim() ?? '').isNotEmpty)
          .toList();

      double priceMin = price;
      double priceMax = price;
      int totalStock = stock;

      if (validVariants.isNotEmpty) {
        final prices = validVariants
            .map((v) => (v['price'] as num?)?.toDouble() ?? price)
            .toList();
        priceMin = prices.reduce(min);
        priceMax = prices.reduce(max);
        totalStock = validVariants.fold<int>(
          0,
          (sum, v) => sum + ((v['stock_qty'] as num?)?.toInt() ?? 0),
        );
      }

      String? cleanBrand = brand?.trim();
      if (cleanBrand == null || cleanBrand.isEmpty) {
        try {
          final shopRow = await SupabaseService.from('shops')
              .select('shop_name')
              .eq('id', shopId)
              .maybeSingle();
          cleanBrand = (shopRow?['shop_name'] as String?)?.trim();
        } catch (_) {}
      }

      final payload = <String, dynamic>{
        'shop_id': shopId,
        'category_id': categoryId,
        'title': title.trim(),
        'description': description?.trim(),
        if (cleanBrand != null && cleanBrand.isNotEmpty) 'brand': cleanBrand,
        'status': status,
        'price_min': priceMin,
        'price_max': priceMax,
        if (originalPrice != null) 'original_price': originalPrice,
        'currency': 'VND',
        'stock_total': totalStock,
        if (coverPath != null && coverPath.trim().isNotEmpty)
          'cover_path': coverPath.trim(),
      };

      String savedProductId;
      if (productId == null) {
        Map<String, dynamic> inserted;
        try {
          inserted = await SupabaseService.from('products')
              .insert(payload)
              .select('id')
              .single();
        } on PostgrestException catch (e) {
          if (_isSchemaMismatch(e)) {
            payload.remove('original_price');
            inserted = await SupabaseService.from('products')
                .insert(payload)
                .select('id')
                .single();
          } else {
            rethrow;
          }
        }
        savedProductId = inserted['id'] as String;
      } else {
        try {
          await SupabaseService.from('products')
              .update({
                ...payload,
                if (originalPrice == null) 'original_price': null,
              })
              .eq('id', productId);
        } on PostgrestException catch (e) {
          if (_isSchemaMismatch(e)) {
            payload.remove('original_price');
            await SupabaseService.from('products')
                .update(payload)
                .eq('id', productId);
          } else {
            rethrow;
          }
        }
        savedProductId = productId;
      }

      // Sync variants
      if (validVariants.isNotEmpty) {
        if (productId != null) {
          await SupabaseService.from('product_variants')
              .delete()
              .eq('product_id', savedProductId);
        }
        final skuPrefix = savedProductId.split('-').first.toUpperCase();
        final variantRows = <Map<String, dynamic>>[];
        for (int i = 0; i < validVariants.length; i++) {
          final v = validVariants[i];
          final rawSku = (v['sku']?.toString().trim() ?? '');
          final variantName = v['variant_name'].toString().trim();
          final variantPrice = (v['price'] as num?)?.toDouble() ?? price;
          final variantStock = (v['stock_qty'] as num?)?.toInt() ?? 0;
          variantRows.add({
            'product_id': savedProductId,
            'sku': rawSku.isNotEmpty
                ? rawSku
                : 'SKU-$skuPrefix-${i + 1}-${_randomSuffix().toUpperCase()}',
            'variant_name': variantName,
            'price': variantPrice,
            if (originalPrice != null) 'compare_at_price': originalPrice,
            'stock_qty': variantStock,
            'weight_grams': 250,
            'status': 'active',
          });
        }
        await SupabaseService.from('product_variants').insert(variantRows);
      } else {
        // Maintain at least one default variant
        final existingDefaults = productId != null
            ? await SupabaseService.from('product_variants')
                .select('id')
                .eq('product_id', savedProductId)
                .limit(1)
            : const [];
        if (existingDefaults.isNotEmpty) {
          await SupabaseService.from('product_variants')
              .update({
                'variant_name': 'Tiêu chuẩn',
                'price': price,
                if (originalPrice != null) 'compare_at_price': originalPrice,
                'stock_qty': stock,
                'status': 'active',
              })
              .eq('id', existingDefaults.first['id'] as String);
        } else {
          final skuPrefix = savedProductId.split('-').first.toUpperCase();
          await SupabaseService.from('product_variants').insert({
            'product_id': savedProductId,
            'sku': 'SKU-$skuPrefix-STD-${_randomSuffix().toUpperCase()}',
            'variant_name': 'Tiêu chuẩn',
            'price': price,
            if (originalPrice != null) 'compare_at_price': originalPrice,
            'stock_qty': stock,
            'weight_grams': 250,
            'status': 'active',
          });
        }
      }

      // Sync cover to product_media if provided
      if (coverPath != null && coverPath.trim().isNotEmpty) {
        try {
          final existingMedia = await SupabaseService.from('product_media')
              .select('id')
              .eq('product_id', savedProductId)
              .limit(1);
          if (existingMedia.isEmpty) {
            await SupabaseService.from('product_media').insert({
              'product_id': savedProductId,
              'media_type': 'image',
              'storage_path': coverPath.trim(),
              'sort_order': 0,
            });
          }
        } catch (_) {}
      }

      final updated = await SupabaseService.from('products')
          .select(_productSelect)
          .eq('id', savedProductId)
          .single();
      return ProductModel.fromJson(updated);
    } on PostgrestException catch (e) {
      throw ServerException(e.message);
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException(e.toString());
    }
  }

  @override
  Future<void> toggleSellerProductStatus({
    required String productId,
    required String status,
  }) async {
    _requireUserId();
    try {
      await SupabaseService.from('products')
          .update({'status': status})
          .eq('id', productId);
    } on PostgrestException catch (e) {
      throw ServerException(e.message);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }
}
