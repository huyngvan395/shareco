import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../../core/errors/exception.dart';
import '../../../../../core/services/supabase/index.dart';
import '../../../product/data/models/product_model.dart';
import '../models/shop_model.dart';

abstract class ShopRemoteDataSource {
  Future<ShopModel> getShopDetail(String shopId);

  Future<List<ProductModel>> getShopProducts({
    required String shopId,
    int limit = 20,
    String? search,
  });
}

class ShopRemoteDataSourceImpl implements ShopRemoteDataSource {
  static const _productSelect =
      'id,shop_id,category_id,title,description,brand,status,price_min,price_max,'
      'currency,stock_total,sold_count,rating_avg,rating_count,cover_path,'
      'created_at,updated_at,shops(shop_name),'
      'product_media(id,product_id,media_type,storage_path,sort_order,created_at),'
      'product_variants(id,product_id,sku,variant_name,price,compare_at_price,'
      'stock_qty,weight_grams,status,created_at)';

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
}
